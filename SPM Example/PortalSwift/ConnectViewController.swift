//
//  ConnectViewController.swift
//  PortalSwift_Example
//
//  Created by Portal Labs, Inc.
//

import PortalSwift
import UIKit

class ConnectViewController: UIViewController, UITextFieldDelegate {
  public var portal: PortalProtocol?
  public var app: PortalExampleAppDelegate? = UIApplication.shared.delegate as? PortalExampleAppDelegate

  private var connect: PortalConnect?
  private var connect2: PortalConnect?
  private var chains: [Int]?

  // UI Elements
  @IBOutlet var connectButton: UIButton?
  @IBOutlet var connectMessage: UITextView?
  @IBOutlet var disconnectButton: UIButton?
  @IBOutlet var disconnectLabel: UILabel?
  @IBOutlet var addressTextInput: UITextField?
  @IBOutlet var connectButton2: UIButton?
  @IBOutlet var connectMessage2: UITextView?
  @IBOutlet var disconnectButton2: UIButton?
  @IBOutlet var addressTextInput2: UITextField?
  @IBOutlet var PolygonMainnetButton: UIButton?
  @IBOutlet var EthMainnetButton: UIButton?
  @IBOutlet var SepoliaButton: UIButton?
  @IBOutlet var MumbaiButton: UIButton?
  @IBOutlet var sessionRequestIdInput: UITextField?
  @IBOutlet var sessionTopicInput: UITextField?
  @IBOutlet var autoApproveToggleButton: UISwitch?

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.addressTextInput?.delegate = self
    self.addressTextInput2?.delegate = self
    self.sessionRequestIdInput?.delegate = self
    self.sessionTopicInput?.delegate = self

    self.connectButton?.isEnabled = false
    self.connectButton2?.isEnabled = false
    self.disconnectButton?.isEnabled = false
    self.disconnectButton2?.isEnabled = false

    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Error loading env vars in connect")
      return
    }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return
    }

    let PROD_CONNECT_SERVER_URL = "connect.portalhq.io"
    let STAGING_CONNECT_SERVER_URL = "connect.portalhq.dev"
    let LOCAL_CONNECT_SERVER_URL = "localhost:3003"
    let CONNECT_URL = ENV == "prod" ? PROD_CONNECT_SERVER_URL : ENV == "staging" ? STAGING_CONNECT_SERVER_URL : LOCAL_CONNECT_SERVER_URL

    do {
      self.connect = try self.portal?.createPortalConnectInstance(webSocketServer: CONNECT_URL)
      self.connect2 = try self.portal?.createPortalConnectInstance(webSocketServer: CONNECT_URL)

      if let keys = self.portal?.gatewayConfig.keys {
        self.chains = Array(keys)
      }

      self.app?.connect = self.connect
      self.app?.connect2 = self.connect2

      if
        let unwrappedConnect = self.connect,
        let unwrappedConnect2 = self.connect2,
        let unwrappedConnectButton = self.connectButton,
        let unwrappedConnectButton2 = self.connectButton2
      {
        self.initPortalConnect(portalConnect: unwrappedConnect, button: unwrappedConnectButton, label: "connect1")
        self.initPortalConnect(portalConnect: unwrappedConnect2, button: unwrappedConnectButton2, label: "connect2")
      }
    } catch {
      print("[ConnectViewController] Unable to create PortalConnect instances \(error)")
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    textField.endEditing(true)
    return true
  }

  func initPortalConnect(portalConnect: PortalConnect, button: UIButton, label: String) {
    button.isEnabled = false

    portalConnect.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) received for v2 on \(label)")
      self?.didRequestApprovalDapps(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(event: Events.ConnectError.rawValue, callback: { data in
      if let errorData = data as? ErrorData {
        print("Event \(Events.ConnectError.rawValue) received on \(label). Error: \(errorData.params.message) Code: \(errorData.params.code)")
      } else {
        print("Event \(Events.ConnectError.rawValue) received on \(label). Error: \(data)")
      }
    })

    portalConnect.on(event: Events.PortalSignatureReceived.rawValue) { (data: Any) in
      let result = data
      print("[ConnectViewController] ✅ Received signature \(result) on \(label)")
    }

    portalConnect.on(event: Events.Connect.rawValue) { (data: Any) in
      print("[ConnectViewController] ✅ Connected! \(data) on \(label)")
      self.disconnectLabel?.text = "Connected ✅"
      if label == "connect1" {
        self.connectButton?.isEnabled = false
        self.disconnectButton?.isEnabled = true
      } else {
        self.connectButton2?.isEnabled = false
        self.disconnectButton2?.isEnabled = true
      }
    }

    portalConnect.on(event: Events.Disconnect.rawValue) { (data: Any) in
      print("[ConnectViewController] 🛑 Disconnected \(data) on \(label)")
      self.disconnectLabel?.text = "Disconnected 🛑"
      if label == "connect1" {
        self.connectButton?.isEnabled = false
        self.disconnectButton?.isEnabled = false
        self.addressTextInput?.text = ""
      } else {
        self.connectButton2?.isEnabled = false
        self.disconnectButton2?.isEnabled = false
        self.addressTextInput2?.text = ""
      }
    }

    portalConnect.on(event: Events.PortalSigningRequested.rawValue) { (data: Any) in
      print("Chain ID: ", (data as? ETHRequestPayload)?.chainId ?? "")
      if self.autoApproveToggleButton?.isOn == true {
        portalConnect.emit(event: Events.PortalSigningApproved.rawValue, data: data)
      }
    }
  }

  override func viewDidDisappear(_: Bool) {
    print("resetting event listeners")
    self.connect = nil
    self.connect2 = nil
  }

  override func viewWillDisappear(_: Bool) {
    self.connect?.viewWillDisappear()
    self.connect2?.viewWillDisappear()
  }

  func didRequestApprovalDapps(portalConnect: PortalConnect, data: Any) {
    print("Emitting Dapp Session Approval for v2..")
    if let connectData = data as? ConnectData {
      let newConnectData = portalConnect.addChainsToProposal(data: connectData)

      portalConnect.emit(event: Events.PortalDappSessionApproved.rawValue, data: newConnectData)
    } else {
      print("Invalid data type. Expected ConnectData.")
    }
  }

  func changeChainId(chainId: Int) {
    self.connect?.once(event: Events.ChainChanged.rawValue) { data in
      print("chain changed to \(data)")
    }
    self.connect2?.once(event: Events.ChainChanged.rawValue) { data in
      print("chain changed to \(data)")
    }
    self.portal?.once(event: Events.ChainChanged.rawValue) { data in
      print("chain changed to \(data)")
    }
    do {
      try self.portal?.setChainId(to: chainId)

      try self.connect?.setChainId(value: chainId)

      try self.connect2?.setChainId(value: chainId)

    } catch {
      print("Error in switching chains: \(error)")
    }
  }

  @IBAction func PolyMainPressed(_: Any) {
    self.changeChainId(chainId: 137)
  }

  @IBAction func SepoliaPressed(_: Any) {
    self.changeChainId(chainId: 11_155_111)
  }

  @IBAction func EthMainnetPressed(_: Any) {
    self.changeChainId(chainId: 1)
  }

  @IBAction func MumbaiPressed(_: Any) {
    self.changeChainId(chainId: 80001)
  }

  @IBAction func emitGetSessionRequest(_: Any) {
    guard let requestId = self.sessionRequestIdInput?.text, let topic = self.sessionTopicInput?.text else {
      print("❌ You must fill in Session Request ID and Session Topic fields")
      return
    }

    self.connect?.emitGetSessionRequest(requestId: requestId, topic: topic)
  }

  @IBAction func autoApproveToggled(_ sender: UISwitch) {
    print("Auto approve toggled: \(sender.isOn)")
  }

  @IBAction func connectPressed() {
    print("Connect button pressed...")
    let uri = self.addressTextInput?.text
    print("Attempting to connect to \(uri ?? "") using \(String(describing: self.connect))")
    self.connect?.connect(uri ?? "")
  }

  @IBAction func connect2Pressed() {
    print("Connect button pressed...")
    let uri = self.addressTextInput2?.text

    print("URI2 Text: \(uri ?? "")")

    print("Attempting to connect to \(uri ?? "") using \(String(describing: self.connect2))")
    self.connect2?.connect(uri ?? "")
  }

  @IBAction func disconnectPressed() {
    print("Disconnecting from connect1...")
    self.connect?.disconnect(true)
  }

  @IBAction func disconnectPressed2() {
    print("Disconnecting from connect2...")
    self.connect2?.disconnect(true)
  }

  @IBAction func uriChanged(_: Any) {
    let uri = self.addressTextInput?.text

    self.connectButton?.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }

  @IBAction func uri2Changed(_: Any) {
    let uri = self.addressTextInput2?.text

    self.connectButton2?.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }
}

//
//  ConnectViewController.swift
//  PortalSwift_Example
//
//  Created by Portal Labs, Inc.
//

import PortalSwift

class ConnectViewController: UIViewController, UITextFieldDelegate {
  public var portal: Portal?
  public var app: PortalExampleAppDelegate = UIApplication.shared.delegate as! PortalExampleAppDelegate

  private var connect: PortalConnect?
  private var connect2: PortalConnect?
  private var chains: [Int]?
  // UI Elements
  @IBOutlet var connectButton: UIButton!
  @IBOutlet var connectMessage: UITextView!
  @IBOutlet var disconnectButton: UIButton!
  @IBOutlet var addressTextInput: UITextField!
  @IBOutlet var connectButton2: UIButton!
  @IBOutlet var connectMessage2: UITextView!
  @IBOutlet var disconnectButton2: UIButton!
  @IBOutlet var addressTextInput2: UITextField!
  @IBOutlet var PolygonMainnetButton: UIButton!
  @IBOutlet var EthMainnetButton: UIButton!
  @IBOutlet var GoerliButton: UIButton!
  @IBOutlet var MumbaiButton: UIButton!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.addressTextInput.delegate = self
    self.addressTextInput2.delegate = self

    self.connectButton.isEnabled = false
    self.connectButton2.isEnabled = false
    self.disconnectButton.isEnabled = false
    self.disconnectButton2.isEnabled = false

    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Error loading env vars in connect")
      return
    }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return
    }

    let PROD_CONNECT_SERVER_URL = "connect.portalhq.io"
    let STAGING_CONNECT_SERVER_URL = "connect-staging.portalhq.io"
    let LOCAL_CONNECT_SERVER_URL = "localhost:3003"
    let CONNECT_URL = ENV == "prod" ? PROD_CONNECT_SERVER_URL : ENV == "staging" ? STAGING_CONNECT_SERVER_URL : LOCAL_CONNECT_SERVER_URL

    do {
      self.connect = try self.portal!.createPortalConnectInstance(webSocketServer: CONNECT_URL)
      self.connect2 = try self.portal!.createPortalConnectInstance(webSocketServer: CONNECT_URL)
      self.chains = Array((self.portal?.gatewayConfig.keys)!)

      self.app.connect = self.connect
      self.app.connect2 = self.connect2

      self.initPortalConnect(portalConnect: self.connect!, button: self.connectButton, label: "connect1")
      self.initPortalConnect(portalConnect: self.connect2!, button: self.connectButton2, label: "connect2", autoApprove: false)
    } catch {
      print("[ConnectViewController] Unable to create PortalConnect instances \(error)")
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    textField.endEditing(true)
    return true
  }

  func initPortalConnect(portalConnect: PortalConnect, button: UIButton, label: String, autoApprove: Bool = true) {
    button.isEnabled = false

    portalConnect.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v2 on \(label)")
      self?.didRequestApprovalDapps(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(event: Events.PortalDappSessionRequestedV1.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v1 on \(label)")
      self?.didRequestApprovalDappsV1(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(event: Events.ConnectError.rawValue, callback: { data in
      if let errorData = data as? ErrorData {
        print("Event \(Events.ConnectError.rawValue) recieved on \(label). Error: \(errorData.message)")
      } else {
        print("Event \(Events.ConnectError.rawValue) recieved on \(label). Error: \(data)")
      }
    })

    portalConnect.on(event: Events.PortalSignatureReceived.rawValue) { (data: Any) in
      let result = data
      print("[ConnectViewController] ✅ Received signature \(result) on \(label)")
    }

    portalConnect.on(event: Events.Connect.rawValue) { (data: Any) in
      print("[ConnectViewController] ✅ Connected! \(data) on \(label)")

      if label == "connect1" {
        self.connectButton.isEnabled = false
        self.disconnectButton.isEnabled = true
      } else {
        self.connectButton2.isEnabled = false
        self.disconnectButton2.isEnabled = true
      }
    }

    portalConnect.on(event: Events.Disconnect.rawValue) { (data: Any) in
      print("[ConnectViewController] 🛑 Disconnected \(data) on \(label)")
      if label == "connect1" {
        self.connectButton.isEnabled = false
        self.disconnectButton.isEnabled = false
        self.addressTextInput.text = ""
      } else {
        self.connectButton2.isEnabled = false
        self.disconnectButton2.isEnabled = false
        self.addressTextInput2.text = ""
      }
    }

    portalConnect.on(event: Events.PortalSigningRequested.rawValue) { (data: Any) in
      print("Chain ID: ", (data as? ETHRequestPayload)?.chainId)
      if autoApprove {
        portalConnect.emit(event: Events.PortalSigningApproved.rawValue, data: data)
      } else {
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
      // Now you can work with the parsed ConnectData object
      print(connectData.id)
      print(connectData.topic)
      print(connectData.params)

      // You can emit the event with the parsed ConnectData object
      portalConnect.emit(event: Events.PortalDappSessionApprovedV1.rawValue, data: connectData)
    } else {
      print("Invalid data type. Expected ConnectData.")
    }
    portalConnect.emit(event: Events.PortalDappSessionApproved.rawValue, data: data)
  }

  func didRequestApprovalDappsV1(portalConnect: PortalConnect, data: Any) {
    print("Emitting Dapp Session Approval for v1..")

    if let connectData = data as? ConnectV1Data {
      // Now you can work with the parsed ConnectV1Data object
      print(connectData.id)
      print(connectData.topic)
      print(connectData.params)

      // You can emit the event with the parsed ConnectV1Data object
      portalConnect.emit(event: Events.PortalDappSessionApprovedV1.rawValue, data: connectData)
    } else {
      print("Invalid data type. Expected ConnectV1Data.")
    }
  }

  @IBAction func PolyMainPressed(_: Any) {
    self.changeChainId(chainId: 137)
  }

  @IBAction func GoerliPressed(_: Any) {
    self.changeChainId(chainId: 5)
  }

  @IBAction func EthMainnetPressed(_: Any) {
    self.changeChainId(chainId: 1)
  }

  @IBAction func MumbaiPressed(_: Any) {
    self.changeChainId(chainId: 80001)
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

  @IBAction func connectPressed() {
    print("Connect button pressed...")
    let uri = self.addressTextInput.text
    print("Attempting to connect to \(uri!) using \(self.connect!)")
    self.connect?.connect(uri!)
  }

  @IBAction func connect2Pressed() {
    print("Connect button pressed...")
    let uri = self.addressTextInput2.text

    print("URI2 Text: \(uri)")

    print("Attempting to connect to \(uri!) using \(self.connect2!)")
    self.connect2?.connect(uri!)
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
    let uri = self.addressTextInput.text

    self.connectButton.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }

  @IBAction func uri2Changed(_: Any) {
    let uri = self.addressTextInput2.text

    self.connectButton2.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }
}

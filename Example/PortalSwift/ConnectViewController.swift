//
//  ConnectViewController.swift
//  PortalSwift_Example
//
//  Created by Portal Labs, Inc.
//

import PortalSwift

class ConnectViewController: UIViewController {
  public var portal: Portal?

  private var connect: PortalConnect?
  private var connect2: PortalConnect?

  // UI Elements
  @IBOutlet var connectButton: UIButton!
  @IBOutlet var connectMessage: UITextView!
  @IBOutlet var disconnectButton: UIButton!
  @IBOutlet var addressTextInput: UITextField!
  @IBOutlet var connectButton2: UIButton!
  @IBOutlet var connectMessage2: UITextView!
  @IBOutlet var disconnectButton2: UIButton!
  @IBOutlet var addressTextInput2: UITextField!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    connectButton.isEnabled = false
    connectButton2.isEnabled = false
    disconnectButton.isEnabled = false
    disconnectButton2.isEnabled = false

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

    connect = PortalConnect(portal!, CONNECT_URL)
    connect2 = PortalConnect(portal!, CONNECT_URL)

    initPortalConnect(portalConnect: connect!, button: connectButton, label: "connect1")
    initPortalConnect(portalConnect: connect2!, button: connectButton2, label: "connect2", autoApprove: false)
  }

  func initPortalConnect(portalConnect: PortalConnect, button: UIButton, label: String, autoApprove: Bool = true) {
    button.isEnabled = false

    portalConnect.on(.DappSessionRequested, callback: { [weak self] data in
      print("Event \(ConnectEvents.DappSessionRequested.rawValue) recieved for v2 on \(label)")
      self?.didRequestApprovalDapps(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(.SignatureReceived) { (data: Any) in
      let result = data as! RequestCompletionResult
      print("[ConnectViewController] ✅ Received signature \(result) on \(label)")
    }

    portalConnect.on(.Connect) { (data: Any) in
      print("[ConnectViewController] ✅ Connected! \(data) on \(label)")

      if label == "connect1" {
        self.connectButton.isEnabled = false
        self.disconnectButton.isEnabled = true
      } else {
        self.connectButton2.isEnabled = false
        self.disconnectButton.isEnabled = true
      }
    }

    portalConnect.on(.Disconnect) { (data: Any) in
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

    portalConnect.on(.SigningRequested) { (data: Any) in
      if autoApprove {
        print("Sending signing approval on \(label) for data \(data)")
        portalConnect.emit(.SigningApproved, data: data)
      } else {
        print("Sending signing rejection on \(label) for data \(data)")
        portalConnect.emit(.SigningRejected, data: data)
      }
    }
  }

  override func viewDidDisappear(_: Bool) {
    print("resetting event listeners")
    connect = nil
    connect2 = nil
  }

  override func viewWillDisappear(_: Bool) {
    connect?.viewWillDisappear()
    connect2?.viewWillDisappear()
  }

  func didRequestApprovalDapps(portalConnect: PortalConnect, data: Any) {
    print("Emitting Dapp Session Approval for v2..")
    portalConnect.emit(.DappSessionApproved, data: data)
  }

  @IBAction func connectPressed() {
    print("Connect button pressed...")
    let uri = addressTextInput.text
    print("Attempting to connect to \(uri!) using \(connect!)")
    connect?.connect(uri!)
  }

  @IBAction func connect2Pressed() {
    print("Connect button pressed...")
    let uri = addressTextInput2.text
    print("Attempting to connect to \(uri!) using \(connect2!)")
    connect2?.connect(uri!)
  }

  @IBAction func disconnectPressed() {
    print("Disconnecting from connect1...")
    connect?.disconnect(true)
  }

  @IBAction func disconnectPressed2() {
    print("Disconnecting from connect2...")
    connect2?.disconnect(true)
  }

  @IBAction func uriChanged(_: Any) {
    let uri = addressTextInput.text

    connectButton.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }

  @IBAction func uri2Changed(_: Any) {
    let uri = addressTextInput2.text

    connectButton2.isEnabled =
      uri != nil
        && uri?.isEmpty == false
        && uri?.starts(with: "wc:") == true
  }
}

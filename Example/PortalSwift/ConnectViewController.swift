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
  @IBOutlet var addressTextInput: UITextField!
  @IBOutlet var connectButton2: UIButton!
  @IBOutlet var connectMessage2: UITextView!
  @IBOutlet var addressTextInput2: UITextField!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
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

    portalConnect.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v2 on \(label)")
      self?.didRequestApprovalDapps(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(event: Events.PortalDappSessionRequestedV1.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v1 on \(label)")
      self?.didRequestApprovalDappsV1(portalConnect: portalConnect, data: data)
    })

    portalConnect.on(event: Events.PortalSignatureReceived.rawValue) { (data: Any) in
      let result = data as! RequestCompletionResult
      print("[ConnectViewController] ✅ Received signature \(result) on \(label)")
    }

    portalConnect.on(event: Events.Connect.rawValue) { (data: Any) in
      print("[ConnectViewController] ✅ Connected! \(data) on \(label)")
    }

    portalConnect.on(event: Events.Disconnect.rawValue) { (data: Any) in
      print("[ConnectViewController] 🛑 Disconnected \(data) on \(label)")
    }

    portalConnect.on(event: Events.PortalSigningRequested.rawValue) { (data: Any) in
      if autoApprove {
        portalConnect.emit(event: Events.PortalSigningApproved.rawValue, data: data)
      } else {
        portalConnect.emit(event: Events.PortalSigningRejected.rawValue, data: data)
      }
    }
  }

  override func viewDidDisappear(_: Bool) {
    print("resetting event listeners")
    connect?.resetEvents()
    connect = nil
    connect2?.resetEvents()
    connect2 = nil
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

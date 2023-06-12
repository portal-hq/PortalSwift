//
//  ConnectViewController.swift
//  PortalSwift_Example
//
//  Created by Portal Labs, Inc.
//

import PortalSwift

class ConnectViewController: UIViewController {
  private var connect: PortalConnect?
  public var portal: Portal?
  
  
  // UI Elements
  @IBOutlet weak var connectButton: UIButton!
  @IBOutlet weak var connectMessage: UITextView!
  @IBOutlet weak var addressTextInput: UITextField!
  
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
    let CONNECT_URL = ENV == "prod" ? PROD_CONNECT_SERVER_URL : STAGING_CONNECT_SERVER_URL

    connectButton.isEnabled = false
    connect = PortalConnect(portal!)
    _ = portal?.provider.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v2")
      self?.didRequestApprovalDapps(data: data)})
    
    _ = portal?.provider.on(event: Events.PortalDappSessionRequestedV1.rawValue, callback: { [weak self] data in
      print("Event \(Events.PortalDappSessionRequested.rawValue) recieved for v1")
      self?.didRequestApprovalDappsV1(data: data)})
  }
  
  func didRequestApprovalDapps(data: Any) -> Void {
    print("Emitting Dapp Session Approval for v2..")
    if let connectData = data as? ConnectData {
        // Now you can work with the parsed ConnectV1Data object
        print(connectData.id)
        print(connectData.topic)
        print(connectData.params)

        // You can emit the event with the parsed ConnectV1Data object
        _ = connect?.emit(event: Events.PortalDappSessionApprovedV1.rawValue, data: connectData)
    } else {
        print("Invalid data type. Expected ConnectV1Data.")
    }
    _ = connect?.emit(event: Events.PortalDappSessionApproved.rawValue, data: data)
  }

  func didRequestApprovalDappsV1(data: Any) {
      print("Emitting Dapp Session Approval for v1..")

      if let connectData = data as? ConnectV1Data {
          // Now you can work with the parsed ConnectV1Data object
          print(connectData.id)
          print(connectData.topic)
          print(connectData.params)

          // You can emit the event with the parsed ConnectV1Data object
          _ = connect?.emit(event: Events.PortalDappSessionApprovedV1.rawValue, data: connectData)
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
  
  @IBAction func uriChanged(_ sender: Any) {
    let uri = addressTextInput.text
    
    connectButton.isEnabled =
      uri != nil
      && uri?.isEmpty == false
      && uri?.starts(with: "wc:") == true
  }
}

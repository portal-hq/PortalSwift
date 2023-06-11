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
    connect = PortalConnect(portal!, CONNECT_URL)
    _ = portal?.provider.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in self?.didRequestApprovalDapps(data: data)})
    
    _ = portal?.provider.on(event: Events.PortalDappSessionRequestedV1.rawValue, callback: { [weak self] data in
      self?.didRequestApprovalDappsV1(data: data)})
  }
  
  func didRequestApprovalDapps(data: Any) -> Void {
    _ = connect?.emit(event: Events.PortalDappSessionApproved.rawValue, data: data)
  }
  func didRequestApprovalDappsV1(data: Any) -> Void {
    _ = connect?.emit(event: Events.PortalDappSessionApprovedV1.rawValue, data: data)
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

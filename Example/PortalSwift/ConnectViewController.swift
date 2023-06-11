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
    
    connectButton.isEnabled = false
    connect = PortalConnect(portal!)
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

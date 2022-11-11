//
//  ViewController.swift
//  PortalSwift
//
//  Created by Blake Williams on 08/14/2022.
//  Copyright (c) 2022 Blake Williams. All rights reserved.
//

import UIKit
import PortalSwift

struct Todo: Codable {
  var userId: Int
  var id: Int
  var title: String
  var completed: Bool
}

class ViewController: UIViewController {
  public var portal: Portal?
  
  // Buttons
  @IBOutlet public var generateButton: UIButton!
  @IBOutlet public var backupButton: UIButton!
  @IBOutlet public var recoverButton: UIButton!
  
  // Send form
  @IBOutlet public var sendAddress: UITextField!
  @IBOutlet public var sendButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    registerPortal()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func handleBackup() throws -> Void {
    _ = try portal?.mpc.backup(method: BackupMethods.GoogleDrive.rawValue)
  }
  
  @IBAction func handleGenerate() throws -> Void {
    _ = try portal?.mpc.generate()
  }
  
  @IBAction func handleRecover() throws -> Void {
    _ = try portal?.mpc.recover(cipherText: "", method: BackupMethods.GoogleDrive.rawValue)
  }
  
  @IBAction func handleSend() throws -> Void {
    let payload = ETHRequestPayload(
      method: "eth_sendTransaction",
      params: []
    )
    _ = try portal?.provider.request(payload: payload) {
      (result: Any) -> Void in
      print(result)
    }
  }
  
  func registerPortal() -> Void {
    do {
      let backup = BackupOptions(gdrive: GDriveStorage())
      let keychain = PortalKeychain()
      portal = try Portal(
        apiKey: "31515686-b8c4-48d5-a5e7-1b0f0d876a10",
        backup: backup,
        chainId: 5,
        keychain: keychain,
        gatewayConfig: [
          5: ""
        ]
      )
      
      print(portal!.apiKey)
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("The provided gateway URL is not valid")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print(String(format: "There is no valid gateway config for chain ID: %d", chainId))
    } catch {
      print(error)
    }
  }

}


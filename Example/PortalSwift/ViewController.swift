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
  @IBOutlet public var backupButton: UIButton!
  @IBOutlet public var generateButton: UIButton!
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
  
  @IBAction func handleBackup(_ sender: UIButton!) throws -> Void {
    print(String(format: "Tapped button: ", sender))
    _ = try portal?.mpc.backup(method: BackupMethods.iCloud.rawValue)  {
      (result: Result<String>) -> Void in
      print(result.data)
      print(result.error)
    }
  }
  
  @IBAction func handleGenerate(_ sender: UIButton!) throws -> Void {
    print(String(format: "Tapped button: ", sender))
    _ = try portal?.mpc.generate()
  }
  
  @IBAction func handleRecover(_ sender: UIButton!) throws -> Void {
    print(String(format: "Tapped button: ", sender))
    portal?.mpc.recover(cipherText: "", method: BackupMethods.iCloud.rawValue) {
      (result: Result<String>) -> Void in
      print(result)
    }
  }
  
  @IBAction func handleSend(_ sender: UIButton!) throws -> Void {
    print(String(format: "Tapped button: ", sender))
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
      let backup = BackupOptions(icloud: ICloudStorage())
      let keychain = PortalKeychain()
      portal = try Portal(
        apiKey: "4d9f0c9e-fd45-45c1-b549-5495da2f5b71",
        backup: backup,
        chainId: 5,
        keychain: keychain,
        gatewayConfig: [
          5: "https://eth-goerli.g.alchemy.com/v2/53va-QZAS8TnaBH3-oBHqcNJtIlygLi-"
        ]
      )
//      print(try portal?.keychain.getSigningShare())
      var cipherText: String
      portal?.mpc.backup(method: BackupMethods.iCloud.rawValue) {
        (result: Result<String>) -> Void in
        print("Data: ", result.data)
        print("Error: ", result.error)
        self.portal?.mpc.recover(cipherText: result.data!, method: BackupMethods.iCloud.rawValue) {
          (result: Result<String>) -> Void in
          print("Data: in recover", result.data)
          print("Error: in recover ", result.error)
        }
      }
//      print(try portal?.keychain.getSigningShare())
//      print(try portal?.keychain.getAddress())
//      print(try portal?.mpc.sign(method: "eth_sign", params: "[\"0xaeabe5b13828f691fdb56007502ef9035c95e8b2\", \"0x57656c636f6d6520746f204f70656e536561210a0a436c69636b20746f207369676e20696e20616e642061636365707420746865204f70656e536561205465726d73206f6620536572766963653a2068747470733a2f2f6f70656e7365612e696f2f746f730a0a5468697320726571756573742077696c6c206e6f742074726967676572206120626c6f636b636861696e207472616e73616374696f6e206f7220636f737420616e792067617320666565732e0a0a596f75722061757468656e7469636174696f6e207374617475732077696c6c20726573657420616674657220323420686f7572732e0a0a57616c6c657420616464726573733a0a3078616561626535623133383238663639316664623536303037353032656639303335633935653862320a0a4e6f6e63653a0a37623563643832302d653433322d343934322d386434352d663561666563343135663262\"]"))
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


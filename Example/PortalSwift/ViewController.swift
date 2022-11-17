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

    injectWebView()
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

      print(portal!.apiKey)
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("The provided gateway URL is not valid")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print(String(format: "There is no valid gateway config for chain ID: %d", chainId))
    } catch {
      print(error)
    }
  }

  func injectWebView() {
    let webViewController = WebViewController()

    // install the WebViewController as a child view controller
    addChildViewController(webViewController)

    let webViewControllerView = webViewController.view!

    view.addSubview(webViewControllerView)

    webViewControllerView.translatesAutoresizingMaskIntoConstraints = false
    webViewControllerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    webViewControllerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    webViewControllerView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    webViewControllerView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

    webViewController.didMove(toParentViewController: self)
  }
}

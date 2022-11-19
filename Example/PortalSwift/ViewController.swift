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

struct UserResult: Codable {
  var clientApiKey: String
  var exchangeUserId: Int
}

struct SignUpBody: Codable {
  var username: String
}

struct CipherTextResult: Codable {
  var cipherText: String
}


class ViewController: UIViewController {
  public var portal: Portal?
  public var CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"

  // Static information
  @IBOutlet weak var addressInformation: UITextView!
  @IBOutlet weak var ethBalanceInformation: UITextView!

  // Buttons
  @IBOutlet public var generateButton: UIButton!
  @IBOutlet public var backupButton: UIButton!
  @IBOutlet public var recoverButton: UIButton!

  // Send form
  @IBOutlet public var sendAddress: UITextField!
  @IBOutlet public var sendButton: UIButton!
  @IBOutlet public var username: UITextField!
  public var user: UserResult?


  override func viewDidLoad() {
    super.viewDidLoad()
    //    registerPortal()
    //    injectWebView()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @IBAction func handleSignIn(_ sender: UIButton) {
    signIn(username: username.text!) {
      (user: UserResult) -> Void in
      print("Signed in: API key:", user.clientApiKey)
      self.user = user
      self.registerPortal(apiKey: user.clientApiKey)
    }
    updateStaticContent()
  }

  @IBAction func handleWebview(_ sender: UIButton) {
    injectWebView()
  }

  @IBAction func handleSignup(_ sender: UIButton) {
    signUp(username: username.text!) {
      (user: UserResult) -> Void in
      print("Signed up: API key:", user.clientApiKey)
      self.user = user
      self.registerPortal(apiKey: user.clientApiKey)
    }
    updateStaticContent()
  }

  @IBAction func handleBackup(_ sender: UIButton!) {
    _ = portal?.mpc.backup(method: BackupMethods.iCloud.rawValue)  {
      (result: Result<String>) -> Void in
      if (result.error != nil) {
        print(result.error)
      } else {
        print("Backup successful: Cipher text:", result.data)

        var request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: ["Content-Type": "application/json"], isString: true)

        request.send() {
          (result: Result<String>) in
          if (result.error != nil) {
            print(result.error)
          } else {
            print("Cipher text sent to custodian server")
          }
        }
      }
    }
  }

  @IBAction func generatePressed(_ sender: UIButton!) {
    handleGenerate()
    updateStaticContent()
  }


  @IBAction func handleRecover(_ sender: UIButton!) {
    var request = HttpRequest<CipherTextResult, [String : String]>(
      url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text/fetch",
      method: "GET", body:[:],
      headers: ["Content-Type": "application/json"],isString: false)

    request.send() {
      (result: Result<CipherTextResult>) in

      print("Sent recover request:", result.data)
      print("Error in sending the recover request:", result.error)
      self.portal?.mpc.recover(cipherText: result.data!.cipherText, method: BackupMethods.iCloud.rawValue) {
        (result: Result<String>) -> Void in
        print("Recovered the keys:", result)
      }
    }
  }

  @IBAction func sendPressed(_ sender: UIButton!) {
    handleSend()
  }

  func updateStaticContent() {
    populateAddressInformation()
    populateEthBalance()
  }

  // populateAddressInformation: Populates the address information and eth balance.
  func populateAddressInformation() {
    do {
      let address = try portal?.keychain.getAddress()
      self.addressInformation.text = "Address: \(address ?? "N/A")"
    } catch {
      print("Error: \(error)")
    }
  }

  func populateEthBalance() {
    do {
      let address = try portal?.keychain.getAddress()
      guard let ethAddress = address else {
        print("address in eth balance", address as Any)
        return
      }
      let payload = ETHRequestPayload(
        method: "eth_getBalance",
        params: [ethAddress, "latest"]
      )
      print("payload", payload)
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        print("ETH balance:", result)
        self.ethBalanceInformation.text = "ETH Balance: \(result)"
      }
    } catch {
      print("Error getting eth balance:", error)
    }
  }

  func handleSend() {
    let payload = ETHRequestPayload(
      method: "eth_sendTransaction",
      params: []
    )
    do {
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        print(result)
      }
    } catch {
      print("Error in send \(error)")
    }

  }

  func handleGenerate() {
    do {
      var address = try portal?.mpc.generate()
      print(address)
      print(try portal?.keychain.getSigningShare())
    } catch {
      print("Error in generate \(error)")
    }
  }

  func registerPortal(apiKey: String) -> Void {
    do {
      let backup = BackupOptions(icloud: ICloudStorage())
      let keychain = PortalKeychain()
      portal = try Portal(
        apiKey: apiKey,
        backup: backup,
        chainId: 5,
        keychain: keychain,
        gatewayConfig: [
          5: "https://eth-goerli.g.alchemy.com/v2/53va-QZAS8TnaBH3-oBHqcNJtIlygLi-"
        ],
        autoApprove: true
      )
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("The provided gateway URL is not valid")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print(String(format: "There is no valid gateway config for chain ID: %d", chainId))
    } catch {
      print(error)
    }
  }

  func injectWebView() {
    let webViewController = WebViewController(portal: portal!)

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

  func signIn(username: String, completionHandler: @escaping (UserResult) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(url: CUSTODIAN_SERVER_URL + "/mobile/login", method: "POST", body: ["username": username], headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<UserResult>) in
      completionHandler(result.data!)
    }
  }

  func signUp(username: String, completionHandler: @escaping (UserResult) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(url: CUSTODIAN_SERVER_URL + "/mobile/signup", method: "POST", body: ["username": username], headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<UserResult>) in
      completionHandler(result.data!)
    }
  }
}

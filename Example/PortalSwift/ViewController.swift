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

struct UserResult {
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
      (user: Any) -> Void in
      print("user", user)
      let userResult = UserResult(
        clientApiKey: (user as! Dictionary<String, Any>)["clientApiKey"]! as! String,
        exchangeUserId: (user as! Dictionary<String, Any>)["exchangeUserId"]! as! Int
      )
      print("Signed in: API key:", userResult.clientApiKey)
      self.user = userResult
      self.registerPortal(apiKey: userResult.clientApiKey)
      self.updateStaticContent()
    }

  }

  @IBAction func handleWebview(_ sender: UIButton) {
    injectWebView()
  }

  @IBAction func handleSignup(_ sender: UIButton) {
    signUp(username: username.text!) {
      (user: Any) -> Void in
      let userResult = UserResult(
        clientApiKey: (user as! Dictionary<String, Any>)["clientApiKey"]! as! String,
        exchangeUserId: (user as! Dictionary<String, Any>)["exchangeUserId"]! as! Int
      )
      print("Signed up: API key:", userResult.clientApiKey)
      self.user = userResult
      self.registerPortal(apiKey: userResult.clientApiKey)
      self.updateStaticContent()
    }

  }

  @IBAction func handleBackup(_ sender: UIButton!) {
    _ = portal?.mpc.backup(method: BackupMethods.iCloud.rawValue)  {
      (result: Result<String>) -> Void in
      if (result.error != nil) {
        print(result.error!)
      } else {
        print("Backup successful: Cipher text:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: ["Content-Type": "application/json"], isString: true)

        request.send() {
          (result: Result<Any>) in
          if (result.error != nil) {
            print("Error in sending cipher Text", result.error!)
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
    let request = HttpRequest<CipherTextResult, [String : String]>(
      url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text/fetch",
      method: "GET", body:[:],
      headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<Any>) in
      guard result.error == nil else {
        print("Error in sending the recover request:", result.error!)
        return
      }
      print("Sent recover request:", result.data!)
      let data = result.data as! CipherTextResult
      self.portal?.mpc.recover(cipherText: data.cipherText , method: BackupMethods.iCloud.rawValue) {
        (result: Result<String>) -> Void in
        print("Recover successful: Cipher text:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: ["Content-Type": "application/json"], isString: true)

        request.send() {
          (result: Result<Any>) in
          if (result.error != nil) {
            print("Error in sending cipher Text", result.error!)
          } else {
            print("Cipher text sent to custodian server")
          }
        }
      }
    }
  }

  @IBAction func sendPressed(_ sender: UIButton!) {
    handleSend()
  }

  func updateStaticContent() {
    populateAddressInformation()
//    populateEthBalance()
//    testSignerMethods()
  }

  func testSignerMethods() {
     logAccounts()
  }

  func logAccounts() {
    do {
      let payload = ETHRequestPayload(
        method: ETHRequestMethods.Accounts.rawValue,
        params: []
      )
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        print("Accounts:", result)
      }
    } catch {
      print("Error logging accounts: ", error)
    }
  }

  func populateAddressInformation() {
    do {
      let address = try portal?.keychain.getAddress()
      DispatchQueue.main.async {
        self.addressInformation.text = "Address: \(address ?? "N/A")"
      }
    } catch {
      print("Error: \(error)")
    }
  }

  func populateEthBalance() {
    do {
      let address = try portal?.keychain.getAddress()
      guard address != nil else {
        print("address in eth balance", address as Any)
        return
      }
      let payload = ETHRequestPayload(
        method: ETHRequestMethods.SendTransaction.rawValue,
        params: [[
          "gas": "0x60000",
          "value": "0x38d7ea4c68000",
          "from": address,
          "to": "0x51a3837B768Faa63D15108925e06a1cad8BEfa50",
          "data": ""
        ]]
      )
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        print("ETH balance:", result)
        DispatchQueue.main.async {
          self.ethBalanceInformation.text = "ETH Balance: \(result)"
        }
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
      let address = try portal?.mpc.generate()
      print("Address: ", address!)
      print(try portal?.keychain.getSigningShare() ?? "")
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
      print("Error in registering portal \(error)")
    }
  }

  func injectWebView() {
    let webViewController = WebViewController(portal: portal!)

    // install the WebViewController as a child view controller
    addChild(webViewController)

    let webViewControllerView = webViewController.view!

    view.addSubview(webViewControllerView)

    webViewControllerView.translatesAutoresizingMaskIntoConstraints = false
    webViewControllerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    webViewControllerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    webViewControllerView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    webViewControllerView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

    webViewController.didMove(toParent: self)
  }

  func signIn(username: String, completionHandler: @escaping (Any) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(url: CUSTODIAN_SERVER_URL + "/mobile/login", method: "POST", body: ["username": username], headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<Any>) in
      guard result.error == nil else {
        print("Error in sending request to login: ", result.error!)
        return
      }
      print()
      completionHandler(result.data!)
    }
  }

  func signUp(username: String, completionHandler: @escaping (Any) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(url: CUSTODIAN_SERVER_URL + "/mobile/signup", method: "POST", body: ["username": username], headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<Any>) in
      guard result.error == nil else {
        print("Error in sending request to sign up: ", result.error!)
        return
      }
      completionHandler(result.data!)
    }
  }
}

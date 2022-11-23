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
  @IBOutlet public var url: UITextField!
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
      let userResult = UserResult(
        clientApiKey: (user as! Dictionary<String, Any>)["clientApiKey"]! as! String,
        exchangeUserId: (user as! Dictionary<String, Any>)["exchangeUserId"]! as! Int
      )
      print("✅ handleSignIn(): API key:", userResult.clientApiKey)
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
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      self.user = userResult
      self.registerPortal(apiKey: userResult.clientApiKey)
      self.updateStaticContent()
    }

  }

  @IBAction func handleBackup(_ sender: UIButton!) {
    _ = portal?.mpc.backup(method: BackupMethods.iCloud.rawValue)  {
      (result: Result<String>) -> Void in
      if (result.error != nil) {
        print("❌ handleBackup():", result.error!)
      } else {
        print("✅ handleBackup(): cipherText:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: ["Content-Type": "application/json"], isString: true)

        request.send() {
          (result: Result<Any>) in
          if (result.error != nil) {
            print("❌ handleBackup(): Error sending custodian cipherText:", result.error!)
          } else {
            print("✅ handleBackup(): Successfully sent custodian cipherText:", result.data!)
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
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        return
      }

      let response = result.data as! Dictionary<String, String>
      let cipherText = response["cipherText"]!

      self.portal?.mpc.recover(cipherText: cipherText, method: BackupMethods.iCloud.rawValue) {
        (result: Result<String>) -> Void in
        if (result.error != nil) {
          print("❌ handleRecover(): portal.mpc.recover", result.error!)
        } else {
          print("✅ handleRecover(): portal.mpc.recover - cipherText:", result.data!)
        }

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: ["Content-Type": "application/json"], isString: true)

        request.send() {
          (result: Result<Any>) in
          if (result.error != nil) {
            print("❌ handleRecover(): Error sending custodian cipherText:", result.error!)
          } else {
            print("✅ handleRecover(): Successfully sent custodian cipherText:", result.data!)
          }
        }
      }
    }
  }

  @IBAction func sendPressed(_ sender: UIButton!) {
    handleSend()
  }

  @IBAction func testProviderMethods(_ sender: UIButton!) {
    print("\n====================\nTesting provider methods\n====================")
    testSignerMethods()
    // testWalletMethods()
    // testOtherMethods()
    print("====================\n[FINISHED] Testing provider methods\n====================\n")
  }

  func updateStaticContent() {
    populateAddressInformation()
    populateEthBalance()
  }

  func testProviderMethod(method: String, params: [Any]) {
    do {
      let payload = ETHRequestPayload(
        method: method,
        params: []
      )
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        print("✅ Received result for:", method)
      }
    } catch {
      print("❌ Error testing method:", method, "Error:", error)
    }
  }

  func testSignerMethods() {
    print("Testing Signer Methods:\n")
    let signerMethods = [
      ETHRequestMethods.Accounts.rawValue,
      ETHRequestMethods.PersonalSign.rawValue,
      ETHRequestMethods.RequestAccounts.rawValue,
      ETHRequestMethods.SendTransaction.rawValue,
      ETHRequestMethods.Sign.rawValue,
      ETHRequestMethods.SignTransaction.rawValue,
      ETHRequestMethods.SignTypedData.rawValue,
    ]

    do {
      let address = try portal?.keychain.getAddress()
      guard address != nil else {
        print("❌ Error testing signer methods: address is nil")
        return
      }
      for method in signerMethods {
        testProviderMethod(method: method, params: [address!])
      }
    } catch {
      print("❌ Error testing signer methods:", error)
      return
    }
  }

  func testWalletMethods() {
    print("\nTesting Wallet Methods:\n")
    let walletMethods = [
      ETHRequestMethods.WalletAddEthereumChain.rawValue,
      ETHRequestMethods.WalletGetPermissions.rawValue,
      ETHRequestMethods.WalletRegisterOnboarding.rawValue,
      ETHRequestMethods.WalletRequestPermissions.rawValue,
      ETHRequestMethods.WalletSwitchEthereumChain.rawValue,
      ETHRequestMethods.WalletWatchAsset.rawValue,
    ]

    for method in walletMethods {
      testProviderMethod(method: method, params: [])
    }
  }

  func testOtherMethods() {
    print("\nTesting Other Methods:\n")
    let otherMethods = [
      ETHRequestMethods.BlockNumber.rawValue,
      ETHRequestMethods.Call.rawValue,
      ETHRequestMethods.Coinbase.rawValue,
      ETHRequestMethods.CompileLLL.rawValue,
      ETHRequestMethods.CompileSerpent.rawValue,
      ETHRequestMethods.CompileSolidity.rawValue,
      ETHRequestMethods.EstimateGas.rawValue,
      ETHRequestMethods.GasPrice.rawValue,
      ETHRequestMethods.GetBalance.rawValue,
      ETHRequestMethods.GetBlockByHash.rawValue,
      ETHRequestMethods.GetBlockByNumber.rawValue,
      ETHRequestMethods.GetBlockTransactionCountByHash.rawValue,
      ETHRequestMethods.GetBlockTransactionCountByNumber.rawValue,
      ETHRequestMethods.GetCode.rawValue,
      ETHRequestMethods.GetCompilers.rawValue,
      ETHRequestMethods.GetFilterChange.rawValue,
      ETHRequestMethods.GetFilterLogs.rawValue,
      ETHRequestMethods.GetLogs.rawValue,
      ETHRequestMethods.GetStorageAt.rawValue,
      ETHRequestMethods.GetTransactionByBlockHashAndIndex.rawValue,
      ETHRequestMethods.GetTransactionByBlockNumberAndIndex.rawValue,
      ETHRequestMethods.GetTransactionByHash.rawValue,
      ETHRequestMethods.GetTransactionCount.rawValue,
      ETHRequestMethods.GetTransactionReceipt.rawValue,
      ETHRequestMethods.GetUncleByBlockHashIndex.rawValue,
      ETHRequestMethods.GetUncleByBlockNumberAndIndex.rawValue,
      ETHRequestMethods.GetUncleCountByBlockHash.rawValue,
      ETHRequestMethods.GetUncleCountByBlockNumber.rawValue,
      ETHRequestMethods.GetWork.rawValue,
      ETHRequestMethods.Hashrate.rawValue,
      ETHRequestMethods.Mining.rawValue,
      ETHRequestMethods.NetListening.rawValue,
      ETHRequestMethods.NetPeerCount.rawValue,
      ETHRequestMethods.NetVersion.rawValue,
      ETHRequestMethods.NewBlockFilter.rawValue,
      ETHRequestMethods.NewFilter.rawValue,
      ETHRequestMethods.NewPendingTransactionFilter.rawValue,
      ETHRequestMethods.ProtocolVersion.rawValue,
      ETHRequestMethods.SendRawTransaction.rawValue,
      ETHRequestMethods.SubmitHashrate.rawValue,
      ETHRequestMethods.SubmitWork.rawValue,
      ETHRequestMethods.Synching.rawValue,
      ETHRequestMethods.UninstallFilter.rawValue,
      ETHRequestMethods.WalletAddEthereumChain.rawValue,
      ETHRequestMethods.WalletGetPermissions.rawValue,
      ETHRequestMethods.WalletRegisterOnboarding.rawValue,
      ETHRequestMethods.WalletRequestPermissions.rawValue,
      ETHRequestMethods.WalletSwitchEthereumChain.rawValue,
      ETHRequestMethods.WalletWatchAsset.rawValue,
      ETHRequestMethods.Web3ClientVersion.rawValue,
      ETHRequestMethods.Web3Sha3.rawValue,
    ]

    for method in otherMethods {
      testProviderMethod(method: method, params: [])
    }
  }

  func testUnsupportedMethods() {
    print("\nTesting Unsupported Methods:\n")
    testUnsupportedSignerMethods()
  }

  func testUnsupportedSignerMethods() {
    print("\nTesting Unsupported Signer Methods:\n")
    let unsupportedSignerMethods = [
      ETHRequestMethods.ChainId.rawValue,
    ]

    do {
      let address = try portal?.keychain.getAddress()
      guard address != nil else {
        print("❌ testUnsupportedSignerMethods(): Error getting address")
        return
      }
      for method in unsupportedSignerMethods {
        testProviderMethod(method: method, params: [address!])
      }
    } catch {
      print("❌ Error testing signer methods:", error)
      return
    }
  }

  func populateAddressInformation() {
    do {
      let address = try portal?.keychain.getAddress()
      DispatchQueue.main.async {
        self.addressInformation.text = "Address: \(address ?? "N/A")"
      }
    } catch {
      print("❌ Error getting address:", error)
    }
  }

  func parseETHBalanceHex(hex: String) -> String {
    let hexString = hex.replacingOccurrences(of: "0x", with: "")
    let hexInt = Int(hexString, radix: 16)!
    let ethBalance = Double(hexInt) / 1000000000000000000
    return String(ethBalance)
  }

  func populateEthBalance() {
    do {
      let address = try portal?.keychain.getAddress()
      guard address != nil else {
        print("❌ populateEthBalance(): Error getting address")
        return
      }
      let payload = ETHRequestPayload(
        method: ETHRequestMethods.GetBalance.rawValue,
        params: [address!, "latest"]
      )
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        let response = result as! Dictionary<String, Any>
        let balanceHex = response["result"] as! String
        DispatchQueue.main.async {
          self.ethBalanceInformation.text = "ETH Balance: \(self.parseETHBalanceHex(hex: balanceHex)) ETH"
        }
      }
    } catch {
      print("❌ Error getting ETH balance:", error)
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
        print("✅ handleSend(): Result:", result)
      }
    } catch {
      print("❌ Error sending transaction:", error)
    }

  }

  func handleGenerate() {
    do {
      let address = try portal?.mpc.generate()
      print("✅ handleGenerate(): Address:", address ?? "N/A")
    } catch {
      print("❌ Error generating address:", error)
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
      print("❌ Error: Invalid Gateway URL")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print("No gateway config for chainId: \(chainId)")
    } catch {
      print("❌ Error registering portal:", error)
    }
  }

  func injectWebView() {
    let webViewController = WebViewController(portal: portal!, url: URL(string: url.text!)!)

    // Install the WebViewController as a child view controller.
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
        print("❌ Error signing in:", result.error!)
        return
      }
      completionHandler(result.data!)
    }
  }

  func signUp(username: String, completionHandler: @escaping (Any) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(url: CUSTODIAN_SERVER_URL + "/mobile/signup", method: "POST", body: ["username": username], headers: ["Content-Type": "application/json"])

    request.send() {
      (result: Result<Any>) in
      guard result.error == nil else {
        print("❌ Error signing up:", result.error!)
        return
      }
      completionHandler(result.data!)
    }
  }
}

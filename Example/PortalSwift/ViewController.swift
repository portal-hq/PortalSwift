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

struct ProviderRequest {
  var method: String
  var params: [Any]
  var skipLoggingResult: Bool
}

struct SendTransactionParams {
  var from: String
  var to: String
  var gas: String
  var gasPrice: String
  var value: String
  var data: String
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
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
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

  @IBAction func handleSignOut(_ sender: UIButton) {
    self.user = nil
    self.addressInformation.text = "Address: N/A"
    self.ethBalanceInformation.text = "ETH Balance: N/A"
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

  @IBAction func testProviderRequests(_ sender: UIButton!) {
    print("\n====================\nTesting provider methods\n====================")
    testSignerRequests()
    // testWalletRequests()
    // testOtherRequests()
    print("====================\n[FINISHED] Testing provider methods\n====================\n")
  }

  @IBAction func handleWebview(_ sender: UIButton) {
    injectWebView()
  }

  func updateStaticContent() {
    populateAddressInformation()
    populateEthBalance()
  }

  func testProviderRequest(method: String, params: [Any], skipLoggingResult: Bool = false) {
    do {
      let payload = ETHRequestPayload(
        method: method,
        params: params
      )
      _ = try portal?.provider.request(payload: payload) {
        (result: Any) -> Void in
        if (!skipLoggingResult) {
          print("✅ ", method, "() result:", result)
        } else {
          print("✅ ", method, "()")
        }
      }
    } catch {
      print("❌ Error testing method:", method, "Error:", error)
    }
  }

  func testSignerRequests() {
    print("Testing Signer Methods:\n")
    do {
      let fromAddress = try portal?.keychain.getAddress()
      let toAddress = "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7"
      let fakeTransaction = SendTransactionParams(
        from: fromAddress!,
        to: toAddress,
        gas: "0x76c0",
        gasPrice: "0x9184e72a000",
        value: "0x9184e72a",
        data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
      )
      guard fromAddress != nil else {
        print("❌ Error testing signer methods: address is nil")
        return
      }
      let signerRequests = [
        ProviderRequest(method: ETHRequestMethods.Accounts.rawValue, params: [], skipLoggingResult: false),
        // ProviderRequest(method: ETHRequestMethods.PersonalSign.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.RequestAccounts.rawValue, params: [], skipLoggingResult: false),
        // ProviderRequest(method: ETHRequestMethods.SendTransaction.rawValue, params: [fakeTransaction], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Sign.rawValue, params: [fromAddress!, "0xdeadbeaf"], skipLoggingResult: false),
        // ProviderRequest(method: ETHRequestMethods.SignTransaction.rawValue, params: [fakeTransaction], skipLoggingResult: false),
        // @Skipping next one because it's a weird one (can't imagine it gets utilized much): https://eips.ethereum.org/EIPS/eip-712#specification-of-the-eth_signtypeddata-json-rpc
        // ProviderRequest(method: ETHRequestMethods.SignTypedData.rawValue, params: [], skipLoggingResult: false)
      ]

      for request in signerRequests {
        testProviderRequest(method: request.method, params: request.params)
      }
    } catch {
      print("❌ Error testing signer methods:", error)
      return
    }
  }

  func testWalletRequests() {
    print("\nTesting Wallet Methods:\n")
    let walletRequests = [
      ProviderRequest(method: ETHRequestMethods.WalletAddEthereumChain.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletGetPermissions.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletRegisterOnboarding.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletRequestPermissions.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletSwitchEthereumChain.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletWatchAsset.rawValue, params: [], skipLoggingResult: false)
    ]

    for request in walletRequests {
      testProviderRequest(method: request.method, params: request.params)
    }
  }

  func testOtherRequests() {
    print("\nTesting Other Methods:\n")
    let otherRequests = [
      ProviderRequest(method: ETHRequestMethods.BlockNumber.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Call.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Coinbase.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.CompileLLL.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.CompileSerpent.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.CompileSolidity.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.EstimateGas.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GasPrice.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetBalance.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetBlockByHash.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetBlockByNumber.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetBlockTransactionCountByHash.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetBlockTransactionCountByNumber.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetCode.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetCompilers.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetFilterChange.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetFilterLogs.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetLogs.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetStorageAt.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetTransactionByBlockHashAndIndex.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetTransactionByBlockNumberAndIndex.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetTransactionByHash.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetTransactionCount.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetTransactionReceipt.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetUncleByBlockHashIndex.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetUncleByBlockNumberAndIndex.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockHash.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockNumber.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.GetWork.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Hashrate.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Mining.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NetListening.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NetPeerCount.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NetVersion.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NewBlockFilter.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NewFilter.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.NewPendingTransactionFilter.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.ProtocolVersion.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.SendRawTransaction.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.SubmitHashrate.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.SubmitWork.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Synching.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.UninstallFilter.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletAddEthereumChain.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletGetPermissions.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletRegisterOnboarding.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletRequestPermissions.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletSwitchEthereumChain.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.WalletWatchAsset.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Web3ClientVersion.rawValue, params: [], skipLoggingResult: false),
      ProviderRequest(method: ETHRequestMethods.Web3Sha3.rawValue, params: [], skipLoggingResult: false)
    ]

    for request in otherRequests {
      testProviderRequest(method: request.method, params: request.params)
    }
  }

  func testUnsupportedRequests() {
    print("\nTesting Unsupported Methods:\n")
    testUnsupportedSignerRequests()
  }

  func testUnsupportedSignerRequests() {
    print("\nTesting Unsupported Signer Methods:\n")
    let unsupportedSignerMethods = [
      ETHRequestMethods.ChainId.rawValue,
    ]

    do {
      let address = try portal?.keychain.getAddress()
      guard address != nil else {
        print("❌ testUnsupportedSignerRequests(): Error getting address")
        return
      }
      for method in unsupportedSignerMethods {
        testProviderRequest(method: method, params: [address!])
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

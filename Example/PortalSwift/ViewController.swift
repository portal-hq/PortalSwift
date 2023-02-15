//
//  ViewController.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import PortalSwift

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

struct ProviderRequest {
  var method: String
  var params: [Any]
  var skipLoggingResult: Bool
}

struct ProviderTransactionRequest {
  var method: String
  var params: [ETHTransactionParam]
  var skipLoggingResult: Bool
}

struct ProviderAddressRequest {
  var method: String
  var params: [ETHAddressParam]
  var skipLoggingResult: Bool
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
    signIn(username: username.text!) { (userResult: UserResult) -> Void in
      print("✅ handleSignIn(): API key:", userResult.clientApiKey)
      self.user = userResult
      self.registerPortal(apiKey: userResult.clientApiKey)
      self.updateStaticContent()
    }
  }

  @IBAction func handleSignup(_ sender: UIButton) {
    signUp(username: username.text!) { (userResult: UserResult) -> Void in
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

  @IBAction func handleGenerate(_ sender: UIButton!) {
    do {
      let address = try portal?.mpc.generate()
      print("✅ handleGenerate(): Address:", address ?? "N/A")
    } catch {
      print("❌ Error generating address:", error)
    }
    updateStaticContent()
  }

  @IBAction func handleBackup(_ sender: UIButton!) {
    print("Starting backup...")
    portal?.mpc.backup(method: BackupMethods.GoogleDrive.rawValue)  { (result: Result<String>) -> Void in
      if (result.error != nil) {
        print("❌ handleBackup():", result.error!)
      } else {
        print("✅ handleBackup(): cipherText:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: [:]
        )

        request.send() { (result: Result<String>) in
          print("✅ handleBackup(): Successfully sent custodian cipherText:")
        }
      }
    }
  }

  @IBAction func handleRecover(_ sender: UIButton!) {
    print("Starting recover...")
    let request = HttpRequest<CipherTextResult, [String : String]>(
      url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text/fetch",
      method: "GET", body:[:],
      headers: [:]
    )

    request.send() { (result: Result<CipherTextResult>) in
      guard result.error == nil else {
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        return
      }

      let cipherText = result.data!.cipherText

      self.portal?.mpc.recover(cipherText: cipherText, method: BackupMethods.GoogleDrive.rawValue) { (result: Result<String>) -> Void in
        if (result.error != nil) {
          print("❌ handleRecover(): portal.mpc.recover", result.error!)
          return;
        }

        print("✅ handleRecover(): portal.mpc.recover - cipherText:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: [:]
        )

        request.send() { (result: Result<String>) in
          if (result.error != nil) {
            print("❌ handleRecover(): Error sending custodian cipherText:", result.error!)
          } else {
            print("✅ handleRecover(): Successfully sent custodian cipherText:", result.data!)
          }
        }
        self.updateStaticContent()
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
    testOtherRequests()
    testTransactionRequests()
    testAddressRequests()
    print("====================\n[FINISHED] Testing provider methods\n====================\n")
  }

  @IBAction func handleWebview(_ sender: UIButton) {
    injectWebView()
  }

  @IBAction func handleDeleteKeychain(_ sender: Any) {
    deleteKeychain()
    updateStaticContent()
  }
  func deleteKeychain() {
    do {
      print("Here is the keychain address: ", try portal?.keychain.getAddress() ?? "")
      try portal?.keychain.deleteAddress()
      try portal?.keychain.deleteSigningShare()
      
      print("Now its gone: ", try portal?.keychain.getAddress() ?? "")
    } catch {
      print(" ✅  Deleted keychain:", error)

    }
  }
  func updateStaticContent() {
    populateAddressInformation()
    // populateEthBalance()
  }

  func populateAddressInformation() {
    do {
      let address = try portal?.keychain.getAddress()
      DispatchQueue.main.async {
        self.addressInformation.text = "Address: \(address ?? "N/A")"
      }
    } catch {
      DispatchQueue.main.async {
        self.addressInformation.text = "Address: N/A"
      }
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
      portal?.provider.request(payload: payload) {
        (result: Result<RequestCompletionResult>) -> Void in
        guard result.error == nil else {
          print("❌ Error getting ETH balance:", result.error!)
          return
        }
        print("✅ Balance result:", (result.data!.result as! Dictionary<String, Any>)["result"]!)
        DispatchQueue.main.async {
          self.ethBalanceInformation.text = "ETH Balance: \(self.parseETHBalanceHex(hex: (result.data!.result as! Dictionary<String, Any>)["result"] as! String)) ETH"
        }
      }
    } catch {
      print("❌ Error getting ETH balance:", error)
    }
  }

  func handleSend() {
    let payload = ETHTransactionPayload(
      method: "eth_sendTransaction",
      params: [ETHTransactionParam(from: portal!.address, to: sendAddress.text!, gas: "0x6000", gasPrice: "0x100", value: "0x10", data: "")]
    )
    portal?.provider.request(payload: payload) {
        (result: Result<TransactionCompletionResult>) -> Void in
        guard result.error == nil else {
          print("❌ Error sending transaction:", result.error!)
          return
        }
        print("✅ handleSend(): Result:", result.data!.result)
      }
  }

  func registerPortal(apiKey: String) -> Void {
    do {
      let backup = BackupOptions(gdrive: GDriveStorage(clientID: "", viewController: self))
      let keychain = PortalKeychain()
      portal = try Portal(
        apiKey: apiKey,
        backup: backup,
        chainId: 5,
        keychain: keychain,
        gatewayConfig: [
          5: ""
        ],
        version: "v1",
        autoApprove: true
      )
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("❌ Error: Invalid Gateway URL")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print("❌ Error: No gateway config for chainId: \(chainId)")
    } catch {
      print("❌ Error registering portal:", error)
    }
  }

  func onError(result: Result<Any>) -> Void {
    print(result.error!)
  }

  func injectWebView() {
    let webViewController = WebViewController(portal: portal!, url: URL(string: url.text!)!, onError: onError)

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

  func signIn(username: String, completionHandler: @escaping (UserResult) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL + "/mobile/login",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"]
    )

    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing in:", result.error!)
        return
      }
      completionHandler(result.data!)
    }
  }

  func signUp(username: String, completionHandler: @escaping (UserResult) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL + "/mobile/signup",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"]
    )

    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing up:", result.error!)
        return
      }
      completionHandler(result.data!)
    }
  }

  func testProviderRequest(method: String, params: [Any], skipLoggingResult: Bool = false, completion: @escaping (Bool) -> Void) {
      let payload = ETHRequestPayload(
        method: method,
        params: params
      )

      print("Starting to test method ", method, "...")
      portal?.provider.request(payload: payload) { (result) -> Void in
        guard (result.error == nil) else {
          print("❌ Error testing provider request:", method, "Error:", result.error!)
          completion(false)
          return
        }

        if (!skipLoggingResult) {
          print("✅ ", method, "() result:", result.data!)
        } else {
          print("✅ ", method, "()")
        }

        completion(true)
      }

  }

  func testProviderTransactionRequest(method: String, params: [ETHTransactionParam], skipLoggingResult: Bool = false, completion: @escaping (Bool) -> Void) {
      let payload = ETHTransactionPayload(
        method: method,
        params: params
      )

      print("Starting to test method ", method, "...")
      portal?.provider.request(payload: payload) { (result: Result<TransactionCompletionResult>) -> Void in
        guard result.error == nil else {
          print("❌ Error testing provider request:", result.error!)
          completion(false)
          return
        }

        if (!skipLoggingResult) {
          print("✅ ", method, "() result:", result.data!.result)
        } else {
          print("✅ ", method, "()")
        }

        completion(true)
      }
  }

  func testProviderAddressRequest(method: String, params: [ETHAddressParam], skipLoggingResult: Bool = false, completion: @escaping (Bool) -> Void) {
      let payload = ETHAddressPayload(
        method: method,
        params: params
      )

      print("Starting to test method ", method, "...")
      portal?.provider.request(payload: payload) { (result: Result<AddressCompletionResult>) -> Void in
        guard result.error == nil else {
          print("❌ Error testing provider request:", result.error!)
          return
        }

        if (!skipLoggingResult) {
          print("✅ ", method, "() result:", result.data!.result)
        } else {
          print("✅ ", method, "()")
        }

        completion(true)
      }
  }

  func testSignerRequests() {
    print("Testing Signer Methods:\n")
    do {
      let fromAddress = try portal?.keychain.getAddress()
      guard fromAddress != nil else {
        print("❌ Error testing signer provider requests: address is nil")
        return
      }
      let signerRequests = [
        ProviderRequest(method: ETHRequestMethods.Accounts.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.RequestAccounts.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Sign.rawValue, params: [fromAddress!, "0xdeadbeaf"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.PersonalSign.rawValue, params: ["0xdeadbeaf", fromAddress!], skipLoggingResult: false),
        // ProviderRequest(method: ETHRequestMethods.SignTypedData.rawValue, params: [], skipLoggingResult: false),
      ]

      for request in signerRequests {
        testProviderRequest(method: request.method, params: request.params) { (success: Bool) -> Void in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing signer provider requests:", error)
      return
    }
  }

  func testWalletRequests() {
    print("\nTesting Wallet Methods:\n")
    let walletRequests = [
      // https://docs.metamask.io/guide/rpc-api.html#wallet-addethereumchain
      ProviderRequest(method: ETHRequestMethods.WalletAddEthereumChain.rawValue, params: [], skipLoggingResult: false),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-getpermissions
      ProviderRequest(method: ETHRequestMethods.WalletGetPermissions.rawValue, params: [], skipLoggingResult: false),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-registeronboarding
      ProviderRequest(method: ETHRequestMethods.WalletRegisterOnboarding.rawValue, params: [], skipLoggingResult: false),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-requestpermissions
      ProviderRequest(method: ETHRequestMethods.WalletRequestPermissions.rawValue, params: [], skipLoggingResult: false),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-switchethereumchain
      ProviderRequest(method: ETHRequestMethods.WalletSwitchEthereumChain.rawValue, params: [], skipLoggingResult: false),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-watchasset
      ProviderRequest(method: ETHRequestMethods.WalletWatchAsset.rawValue, params: [], skipLoggingResult: false)
    ]

    for request in walletRequests {
      testProviderRequest(method: request.method, params: request.params) { (success: Bool) -> Void in
        // Do something
      }
    }
  }

  func testOtherRequests() {
    print("\nTesting Other Requests:\n")
    do {
      let fromAddress = try portal?.keychain.getAddress()
      guard fromAddress != nil else {
        print("❌ Error testing other provider requests: address is nil")
        return
      }
      let otherRequests = [
        ProviderRequest(method: ETHRequestMethods.BlockNumber.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Coinbase.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.CompileLLL.rawValue, params: ["(returnlll (suicide (caller)))"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.CompileSerpent.rawValue, params: ["/* some serpent */"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.CompileSolidity.rawValue, params: ["contract test { function multiply(uint a) returns(uint d) {   return a * 7;   } }"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GasPrice.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBalance.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockByHash.rawValue, params: ["0xdc0818cf78f21a8e70579cb46a43643f78291264dda342ae31049421c82d21ae", false], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockByNumber.rawValue, params: ["latest", false], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockTransactionCountByHash.rawValue, params: ["0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockTransactionCountByNumber.rawValue, params: ["latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetCode.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetCompilers.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetFilterChange.rawValue, params: ["0x16"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetFilterLogs.rawValue, params: ["0x16"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionByBlockHashAndIndex.rawValue, params: ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331", "0x0"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionByBlockNumberAndIndex.rawValue, params: ["latest", "0x0"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionByHash.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionCount.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionReceipt.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleByBlockHashIndex.rawValue, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b", "0x0"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleByBlockNumberAndIndex.rawValue, params: ["latest", "0x0"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockHash.rawValue, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockNumber.rawValue, params: ["latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetWork.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Hashrate.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Mining.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NetListening.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NetPeerCount.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NetVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NewBlockFilter.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NewPendingTransactionFilter.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.ProtocolVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.SendRawTransaction.rawValue, params: ["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.SubmitHashrate.rawValue, params: ["0x0000000000000000000000000000000000000000000000000000000000500000", "0x59daa26581d0acd1fce254fb7e85952f4c09d0915afd33d3886cd914bc7d283c"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Synching.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.UninstallFilter.rawValue, params: ["0xb"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Web3ClientVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Web3Sha3.rawValue, params: ["0x68656c6c6f20776f726c64"], skipLoggingResult: false),
      ]

      for request in otherRequests {
        testProviderRequest(method: request.method, params: request.params) { (success: Bool) -> Void in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing other provider requests:", error)
      return
    }
  }

  func testTransactionRequests() {
    print("\nTesting Transaction Requests:\n")
    do {
      let fromAddress = try portal?.keychain.getAddress()
      let toAddress = "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7"
      let fakeTransaction = ETHTransactionParam(
        from: fromAddress!,
        to: toAddress,
        gas: "0x76c0",
        gasPrice: "0x9184e72a000",
        value: "0x9184e72a",
        data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
      )
      guard fromAddress != nil else {
        print("❌ Error testing transaction provider requests: address is nil")
        return
      }
      let requests = [
        ProviderTransactionRequest(method: ETHRequestMethods.Call.rawValue, params: [fakeTransaction], skipLoggingResult: false),
        ProviderTransactionRequest(method: ETHRequestMethods.EstimateGas.rawValue, params: [fakeTransaction], skipLoggingResult: false),
        ProviderTransactionRequest(method: ETHRequestMethods.GetStorageAt.rawValue, params: [], skipLoggingResult: false),
        ProviderTransactionRequest(method: ETHRequestMethods.SubmitWork.rawValue, params: [], skipLoggingResult: false),
        ProviderTransactionRequest(method: ETHRequestMethods.SendTransaction.rawValue, params: [fakeTransaction], skipLoggingResult: false),
        ProviderTransactionRequest(method: ETHRequestMethods.SignTransaction.rawValue, params: [fakeTransaction], skipLoggingResult: false),
      ]

      for request in requests {
        testProviderTransactionRequest(method: request.method, params: request.params) { (success: Bool) -> Void in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing other provider requests:", error)
      return
    }
  }

  func testAddressRequests() {
    print("\nTesting Address Requests:\n")
    do {
      let fromAddress = try portal?.keychain.getAddress()
      let fakeAddressParam = ETHAddressParam(address: fromAddress!)
      guard fromAddress != nil else {
        print("❌ Error testing transaction provider requests: address is nil")
        return
      }
      let requests = [
        ProviderAddressRequest(method: ETHRequestMethods.GetLogs.rawValue, params: [fakeAddressParam], skipLoggingResult: false),
        ProviderAddressRequest(method: ETHRequestMethods.NewFilter.rawValue, params: [fakeAddressParam], skipLoggingResult: false),
      ]

      for request in requests {
        testProviderAddressRequest(method: request.method, params: request.params) { (success: Bool) -> Void in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing other provider requests:", error)
      return
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
        testProviderRequest(method: method, params: [address!]) { (success: Bool) -> Void in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing signer methods:", error)
      return
    }
  }
}

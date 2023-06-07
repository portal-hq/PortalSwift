//
//  ViewController.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import PortalSwift

struct SignUpBody: Codable {
  var username: String
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
  // Static information
  @IBOutlet weak var addressInformation: UITextView!
  @IBOutlet weak var ethBalanceInformation: UITextView!

  // Buttons
  @IBOutlet weak var backupButton: UIButton!
  @IBOutlet weak var dappBrowserButton: UIButton!
  @IBOutlet weak var generateButton: UIButton!
  @IBOutlet weak var logoutButton: UIButton!
  @IBOutlet weak var portalConnectButton: UIButton!
  @IBOutlet weak var recoverButton: UIButton!
  @IBOutlet weak var signInButton: UIButton!
  @IBOutlet weak var signUpButton: UIButton!
  @IBOutlet weak var testButton: UIButton!
  
  // Send form
  @IBOutlet public var sendAddress: UITextField!
  @IBOutlet public var sendButton: UIButton!
  @IBOutlet public var username: UITextField!
  @IBOutlet public var url: UITextField!
  
  
  public var user: UserResult?
  public var CUSTODIAN_SERVER_URL: String?
  public var API_URL: String?
  public var MPC_URL: String?
  public var PortalWrapper: PortalWrapper = PortalSwift_Example.PortalWrapper()
  public var portal: Portal?
  public var eth_estimate: String?

  
  override func viewDidLoad() {
    super.viewDidLoad()
    let PROD_CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"
    let STAGING_CUSTODIAN_SERVER_URL = "https://staging-portalex-mpc-service.onrender.com"
    let PROD_API_URL = "api.portalhq.io"
    let PROD_MPC_URL = "mpc.portalhq.io"
    let STAGING_API_URL = "api-staging.portalhq.io"
    let STAGING_MPC_URL = "mpc-staging.portalhq.io"
    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Couldnt load info plist")
      return }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return  }
    print("ENV in the view controller", ENV)
    if (ENV == "prod") {
      CUSTODIAN_SERVER_URL = PROD_CUSTODIAN_SERVER_URL
      API_URL = PROD_API_URL
      MPC_URL = PROD_MPC_URL
    } else {
      CUSTODIAN_SERVER_URL = STAGING_CUSTODIAN_SERVER_URL
      API_URL = STAGING_API_URL
      MPC_URL = STAGING_MPC_URL
    }
    
    DispatchQueue.main.async {
      self.backupButton.isEnabled = false
      self.dappBrowserButton.isEnabled = false
      self.generateButton.isEnabled = false
      self.logoutButton.isEnabled = false
      self.portalConnectButton.isEnabled = false
      self.recoverButton.isEnabled = false
      self.signInButton.isEnabled = false
      self.signUpButton.isEnabled = false
      self.testButton.isEnabled = false
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let connectViewController = segue.destination as? ConnectViewController {
      connectViewController.portal = self.portal
    }
  }

  @IBAction func handleSignIn(_ sender: UIButton) {
    PortalWrapper.signIn(username: username.text!) { (result: Result<UserResult>) -> Void in
      guard (result.error == nil) else {
        print(" ❌ handleSignIn(): Failed", result.error!)
        return
      }
      print("✅ handleSignIn(): API key:", result.data!.clientApiKey)
      self.user = result.data!
      self.registerPortalUi(apiKey: result.data!.clientApiKey)
      self.updateStaticContent()
      self.portal = self.PortalWrapper.portal
      
      DispatchQueue.main.async {
        self.logoutButton.isEnabled = true
      }
    }
  }

  @IBAction func handleSignup(_ sender: UIButton) {
    PortalWrapper.signUp(username: username.text!) { (result: Result<UserResult>) -> Void in
      guard (result.error == nil) else {
        print(" ❌ handleSignIn(): Failed", result.error!)
        return
      }
      print("✅ handleSignup(): API key:", result.data!.clientApiKey)
      self.user = result.data
      self.registerPortalUi(apiKey: result.data!.clientApiKey)
      self.updateStaticContent()
      self.portal = self.PortalWrapper.portal

      DispatchQueue.main.async {
        self.logoutButton.isEnabled = true
      }
    }
  }

  @IBAction func handleSignOut(_ sender: UIButton) {
    self.user = nil
    self.addressInformation.text = "Address: N/A"
    self.ethBalanceInformation.text = "ETH Balance: N/A"
    
    DispatchQueue.main.async {
      self.logoutButton.isEnabled = false
    }
  }

  @IBAction func handleGenerate(_ sender: UIButton!) {
    PortalWrapper.generate() { (result) -> Void in
      guard result.error == nil else {
        print("❌ handleGenerate():", result.error ?? "N/A")
        return
      }
      print("✅ handleGenerate(): Address:", result.data ?? "N/A")
      self.updateStaticContent()
      
      DispatchQueue.main.async {
        self.backupButton.isEnabled = true
        self.dappBrowserButton.isEnabled = true
        self.portalConnectButton.isEnabled = true
        self.recoverButton.isEnabled = true
        self.testButton.isEnabled = true
      }
    }
  }

  @IBAction func handleBackup(_ sender: UIButton!) {
    print("Starting backup...")
    // PortalWrapper.backup(backupMethod: BackupMethods.GoogleDrive.rawValue, user: self.user!) { (result) -> Void in
    PortalWrapper.backup(backupMethod: BackupMethods.iCloud.rawValue, user: self.user!) { (result) -> Void in
      guard result.error == nil else {
        print("❌ handleBackup():",  result.error!)
        return
      }
      print("✅ handleBackup(): Successfully sent custodian cipherText")
    }
  }

  @IBAction func handleRecover(_ sender: UIButton!) {
    // PortalWrapper.recover(backupMethod: BackupMethods.GoogleDrive.rawValue, user: self.user!) { (result) -> Void in
    PortalWrapper.recover(backupMethod: BackupMethods.iCloud.rawValue, user: self.user!) { (result) -> Void in
      guard result.error == nil else {
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        return
      }
      
      self.updateStaticContent()
    }
  }

  @IBAction func sendPressed(_ sender: UIButton!) {
    handleSend()
  }

  @IBAction func usernameChanged(_ sender: Any) {
    let hasUsername = username.text?.count ?? 0 > 3
    
    signInButton.isEnabled = hasUsername
    signUpButton.isEnabled = hasUsername
  }
  
  @IBAction func testProviderRequests(_ sender: UIButton!) {
    print("\n====================\nTesting provider methods\n====================")
    testSignerRequests()
    // testWalletRequests()
    testOtherRequests()
    testTransactionRequests()
//    testAddressRequests()
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
    retrieveNFTs()
    getTransactions()
    getBalances()
//     populateEthBalance()
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
  
  func retrieveNFTs() -> Void {
    do {
      try self.portal?.api.getNFTs() { (results) -> Void in
        guard results.error == nil else {
          print("❌ Unable to retrieve NFTs", results.error!)
          return
        }
        
        print("✅ Retrieved NFTs", results.data!)
      }
    } catch {
      print("❌ Unable to retrieve NFTs", error)
    }
  }
  
  func getTransactions() -> Void {
    do {
      try self.portal?.api.getTransactions() { (results) -> Void in
        guard results.error == nil else {
          print("❌ Unable to get transactions", results.error!)
          return
        }
        
        print("✅ Retrieved transactions", results.data!)
      }
    } catch {
      print("❌ Unable to retrieve transactions", error)
    }
  }
  
  func getBalances() -> Void {
    do {
      try self.portal?.api.getBalances() { (results) -> Void in
        guard results.error == nil else {
          print("❌ Unable to get balances", results.error!)
          return
        }
        
        print("✅ Retrieved balances", results.data!)
      }
    } catch {
      print("❌ Unable to retrieve balances", error)
    }
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
        let res = (result.data!.result as! ETHGatewayResponse)
        print("✅ Balance result:", res.result)
        DispatchQueue.main.async {
          self.ethBalanceInformation.text = "ETH Balance: \(self.parseETHBalanceHex(hex: res.result as! String)) ETH"
        }
      }
    } catch {
      print("❌ Error getting ETH balance:", error)
    }
  }

    func handleSend() {
        let payload = ETHTransactionPayload(
            method: ETHRequestMethods.GasPrice.rawValue,
            params: []
        )
        portal?.provider.request(payload: payload) {
            (result: Result<TransactionCompletionResult>) -> Void in
            guard result.error == nil else {
                print("❌ Error estimating gas:", result.error!)
                return
            }
            let response = result.data!.result as! ETHGatewayResponse
            if (response.result != nil) {
                self.sendTransaction(ethEstimate: response.result!)
            }
        }
    }
    
    func sendTransaction (ethEstimate: String) {
        let payload = ETHTransactionPayload(
              method: ETHRequestMethods.SendTransaction.rawValue,
              params: [ETHTransactionParam(from: portal!.mpc.getAddress(), to: sendAddress.text!, gas: ethEstimate, gasPrice: ethEstimate, value: "0x10", data: "")]
               // Test EIP-1559 Transactions with these params
            // params: [ETHTransactionParam(from: portal!.mpc.getAddress(), to: sendAddress.text!,  gas:"0x5208", value: "0x10", data: "", maxPriorityFeePerGas: ethEstimate, maxFeePerGas: ethEstimate)]
            )
      
        portal?.provider.request(payload: payload) {
            (result: Result<TransactionCompletionResult>) -> Void in
            guard result.error == nil else {
              print("❌ Error sending transaction:", result.error!)
              return
            }
          guard (result.data!.result as! Result<Any>).error == nil else {
            print("❌ Error sending transaction:", ((result.data!.result as! Result<Any>).error))
            return
          }
            print("✅ handleSend(): Result:", result.data!.result)
          }
    }

  func registerPortalUi(apiKey: String) -> Void {
    
    do {
      //      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      //        print("Couldnt load info plist")
      //        return }
      //      guard let GDRIVE_CLIENT_ID: String = infoDictionary["GDRIVE_CLIENT_ID"] as? String else {
      //        print("Error: Do you have `GDRIVE_CLIENT_ID=$(GDRIVE_CLIENT_ID)` in your info.plist?")
      //        return  }
      //      let backup = BackupOptions(gdrive: GDriveStorage(clientID: GDRIVE_CLIENT_ID, viewController: self))
      let backup = BackupOptions(icloud: ICloudStorage())
      PortalWrapper.registerPortal(apiKey: apiKey, backup: backup) { (result) -> Void in
        DispatchQueue.main.async {
          do {
            self.generateButton.isEnabled = true
            
            let address = try self.portal?.keychain.getAddress()
            let hasAddress = address?.count ?? 0 > 0
            
            self.backupButton.isEnabled = hasAddress
            self.dappBrowserButton.isEnabled = hasAddress
            self.portalConnectButton.isEnabled = hasAddress
            self.recoverButton.isEnabled = hasAddress
            self.testButton.isEnabled = hasAddress
          } catch {
            print("Error fetching address: \(error)")
          }
        }
      }
    }
  }
  
  func didRequestApproval(data: Any) -> Void {
    _ = portal?.provider.emit(event: Events.PortalSigningApproved.rawValue, data: data)
  }

  func onError(result: Result<Any>) -> Void {
    print("PortalWebviewError:", result.error!, "Description:", result.error!.localizedDescription)
    guard result.error == nil else {
       print("❌ Error in PortalWebviewError:", result.error)
       return
    }
    guard ((result.data! as AnyObject).result as! Result<Any>).error == nil else {
      print("❌ Error in PortalWebviewError:", ((result.data as! AnyObject).result as! Result<Any>))
      return
    }
  }

  func injectWebView() {
    let webViewController = PortalWebView(portal: portal!, url: URL(string: url.text!)!, onError: onError)
    // Install the WebViewController as a child view controller.
      addChild(webViewController)
      let webViewControllerView = webViewController.view!
      view.addSubview(webViewControllerView)
      webViewController.didMove(toParent: self)
    
  }

  func testProviderRequest(method: String, params: [Any], skipLoggingResult: Bool = false, completion: @escaping (Bool) -> Void) {
      let payload = ETHRequestPayload(
        method: method,
        params: params
      )

      print("Starting to test method ", method, "...")
    portal?.provider.request(payload: payload) { (result: Result<RequestCompletionResult>) -> Void in
      guard (result.error == nil) else {
          print("❌ Error testing provider request:", method, "Error:", result.error!)
          completion(false)
          return
        }
      if (signerMethods.contains(method)) {
        guard ((result.data!.result as! Result<SignerResult>).error == nil) else {
            print("❌ Error testing signer request:", method, "Error:", (result.data!.result as! Result<SignerResult>).error)
            completion(false)
            return
          }
        if ((result.data!.result as! Result<SignerResult>).data!.signature != nil) {
          print("✅ Signature for", method,(result.data!.result as! Result<SignerResult>).data!.signature)
        } else {
          print("✅ Accounts for", method,(result.data!.result as! Result<SignerResult>).data!.accounts)
        }
      } else {
        guard ((result.data!.result as! ETHGatewayResponse).error == nil) else {
          print("❌ Error testing provider request:", method, "Error:", (result.data!.result as! ETHGatewayResponse).error)
            completion(false)
            return
          }
        print("✅ Gateway response for", method, (result.data!.result as! ETHGatewayResponse).result)
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
          print("❌ Error testing provider transaction request:", method, result.error!)
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
          print("❌ Error testing provider request:", method, result.error!)
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
        ProviderRequest(method: ETHRequestMethods.GasPrice.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBalance.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockByHash.rawValue, params: ["0xdc0818cf78f21a8e70579cb46a43643f78291264dda342ae31049421c82d21ae", false], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetBlockTransactionCountByNumber.rawValue, params: ["latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetCode.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionByHash.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionCount.rawValue, params: [fromAddress!, "latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetTransactionReceipt.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleByBlockHashIndex.rawValue, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b", "0x0"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockHash.rawValue, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetUncleCountByBlockNumber.rawValue, params: ["latest"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NetVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NewBlockFilter.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.NewPendingTransactionFilter.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.ProtocolVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.SendRawTransaction.rawValue, params: ["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Web3ClientVersion.rawValue, params: [], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.Web3Sha3.rawValue, params: ["0x68656c6c6f20776f726c64"], skipLoggingResult: false),
        ProviderRequest(method: ETHRequestMethods.GetStorageAt.rawValue, params: [fromAddress, "0x0", "latest"], skipLoggingResult: false),

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

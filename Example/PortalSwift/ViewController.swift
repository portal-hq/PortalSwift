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

class ViewController: UIViewController, UITextFieldDelegate {
  // Static information
  @IBOutlet var addressInformation: UITextView!
  @IBOutlet var ethBalanceInformation: UITextView!

  // Buttons
  @IBOutlet var backupButton: UIButton!
  @IBOutlet var dappBrowserButton: UIButton!
  @IBOutlet var generateButton: UIButton!
  @IBOutlet var logoutButton: UIButton!
  @IBOutlet var portalConnectButton: UIButton!
  @IBOutlet var recoverButton: UIButton!
  @IBOutlet var signButton: UIButton!
  @IBOutlet var signInButton: UIButton!
  @IBOutlet var signUpButton: UIButton!
  @IBOutlet var testButton: UIButton!
  @IBOutlet var deleteKeychainButton: UIButton!
  @IBOutlet var testNFTsTrxsBalancesButton: UIButton!

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

    self.username.delegate = self
    self.sendAddress.delegate = self
    self.url.delegate = self

    let PROD_CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"
    let STAGING_CUSTODIAN_SERVER_URL = "https://staging-portalex-mpc-service.onrender.com"
    let PROD_API_URL = "api.portalhq.io"
    let PROD_MPC_URL = "mpc.portalhq.io"
    let STAGING_API_URL = "api-staging.portalhq.io"
    let STAGING_MPC_URL = "mpc-staging.portalhq.io"
    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Couldnt load info plist")
      return
    }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return
    }
    print("ENV in the view controller", ENV)
    if ENV == "prod" {
      self.CUSTODIAN_SERVER_URL = PROD_CUSTODIAN_SERVER_URL
      self.API_URL = PROD_API_URL
      self.MPC_URL = PROD_MPC_URL
    } else {
      self.CUSTODIAN_SERVER_URL = STAGING_CUSTODIAN_SERVER_URL
      self.API_URL = STAGING_API_URL
      self.MPC_URL = STAGING_MPC_URL
    }

    DispatchQueue.main.async {
      self.backupButton.isEnabled = false
      self.dappBrowserButton.isEnabled = false
      self.generateButton.isEnabled = false
      self.logoutButton.isEnabled = false
      self.portalConnectButton.isEnabled = false
      self.recoverButton.isEnabled = false
      self.signButton.isEnabled = false
      self.signInButton.isEnabled = false
      self.signUpButton.isEnabled = false
      self.testButton.isEnabled = false
      self.deleteKeychainButton.isEnabled = false
      self.testNFTsTrxsBalancesButton.isEnabled = false
      self.sendButton.isEnabled = false
    }
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    textField.endEditing(true)

    return true
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    if let connectViewController = segue.destination as? ConnectViewController {
      connectViewController.portal = self.portal
    }

    if let webViewController = segue.destination as? WebViewController {
      webViewController.portal = self.portal
      webViewController.url = self.url.text
    }
  }

  @IBAction func handleSignIn(_: UIButton) {
    print("signIn", self.PortalWrapper, self.PortalWrapper.signIn)

    self.PortalWrapper.signIn(username: self.username.text!) { (result: Result<UserResult>) in
      guard result.error == nil else {
        print(" ❌ handleSignIn(): Failed", result.error!)
        return
      }
      print("✅ handleSignIn(): API key:", result.data!.clientApiKey)
      self.user = result.data!
      self.registerPortalUi(apiKey: result.data!.clientApiKey)
      self.portal = self.PortalWrapper.portal
      self.populateAddressInformation()

      DispatchQueue.main.async {
        self.logoutButton.isEnabled = true
      }
    }
  }

  @IBAction func handleSignup(_: UIButton) {
    print("signUp", self.PortalWrapper, self.PortalWrapper.signUp)
    self.PortalWrapper.signUp(username: self.username.text!) { (result: Result<UserResult>) in
      guard result.error == nil else {
        print(" ❌ handleSignIn(): Failed", result.error!)
        return
      }
      print("✅ handleSignup(): API key:", result.data!.clientApiKey)
      self.user = result.data
      self.registerPortalUi(apiKey: result.data!.clientApiKey)
      self.portal = self.PortalWrapper.portal
      self.populateAddressInformation()

      DispatchQueue.main.async {
        self.logoutButton.isEnabled = true
      }
    }
  }

  @IBAction func handleSignOut(_: UIButton) {
    self.user = nil
    self.addressInformation.text = "Address: N/A"
    self.ethBalanceInformation.text = "ETH Balance: N/A"

    DispatchQueue.main.async {
      self.logoutButton.isEnabled = false
    }
  }

  @IBAction func handleGenerate(_: UIButton!) {
    self.PortalWrapper.generate { result in
      guard result.error == nil else {
        print("❌ handleGenerate():", result.error ?? "N/A")
        return
      }
      print("✅ handleGenerate(): Address:", result.data ?? "N/A")
      self.populateAddressInformation()

      DispatchQueue.main.async {
        self.backupButton.isEnabled = true
        self.dappBrowserButton.isEnabled = true
        self.portalConnectButton.isEnabled = true
        self.recoverButton.isEnabled = true
        self.testButton.isEnabled = true
        self.signButton.isEnabled = true
        self.deleteKeychainButton.isEnabled = true
        self.testNFTsTrxsBalancesButton.isEnabled = true
        self.sendButton.isEnabled = true
      }
    }
  }

  @IBAction func handleBackup(_: UIButton!) {
    print("Starting backup...")
    // PortalWrapper.backup(backupMethod: BackupMethods.GoogleDrive.rawValue, user: self.user!) { (result) -> Void in
    self.PortalWrapper.backup(backupMethod: BackupMethods.iCloud.rawValue, user: self.user!) { result in
      guard result.error == nil else {
        print("❌ handleBackup():", result.error!)

        do {
          try self.PortalWrapper.portal!.api.storedClientBackupShare(success: false) { result in
            guard result.error == nil else {
              print("❌ handleBackup(): Error notifying Portal that backup share was not stored.")
              return
            }
          }
        } catch {
          print("❌ handleBackup(): Error notifying Portal that backup share was not stored.")
        }
        return
      }

      do {
        try self.PortalWrapper.portal!.api.storedClientBackupShare(success: true) { result in
          guard result.error == nil else {
            print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
            return
          }

          self.populateAddressInformation()
          print("✅ handleBackup(): Successfully sent custodian cipherText")
        }
      } catch {
        print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
      }
    }
  }

  @IBAction func handleRecover(_: UIButton!) {
    // PortalWrapper.recover(backupMethod: BackupMethods.GoogleDrive.rawValue, user: self.user!) { (result) -> Void in
    self.PortalWrapper.recover(backupMethod: BackupMethods.iCloud.rawValue, user: self.user!) { result in
      guard result.error == nil else {
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        do {
          try self.PortalWrapper.portal!.api.storedClientBackupShare(success: false) { result in
            guard result.error == nil else {
              print("❌ handleRecover(): Error notifying Portal that backup share was not stored.")
              return
            }
          }
        } catch {
          print("❌ handleRecover(): Error notifying Portal that backup share was not stored.")
        }
        return
      }

      do {
        try self.PortalWrapper.portal!.api.storedClientBackupShare(success: true) { result in
          guard result.error == nil else {
            print("❌ handleRecover(): Error notifying Portal that backup share was stored.")
            return
          }

          self.populateAddressInformation()
          print("✅ handleRecover(): Successfully recovered")
        }
      } catch {
        print("❌ handleRecover(): Error notifying Portal that backup share was stored.")
      }
    }
  }

  @IBAction func sendPressed(_: UIButton!) {
    self.handleSend()
  }

  @IBAction func usernameChanged(_: Any) {
    let hasUsername = self.username.text?.count ?? 0 > 3

    self.signInButton.isEnabled = hasUsername
    self.signUpButton.isEnabled = hasUsername
  }

  @IBAction func testProviderRequests(_: UIButton!) {
    print("\n====================\nTesting provider methods\n====================")
    self.testSignerRequests()
    // testWalletRequests()
    self.testOtherRequests()
    self.testTransactionRequests()
//    testAddressRequests()
    print("====================\n[FINISHED] Testing provider methods\n====================\n")
  }

  @IBAction func handleDeleteKeychain(_: Any) {
    self.deleteKeychain()
    self.populateAddressInformation()
  }

  func deleteKeychain() {
    do {
      try self.portal?.deleteAddress()
      try self.portal?.deleteSigningShare()
      print("✅ Deleted keychain")
    } catch {
      print("❌ Delete keychain error:", error)
    }
  }

  @IBAction func fetchNFTsAndTrxsAndBalances() {
    self.retrieveNFTs()
    self.getTransactions()
    self.getBalances()
  }

  func populateAddressInformation() {
    do {
      let address = self.portal?.address
      print("Address", address)

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
    let ethBalance = Double(hexInt) / 1_000_000_000_000_000_000
    return String(ethBalance)
  }

  func retrieveNFTs() {
    do {
      try self.portal?.api.getNFTs { results in
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

  func getTransactions() {
    do {
      try self.portal?.api.getTransactions { results in
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

  func getBalances() {
    do {
      try self.portal?.api.getBalances { results in
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
      let address = self.portal?.address
      guard address != nil else {
        print("❌ populateEthBalance(): Error getting address")
        return
      }
      let payload = ETHRequestPayload(
        method: ETHRequestMethods.GetBalance.rawValue,
        params: [address!, "latest"]
      )
      self.portal?.provider.request(payload: payload) {
        (result: Result<RequestCompletionResult>) in
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
    self.portal?.provider.request(payload: payload) {
      (result: Result<TransactionCompletionResult>) in
      guard result.error == nil else {
        print("❌ Error estimating gas:", result.error!)
        return
      }
      let response = result.data!.result as! ETHGatewayResponse
      if response.result != nil {
        self.sendTransaction(ethEstimate: response.result!)
      }
    }
  }

  @IBAction func handleSign() {
    do {
      let address = try portal?.address

      let payload = ETHRequestPayload(
        method: ETHRequestMethods.PersonalSign.rawValue,
        params: [address!, "0xdeadbeef"]
      )

      self.portal?.provider.request(payload: payload) {
        (result: Result<RequestCompletionResult>) in
        guard result.error == nil else {
          print("❌ Error estimating gas:", result.error!)
          return
        }

        print("✅ handleSign(): Successfully signed:", result.data!)
      }
    } catch {
      print("[ViewController] handleSign(): unable to read address from keychain")
    }
  }

  func sendTransaction(ethEstimate: String) {
    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [ETHTransactionParam(from: self.portal!.address!, to: self.sendAddress.text!, gas: ethEstimate, gasPrice: ethEstimate, value: "0x10", data: "")]
      // Test EIP-1559 Transactions with these params
      // params: [ETHTransactionParam(from: portal!.mpc.getAddress(), to: sendAddress.text!,  gas:"0x5208", value: "0x10", data: "", maxPriorityFeePerGas: ethEstimate, maxFeePerGas: ethEstimate)]
    )

    self.portal?.provider.request(payload: payload) {
      (result: Result<TransactionCompletionResult>) in
      guard result.error == nil else {
        print("❌ Error sending transaction:", result.error!)
        return
      }
      guard (result.data!.result as! Result<Any>).error == nil else {
        print("❌ Error sending transaction:", (result.data!.result as! Result<Any>).error)
        return
      }
      print("✅ handleSend(): Result:", result.data!.result)
    }
  }

  func registerPortalUi(apiKey: String) {
    do {
      //      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      //        print("Couldnt load info plist")
      //        return }
      //      guard let GDRIVE_CLIENT_ID: String = infoDictionary["GDRIVE_CLIENT_ID"] as? String else {
      //        print("Error: Do you have `GDRIVE_CLIENT_ID=$(GDRIVE_CLIENT_ID)` in your info.plist?")
      //        return  }
      //      let backup = BackupOptions(gdrive: GDriveStorage(clientID: GDRIVE_CLIENT_ID, viewController: self))
      let backup = BackupOptions(icloud: ICloudStorage(containerIdentifier: "iCloud.io.portalhq.demo"))
      self.PortalWrapper.registerPortal(apiKey: apiKey, backup: backup) { _ in
        DispatchQueue.main.async {
          do {
            self.generateButton.isEnabled = true

            let address = try self.portal?.address
            let hasAddress = address?.count ?? 0 > 0

            self.backupButton.isEnabled = hasAddress
            self.dappBrowserButton.isEnabled = hasAddress
            self.portalConnectButton.isEnabled = hasAddress
            self.recoverButton.isEnabled = hasAddress
            self.testButton.isEnabled = hasAddress
            self.signButton.isEnabled = hasAddress
            self.deleteKeychainButton.isEnabled = hasAddress
            self.testNFTsTrxsBalancesButton.isEnabled = hasAddress
            self.sendButton.isEnabled = hasAddress
          } catch {
            print("Error fetching address: \(error)")
          }
        }
      }
    }
  }

  func testProviderRequest(method: String, params: [Any], skipLoggingResult _: Bool = false, completion: @escaping (Bool) -> Void) {
    let payload = ETHRequestPayload(
      method: method,
      params: params
    )

    print("Starting to test method ", method, "...")
    self.portal?.provider.request(payload: payload) { (result: Result<RequestCompletionResult>) in
      guard result.error == nil else {
        print("❌ Error testing provider request:", method, "Error:", result.error!)
        completion(false)
        return
      }
      if signerMethods.contains(method) {
        guard (result.data!.result as! Result<SignerResult>).error == nil else {
          print("❌ Error testing signer request:", method, "Error:", (result.data!.result as! Result<SignerResult>).error)
          completion(false)
          return
        }
        if (result.data!.result as! Result<SignerResult>).data!.signature != nil {
          print("✅ Signature for", method, (result.data!.result as! Result<SignerResult>).data!.signature)
        } else {
          print("✅ Accounts for", method, (result.data!.result as! Result<SignerResult>).data!.accounts)
        }
      } else {
        guard (result.data!.result as! ETHGatewayResponse).error == nil else {
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
    self.portal?.provider.request(payload: payload) { (result: Result<TransactionCompletionResult>) in
      guard result.error == nil else {
        print("❌ Error testing provider transaction request:", method, result.error!)
        completion(false)
        return
      }

      if !skipLoggingResult {
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
    self.portal?.provider.request(payload: payload) { (result: Result<AddressCompletionResult>) in
      guard result.error == nil else {
        print("❌ Error testing provider request:", method, result.error!)
        return
      }

      if !skipLoggingResult {
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
      let fromAddress = try portal?.address
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
        self.testProviderRequest(method: request.method, params: request.params) { (_: Bool) in
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
      ProviderRequest(method: ETHRequestMethods.WalletWatchAsset.rawValue, params: [], skipLoggingResult: false),
    ]

    for request in walletRequests {
      self.testProviderRequest(method: request.method, params: request.params) { (_: Bool) in
        // Do something
      }
    }
  }

  func testOtherRequests() {
    print("\nTesting Other Requests:\n")
    do {
      let fromAddress = try portal?.address
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
        self.testProviderRequest(method: request.method, params: request.params) { (_: Bool) in
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
      let fromAddress = try portal?.address
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
        self.testProviderTransactionRequest(method: request.method, params: request.params) { (_: Bool) in
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
    self.testUnsupportedSignerRequests()
  }

  func testUnsupportedSignerRequests() {
    print("\nTesting Unsupported Signer Methods:\n")
    let unsupportedSignerMethods = [
      ETHRequestMethods.ChainId.rawValue,
    ]

    do {
      let address = try portal?.address
      guard address != nil else {
        print("❌ testUnsupportedSignerRequests(): Error getting address")
        return
      }
      for method in unsupportedSignerMethods {
        self.testProviderRequest(method: method, params: [address!]) { (_: Bool) in
          // Do something
        }
      }
    } catch {
      print("❌ Error testing signer methods:", error)
      return
    }
  }
}

//
//  ViewController.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import os.log
import PortalSwift
import UIKit

struct UserResult: Codable {
  var clientApiKey: String
  var exchangeUserId: Int
}

struct CipherTextResult: Codable {
  var cipherText: String
}

struct OrgShareResult: Codable {
  var orgShare: String
}

struct SignUpBody: Codable {
  var username: String
}

struct ProviderRequest {
  var method: PortalRequestMethod
  var params: [Any]
}

@available(iOS 16.0, *)
class ViewController: UIViewController, UITextFieldDelegate {
  var activityIndicator: UIActivityIndicatorView!
  var overlayView: UIView!

  // Static information
  @IBOutlet var addressInformation: UITextView?
  @IBOutlet var ethBalanceInformation: UITextView?

  // Buttons
  @IBOutlet var dappBrowserButton: UIButton?
  @IBOutlet var generateButton: UIButton?
  @IBOutlet var logoutButton: UIButton?
  @IBOutlet var portalConnectButton: UIButton?

  @IBOutlet var personalSignButton: UIButton?
  @IBOutlet var signButton: UIButton?
  @IBOutlet var signInButton: UIButton?
  @IBOutlet var signUpButton: UIButton?
  @IBOutlet var testButton: UIButton?
  @IBOutlet var deleteKeychainButton: UIButton?
  @IBOutlet var testNFTsTrxsBalancesSimTrxButton: UIButton?
  @IBOutlet var ejectButton: UIButton?

  @IBOutlet var passkeyBackupButton: UIButton?
  @IBOutlet var passkeyRecoverButton: UIButton?
  @IBOutlet var passwordBackupButton: UIButton!
  @IBOutlet var passwordRecoverButton: UIButton!
  @IBOutlet var gdriveBackupButton: UIButton!
  @IBOutlet var gdriveRecoverButton: UIButton!
  @IBOutlet var iCloudBackupButton: UIButton!
  @IBOutlet var iCloudRecoverButton: UIButton!

  // Send form
  @IBOutlet public var sendAddress: UITextField?
  @IBOutlet public var sendButton: UIButton?
  @IBOutlet public var sendUniButton: UIButton?
  @IBOutlet public var username: UITextField?
  @IBOutlet public var url: UITextField?

  public var user: UserResult?

  private var config: ApplicationConfiguration? {
    get {
      if let appDelegate = UIApplication.shared.delegate as? PortalExampleAppDelegate {
        return appDelegate.config
      }

      return nil
    }
    set(config) {
      if var appDelegate = UIApplication.shared.delegate as? PortalExampleAppDelegate {
        appDelegate.config = config
      }
    }
  }

  private var portal: Portal? {
    get {
      if let appDelegate = UIApplication.shared.delegate as? PortalExampleAppDelegate {
        return appDelegate.portal
      }

      return nil
    }
    set(portal) {
      if var appDelegate = UIApplication.shared.delegate as? PortalExampleAppDelegate {
        appDelegate.portal = portal
      }
    }
  }

  private let decoder = JSONDecoder()
  private let logger = Logger()
  private let requests = PortalRequests()

  // Set up the scroll view
  @IBOutlet var scrollView: UIScrollView!
  override func viewDidLoad() {
    super.viewDidLoad()

    // Set up application using Secrets.xcconfig
    self.loadApplicationConfig()

    // Set up UI components
    self.prepareUIComponents()

    // Set proper visibility states
    self.updateUIComponents()
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
      webViewController.url = self.url?.text
    }
  }

  /***********************************************
   * Portal functions
   ***********************************************/

  public func backup(_ userId: String, withMethod: BackupMethods) async throws -> String {
    guard let portal else {
      self.logger.error("ViewController.backup() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let config else {
      self.logger.error("ViewController.backup() - Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    self.logger.debug("ViewController.backup() - Starting backup...")
    let (cipherText, storageCallback) = try await portal.backupWallet(withMethod) { status in
      self.logger.debug("ViewController.backup() - Backup progress callback with status: \(status.status.rawValue), \(status.done)")
    }

    guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(userId)/cipher-text") else {
      throw URLError(.badURL)
    }
    let payload = [
      "backupMethod": withMethod.rawValue,
      "cipherText": cipherText,
    ]

    let resultData = try await requests.post(url, andPayload: payload)
    guard let result = String(data: resultData, encoding: .utf8) else {
      self.logger.error("ViewController.backup() - Unable to parse response from cipherText storage request to custodian.")
      throw PortalExampleAppError.couldNotParseCustodianResponse()
    }

    try await storageCallback()

    return result
  }

  public func deleteKeychain() async {
    do {
      guard let portal else {
        self.logger.error("ViewController.deleteKeychain() - Portal not initialized. Please call registerPortal().")
        throw PortalExampleAppError.portalNotInitialized()
      }

      try await portal.deleteShares()
      try portal.deleteAddress()
      try portal.deleteSigningShare()
      self.logger.debug("ViewController.deleteKeychain() - ✅ Deleted keychain data")
    } catch {
      self.logger.error("ViewController.deleteKeychain() - ❌ Error deleting keychain data: \(error.localizedDescription)")
    }
  }

  public func eject(_ withBackupMethod: BackupMethods) async throws -> String {
    guard let portal else {
      self.logger.error("ViewController.eject() - ❌ Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let user else {
      self.logger.error("ViewController.eject() - ❌ User not logged in.")
      throw PortalExampleAppError.userNotLoggedIn()
    }
    guard let config else {
      self.logger.error("ViewController.recover() - ❌ Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }
    guard let cipherTextUrl = URL(
      string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(withBackupMethod.rawValue)"
    ) else {
      throw URLError(.badURL)
    }
    let cipherTextData = try await requests.get(cipherTextUrl)
    let cipherTextResponse = try decoder.decode(CipherTextResult.self, from: cipherTextData)

    guard let organizationBackupShareUrl = URL(
      string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(withBackupMethod.rawValue)-SECP256K1"
    ) else {
      throw URLError(.badURL)
    }
    let organizationBackupShareData = try await requests.get(organizationBackupShareUrl)
    let organizationBackupShareResponse = try decoder.decode(OrgShareResult.self, from: organizationBackupShareData)

    let privateKey = try await portal.eject(
      withBackupMethod,
      withCipherText: cipherTextResponse.cipherText,
      andOrganizationBackupShare: organizationBackupShareResponse.orgShare
    )

    return privateKey
  }

  public func generate() async throws -> PortalCreateWalletResponse {
    guard let portal else {
      self.logger.error("PortalWrapper.generate() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.createWallet()
  }

  func getBalances() async throws -> [FetchedBalance] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    let chainId = "eip155:11155111"
    let balances = try await portal.getBalances(chainId)

    return balances
  }

  public func getGasPrice(_ chainId: String) async throws {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    let gasPriceResponse = try await portal.request(chainId, withMethod: .eth_gasPrice, andParams: [])

    print("Gas price response: \(gasPriceResponse)")

//    return gasPriceResponse.result
  }

  public func getNFTs(_ chainId: String) async throws -> [FetchedNFT] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.getNFTs(chainId)
  }

  public func getShareMetadata() async throws -> [FetchedSharePair] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    let backupShares = try await portal.getBackupShares()
    self.logger.info("ViewController.getShareMetadata() - ✅ Successfully fetched backup shares.")

    let signingShares = try await portal.getSigningShares()
    self.logger.info("ViewController.getShareMetadata() - ✅ Successfully fetched signing shares.")

    let shares = backupShares + signingShares
    return shares
  }

  public func getTransactions(_ chainId: String) async throws -> [FetchedTransaction] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.getTransactions(chainId)
  }

  public func recover(_ userId: String, withBackupMethod: BackupMethods) async throws -> PortalCreateWalletResponse {
    guard let portal else {
      self.logger.error("ViewController.recover() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let config else {
      self.logger.error("ViewController.recover() - Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }
    guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(userId)/cipher-text/fetch?backupMethod=\(withBackupMethod.rawValue)") else {
      throw URLError(.badURL)
    }
    let data = try await requests.get(url)
    let response = try decoder.decode(CipherTextResult.self, from: data)
    let cipherText = response.cipherText

    return try await portal.recoverWallet(withBackupMethod, withCipherText: cipherText) { status in
      self.logger.debug("ViewController.recover() - Recover progress callback with status: \(status.status.rawValue), \(status.done)")
    }
  }

  public func sendTransaction() async throws -> String {
    guard let portal else {
      self.logger.error("ViewController.sendTransaction() - ❌ Portal not initialized.")
      throw PortalExampleAppError.portalNotInitialized()
    }
    let chainId = "eip155:1115511"
    guard let address = await portal.getAddress(chainId) else {
      self.logger.error("ViewController.sendTransaction() - ❌ Address not found.")
      throw PortalExampleAppError.addressNotFound()
    }

    _ = try await self.getGasPrice(chainId)

    return ""

    let transaction = [
      "data": "",
      "from": address,
      "gasPrice": "ethEstimate",
      "to": self.sendAddress?.text ?? "",
      "value": "0x10",
    ]

    let sendTransactionResponse = try await portal.request(chainId, withMethod: .eth_sendTransaction, andParams: [transaction])
    guard let transactionHash = sendTransactionResponse.result as? String else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    return transactionHash
  }

  public func simulateTransaction(_ chainId: String, transaction: Any) async throws -> SimulatedTransaction {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.simulateTransaction(chainId, from: transaction)
  }

  public func testProviderRequest(
    _ method: PortalRequestMethod,
    params: [Any]
  ) async throws -> Bool {
    do {
      guard let portal = self.portal else {
        throw PortalExampleAppError.portalNotInitialized()
      }
      self.logger.info("ViewController.testProviderRequest() - Testing `\(method.rawValue)`...")

      let chainId = "eip155:11155111"
      let response = try await portal.request(chainId, withMethod: method, andParams: params)

      let result = response.result

      if signerMethods.contains(method.rawValue) {
        if let signature = result as? String {
          self.logger.info("ViewController.testProviderRequest() - ✅ Signature for \(method.rawValue): \(signature)")
          return true
        } else {
          self.logger.error("ViewController.testProviderRequest() - ❌ No signature found for method: \(method.rawValue)")
          return false
        }
      } else {
        guard let rpcResponse = response.result as? PortalProviderRpcResponse else {
          self.logger.error("ViewController.testProviderRequest() - ❌ Error testing provider `\(method.rawValue)` request: No RPC Response available.")
          return false
        }

        self.logger.info("ViewController.testProviderRequest() - ✅ RPC response for `\(method.rawValue)`: \(String(describing: rpcResponse.result))")
        return true
      }
    } catch {
      self.logger.error("ViewController.testProviderRequest() - ❌ Error executing `\(method.rawValue)` request: \(error.localizedDescription)")
      return false
    }
  }

  public func testOtherRequests() async throws {
    let chainId = "eip155:11155111"

    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let address = await portal.getAddress(chainId) else {
      throw PortalExampleAppError.addressNotFound()
    }

    let otherRequests = [
      ProviderRequest(method: .eth_accounts, params: []),
      ProviderRequest(method: .eth_requestAccounts, params: []),
      ProviderRequest(method: .eth_blockNumber, params: []),
      ProviderRequest(method: .eth_gasPrice, params: []),
      ProviderRequest(method: .eth_getBalance, params: [address, "latest"]),
      ProviderRequest(method: .eth_getBlockByHash, params: ["0xdc0818cf78f21a8e70579cb46a43643f78291264dda342ae31049421c82d21ae", false]),
      ProviderRequest(method: .eth_getBlockTransactionCountByNumber, params: ["latest"]),
      ProviderRequest(method: .eth_getCode, params: [address, "latest"]),
      ProviderRequest(method: .eth_getTransactionByHash, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"]),
      ProviderRequest(method: .eth_getTransactionCount, params: [address, "latest"]),
      ProviderRequest(method: .eth_getTransactionReceipt, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"]),
      ProviderRequest(method: .eth_getUncleByBlockHashAndIndex, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b", "0x0"]),
      ProviderRequest(method: .eth_getUncleCountByBlockHash, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b"]),
      ProviderRequest(method: .eth_getUncleCountByBlockNumber, params: ["latest"]),
      ProviderRequest(method: .net_version, params: []),
      ProviderRequest(method: .eth_newBlockFilter, params: []),
      ProviderRequest(method: .eth_newPendingTransactionFilter, params: []),
      ProviderRequest(method: .eth_protocolVersion, params: []),
      ProviderRequest(method: .eth_sendRawTransaction, params: ["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"]),
      ProviderRequest(method: .web3_clientVersion, params: []),
      ProviderRequest(method: .web3_sha3, params: ["0x68656c6c6f20776f726c64"]),
      ProviderRequest(method: .eth_getStorageAt, params: [address, "0x0", "latest"]),
    ]

    for request in otherRequests {
      _ = try await self.testProviderRequest(request.method, params: request.params)
    }
  }

  public func testSignerRequests() async throws {
    let chainId = "eip155:11155111"

    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let address = await portal.getAddress(chainId) else {
      throw PortalExampleAppError.addressNotFound()
    }

    let toAddress = "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7"
    let fakeTransaction = [
      "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
      "from": address,
      "to": toAddress,
      "value": "0x9184e72a",
    ]

    let signerRequests = [
      ProviderRequest(method: .eth_sign, params: [address, "0xdeadbeaf"]),
      ProviderRequest(method: .personal_sign, params: ["0xdeadbeaf", address]),
      ProviderRequest(method: .eth_signTransaction, params: [fakeTransaction]),
    ]

    for request in signerRequests {
      _ = try await self.testProviderRequest(request.method, params: request.params)
    }
  }

  public func testTransactionRequests() async throws {
    let chainId = "eip155:11155111"
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let address = await portal.getAddress(chainId) else {
      throw PortalExampleAppError.addressNotFound()
    }

    let toAddress = "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7"
    let fakeTransaction = [
      "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
      "from": address,
      "to": toAddress,
      "value": "0x9184e72a",
    ]
    let requests = [
      ProviderRequest(method: .eth_call, params: [fakeTransaction]),
      ProviderRequest(method: .eth_estimateGas, params: [fakeTransaction]),
      ProviderRequest(method: .eth_sendTransaction, params: [fakeTransaction]),
      ProviderRequest(method: .eth_signTransaction, params: [fakeTransaction]),
    ]

    for request in requests {
      _ = try await self.testProviderRequest(request.method, params: request.params)
    }
  }

  public func testWalletRequests() async throws {
    print("\nTesting Wallet Methods:\n")
    let walletRequests = [
      // https://docs.metamask.io/guide/rpc-api.html#wallet-addethereumchain
      ProviderRequest(method: .wallet_addEthereumChain, params: []),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-getpermissions
      ProviderRequest(method: .wallet_getPermissions, params: []),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-registeronboarding
      ProviderRequest(method: .wallet_registerOnboarding, params: []),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-requestpermissions
      ProviderRequest(method: .wallet_requestPermissions, params: []),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-switchethereumchain
      ProviderRequest(method: .wallet_switchEthereumChain, params: []),
      // https://docs.metamask.io/guide/rpc-api.html#wallet-watchasset
      ProviderRequest(method: .wallet_watchAsset, params: []),
    ]

    for request in walletRequests {
      _ = try await self.testProviderRequest(request.method, params: request.params)
    }
  }

  /***********************************************
   * Custodian functions
   ***********************************************/

  public func signIn(_ username: String) async throws -> UserResult {
    do {
      guard let config = self.config else {
        throw PortalExampleAppError.configurationNotSet()
      }
      if let url = URL(string: "\(config.custodianServerUrl)/mobile/login") {
        let payload = ["username": username]

        let data = try await requests.post(url, andPayload: payload)
        let user = try decoder.decode(UserResult.self, from: data)

        self.user = user
        return user
      }

      throw URLError(.badURL)
    } catch {
      self.logger.error("ViewController.signIn() - Unable to sign in: \(error.localizedDescription)")
      throw error
    }
  }

  public func signUp(_ username: String) async throws -> UserResult {
    do {
      guard let config = self.config else {
        throw PortalExampleAppError.configurationNotSet()
      }
      if let url = URL(string: "\(config.custodianServerUrl)/mobile/signup") {
        let payload = ["username": username]

        let data = try await requests.post(url, andPayload: payload)
        let user = try decoder.decode(UserResult.self, from: data)

        self.user = user
        return user
      }

      throw URLError(.badURL)
    } catch {
      self.logger.error("ViewController.signUp() - Unable to sign up: \(error.localizedDescription)")
      throw error
    }
  }

  /***********************************************
   * Setup functions
   ***********************************************/

  public func loadApplicationConfig() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        self.logger.error("PortalWrapper.init - Couldnt load info.plist dictionary.")
        throw PortalExampleAppError.cantLoadInfoPlist()
      }
      guard let ENV: String = infoDictionary["ENV"] as? String else {
        self.logger.error("Error: Do you have `ENV=$(ENV)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }
      guard let ALCHEMY_API_KEY: String = infoDictionary["ALCHEMY_API_KEY"] as? String else {
        self.logger.error("Error: Do you have `ALCHEMY_API_KEY=$(ALCHEMY_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }
      guard let GOOGLE_CLIENT_ID: String = infoDictionary["GDRIVE_CLIENT_ID"] as? String else {
        self.logger.error("Error: Do you have `GDRIVE_CLIENT_ID=$(GDRIVE_CLIENT_ID)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      let debugMessage = "ViewController.loadApplicationConfig() - Found environment: \(ENV)"
      self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

      switch ENV {
      case "prod", "production":
        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.io",
          custodianServerUrl: "https://portalex-mpc.portalhq.io",
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.io"
        )
      case "stage", "staging":
        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.dev",
          custodianServerUrl: "https://staging-portalex-mpc-service.onrender.com",
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.dev"
        )
      default:
        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "localhost:3001",
          custodianServerUrl: "https://staging-portalex-mpc-service.onrender.com",
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "localhost:3002"
        )
      }
    } catch {
      self.logger.error("ViewController.loadApplicationConfig() - Error loading application config: \(error.localizedDescription)")
    }
  }

  public func parseETHBalanceHex(hex: String) -> String {
    let hexString = hex.replacingOccurrences(of: "0x", with: "")
    guard let hexInt = Int(hexString, radix: 16) else {
      print("Unable to parse ETH balance hex")
      return ""
    }
    let ethBalance = Double(hexInt) / 1_000_000_000_000_000_000
    return String(ethBalance)
  }

  public func prepareUIComponents() {
    // Set up UI Components
    var totalHeight: CGFloat = 0

    // Add up the height of all subviews
    for subview in self.scrollView.subviews {
      totalHeight += subview.frame.size.height + 5
      // Consider adding any vertical spacing between subviews if applicable
    }

    self.scrollView.contentSize = CGSize(width: self.scrollView.frame.size.width, height: totalHeight)

    self.scrollView.showsVerticalScrollIndicator = true
    self.scrollView.showsHorizontalScrollIndicator = false
    self.username?.delegate = self
    self.sendAddress?.delegate = self
    self.url?.delegate = self

    // Initialize the activity indicator
    self.activityIndicator = UIActivityIndicatorView(style: .large) // or .medium based on your preference
    self.activityIndicator.hidesWhenStopped = true
    self.activityIndicator.color = .systemBlue
    view.addSubview(self.activityIndicator)
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      self.activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    // Initialize the overlay view
    self.overlayView = UIView()
    self.overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.25) // Semi-transparent black
    self.overlayView.frame = self.view.bounds
    self.overlayView.isHidden = true

    view.addSubview(self.overlayView)
    view.bringSubviewToFront(self.activityIndicator)
  }

  public func populateEthBalance() async throws {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    let chainId = "eip155:11155111"
    guard let address = await portal.getAddress(chainId) else {
      throw PortalExampleAppError.addressNotFound()
    }

    let balanceResponse = try await portal.request(chainId, withMethod: .eth_getBalance, andParams: [address, "latest"])
    guard let balance = balanceResponse.result as? String else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    DispatchQueue.main.async {
      self.ethBalanceInformation?.text = "ETH Balance: \(self.parseETHBalanceHex(hex: balance)) ETH"
    }
  }

  public func registerPortal() async throws -> Portal {
    do {
      guard let config = self.config else {
        throw PortalExampleAppError.configurationNotSet()
      }
      guard let user else {
        throw PortalExampleAppError.userNotLoggedIn()
      }

      let infoString = "ViewController.registerPortal() - Registering portal using config: \(config)"
      self.logger.log(level: .info, "\(infoString, privacy: .public)")

      let portal = try Portal(
        user.clientApiKey,
        withRpcConfig: [
          "eip155:1": "https://eth-mainnet.g.alchemy.com/v2/\(config.alchemyApiKey)",
          "eip155:5": "https://eth-goerli.g.alchemy.com/v2/\(config.alchemyApiKey)",
          "eip155:137": "https://polygon-mainnet.g.alchemy.com/v2/\(config.alchemyApiKey)",
          "eip155:80001": "https://polygon-mumbai.g.alchemy.com/v2/\(config.alchemyApiKey)",
          "eip155:11155111": "https://eth-sepolia.g.alchemy.com/v2/\(config.alchemyApiKey)",
        ],
        autoApprove: false,
        featureFlags: FeatureFlags(optimized: true, isMultiBackupEnabled: true),
        apiHost: config.apiUrl,
        mpcHost: config.mpcUrl
      )

      try portal.setGDriveConfiguration(clientId: config.googleClientId)
      try portal.setGDriveView(self)
      try portal.setPasskeyAuthenticationAnchor(self.view.window!)
      try portal.setPasskeyConfiguration(relyingParty: "portalhq.dev", webAuthnHost: "backup.portalhq.dev")

      self.logger.info("ViewController.registerPortal() - Portal API Key: \(portal.apiKey)")

      portal.on(event: Events.PortalSigningRequested.rawValue, callback: { data in
        portal.emit(Events.PortalSigningApproved.rawValue, data: data)
      })

      portal.on(event: Events.PortalSignatureReceived.rawValue) { (data: Any) in
        let result = data as! RequestCompletionResult

        let debugMessage = "ViewController.registerPortal() - Recived signature: \(result)"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
      }

      self.logger.debug("ViewController.registerPortal() - ✅ Portal initialized")

      self.portal = portal

      return portal
    } catch {
      print("❌ Error registering portal:", error)
      throw error
    }
  }

  // Call this function whenever you want to prompt the user for a PIN
  public func requestPassword() async -> String? {
    let password = await withCheckedContinuation { continuation in
      let alertController = UIAlertController(title: "Enter Password", message: nil, preferredStyle: .alert)

      // Add text field for PIN input
      alertController.addTextField { textField in
        textField.placeholder = "PASSWORD"
        textField.isSecureTextEntry = true
        textField.keyboardType = .numberPad
      }

      // Submit action
      let submitAction = UIAlertAction(title: "Submit", style: .default) { _ in
        let password = alertController.textFields?.first?.text
        continuation.resume(returning: password)
      }
      alertController.addAction(submitAction)

      // Cancel action
      let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        continuation.resume(returning: nil)
      }
      alertController.addAction(cancelAction)

      // Present the alert controller
      self.present(alertController, animated: true, completion: nil)
    }

    return password
  }

  func startLoading() {
    self.overlayView.isHidden = false
    self.activityIndicator.startAnimating()
    // Disable user interaction while loading
    view.isUserInteractionEnabled = false
  }

  func stopLoading() {
    self.overlayView.isHidden = true
    self.activityIndicator.stopAnimating()
    // Re-enable user interaction when loading is finished
    view.isUserInteractionEnabled = true
  }

  private func updateUIComponents() {
    DispatchQueue.main.async {
      Task {
        do {
          if let addressInformation = self.addressInformation {
            addressInformation.text = try? await self.portal?.addresses[.eip155] ?? "N/A"
          }

          let availableRecoveryMethods = try await self.portal?.availableRecoveryMethods() ?? []
          let walletExists = try await self.portal?.doesWalletExist() ?? false
          let isWalletOnDevice = try await self.portal?.isWalletOnDevice() ?? false

          let username = self.username?.text ?? ""

          // Auth buttons
          self.logoutButton?.isEnabled = self.user != nil
          self.logoutButton?.isHidden = self.user == nil
          self.signInButton?.isEnabled = !username.isEmpty
          self.signInButton?.isHidden = self.user != nil
          self.signUpButton?.isEnabled = !username.isEmpty
          self.signUpButton?.isHidden = self.user != nil

          // Generate buttons
          self.generateButton?.isEnabled = !walletExists
          self.generateButton?.isHidden = self.portal == nil
          if let generateButton = self.generateButton {
            generateButton.setTitle(walletExists ? "Wallet already exists" : "Create Wallet", for: .normal)
          }

          // dApp connection buttons
          self.dappBrowserButton?.isEnabled = walletExists && isWalletOnDevice
          self.dappBrowserButton?.isHidden = !walletExists || !isWalletOnDevice
          self.portalConnectButton?.isEnabled = walletExists && isWalletOnDevice
          self.portalConnectButton?.isHidden = !walletExists || !isWalletOnDevice

          // Backup buttons
          self.gdriveBackupButton?.isEnabled = walletExists && isWalletOnDevice
          self.gdriveBackupButton?.isHidden = !walletExists || !isWalletOnDevice
          self.iCloudBackupButton?.isEnabled = walletExists && isWalletOnDevice
          self.iCloudBackupButton?.isHidden = !walletExists || !isWalletOnDevice
          self.passkeyBackupButton?.isEnabled = walletExists && isWalletOnDevice
          self.passkeyBackupButton?.isHidden = !walletExists || !isWalletOnDevice
          self.passwordBackupButton?.isEnabled = walletExists && isWalletOnDevice
          self.passwordBackupButton?.isHidden = !walletExists || !isWalletOnDevice

          // Recover buttons
          self.gdriveRecoverButton?.isEnabled = availableRecoveryMethods.contains(.GoogleDrive)
          self.gdriveRecoverButton?.isHidden = !walletExists
          self.iCloudRecoverButton?.isEnabled = availableRecoveryMethods.contains(.iCloud)
          self.iCloudRecoverButton?.isHidden = !walletExists
          self.passkeyRecoverButton?.isEnabled = availableRecoveryMethods.contains(.Passkey)
          self.passkeyRecoverButton?.isHidden = !walletExists
          self.passwordRecoverButton?.isEnabled = availableRecoveryMethods.contains(.Password)
          self.passwordRecoverButton?.isHidden = !walletExists

          // Signing buttons
          self.signButton?.isEnabled = walletExists && isWalletOnDevice
          self.signButton?.isHidden = !walletExists || !isWalletOnDevice
          self.personalSignButton?.isEnabled = walletExists && isWalletOnDevice
          self.personalSignButton?.isHidden = !walletExists || !isWalletOnDevice
          self.sendButton?.isEnabled = walletExists && isWalletOnDevice
          self.sendButton?.isHidden = !walletExists || !isWalletOnDevice
          self.sendUniButton?.isEnabled = walletExists && isWalletOnDevice
          self.sendUniButton?.isHidden = !walletExists || !isWalletOnDevice

          // Other management buttons
          self.deleteKeychainButton?.isEnabled = walletExists && isWalletOnDevice
          self.deleteKeychainButton?.isHidden = !walletExists || !isWalletOnDevice
          self.ejectButton?.isEnabled = availableRecoveryMethods.count > 0
          self.ejectButton?.isHidden = availableRecoveryMethods.count == 0

          // Portal test functions
          self.testButton?.isEnabled = walletExists && isWalletOnDevice
          self.testButton?.isHidden = !walletExists || !isWalletOnDevice
          self.testNFTsTrxsBalancesSimTrxButton?.isEnabled = walletExists && isWalletOnDevice
          self.testNFTsTrxsBalancesSimTrxButton?.isHidden = !walletExists || !isWalletOnDevice

          // Text components
          self.addressInformation?.isHidden = !walletExists || !isWalletOnDevice
          self.ethBalanceInformation?.isHidden = !walletExists || !isWalletOnDevice
          self.sendAddress?.isHidden = !walletExists || !isWalletOnDevice
          self.url?.isHidden = !walletExists || !isWalletOnDevice

          self.logger.debug("ViewController.updateUIComponents() - ✅ Ending loading")

          self.stopLoading()
        } catch {
          self.logger.error("ViewController.UpdateUIComponents() - ❌ Failed to update UI Components: \(error)")
        }
      }
    }
  }

  /***********************************************
   * UI actions
   ***********************************************/

  // Custodian actions

  @IBAction func handleSignIn(_: UIButton) {
    Task {
      do {
        guard let username = username?.text else {
          self.logger.error("ViewController.handleSignIn() - Cannot sign in. No username set.")
          return
        }
        self.startLoading()
        let user = try await signIn(username)
        self.logger.debug("ViewController.handleSignIn() - ✅ Signed in! User clientApiKey: \(user.clientApiKey)")

        self.portal = try await self.registerPortal()
        self.logger.debug("ViewController.handleSignIn() - ✅ Initialized. Updating UI Components.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSignIn() - ❌ Error signing in: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleSignOut(_: UIButton) {
    self.user = nil
    self.addressInformation?.text = "Address: N/A"
    self.ethBalanceInformation?.text = "ETH Balance: N/A"
    self.portal = nil

    DispatchQueue.main.async {
      self.logoutButton?.isEnabled = false
    }

    self.updateUIComponents()
  }

  @IBAction func handleSignup(_: UIButton) {
    Task {
      do {
        self.logger.debug("ViewController.handleSignUp() - Attempting sign up...")
        guard let username = username?.text else {
          self.logger.error("ViewController.handleSignUp() - Cannot sign up. No username set.")
          return
        }
        self.startLoading()
        let user = try await signUp(username)
        self.logger.debug("ViewController.handleSignUp() - ✅ Signed up! User clientApiKey: \(user.clientApiKey)")
        self.portal = try await self.registerPortal()
        self.logger.debug("ViewController.handleSignUp() - ✅ Portal initialized!")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSignUp() - ❌ Error signing up: \(error.localizedDescription)")
      }
    }
  }

  // Portal wallet actions

  @IBAction func handleDeleteKeychain(_: Any) {
    Task {
      guard let portal else {
        throw PortalExampleAppError.portalNotInitialized()
      }

      await self.deleteKeychain()
      guard let address = try await portal.addresses[.eip155] else {
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = "N/A"
          }
        }
        return
      }
    }
  }

  @IBAction func handleEject(_: UIButton) {
    Task {
      do {
        guard let enteredPassword = await requestPassword(), !enteredPassword.isEmpty else {
          self.logger.error("ViewController.handleEject() - ❌ No password set by user. Eject will not take place.")
          return
        }

        try self.portal?.setPassword(enteredPassword)

        let privateKey = try await eject(.Password)

        self.logger.info("ViewController.handleEject() - ✅ Successfully ejected wallet. Private key: \(privateKey)")
      } catch {
        self.stopLoading()
        print("⚠️", error)
        self.logger.error("ViewController.handleEject() - Error ejecting wallet: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleGenerate(_: UIButton!) {
    Task {
      do {
        self.startLoading()
        let (ethereum, _) = try await generate()
        guard let address = ethereum else {
          self.logger.error("ViewController.handleGenerate() - ❌ Wallet was generated, but no address was found.")
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        let debugMessage = "ViewController.handleGenerate() - ✅ Wallet successfully created! Address: \(String(describing: address))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGenerate() - ❌ Error creating wallet: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleGdriveBackup(_: UIButton!) {
    Task {
      do {
        guard let portal = self.portal else {
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        self.startLoading()
        try portal.setGDriveView(self)
        self.logger.debug("ViewController.handleGdriveBackup() - Starting backup...")
        _ = try await self.backup(String(user.exchangeUserId), withMethod: .GoogleDrive)
        self.logger.debug("ViewController.handlePasskeyBackup(): ✅ Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGdriveBackup() - ❌ Error running backup: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleGdriveRecover(_: UIButton!) {
    Task {
      do {
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        self.startLoading()
        self.logger.debug("ViewController.handleGdriveRecover() - Starting recover...")
        let (ethereum, _) = try await recover(String(user.exchangeUserId), withBackupMethod: .GoogleDrive)
        guard let address = ethereum else {
          self.logger.error("ViewController.handleGdriveRecover() - ❌ Wallet was recovered, but no address was found.")
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        let debugMessage = "ViewController.handleGdriveRecover() - ✅ Wallet successfully recovered! Address: \(String(describing: address))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGdriveRecover() - Error running recover: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleiCloudBackup(_: UIButton!) {
    Task {
      do {
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        self.startLoading()
        self.logger.debug("ViewController.handleiCloudBackup() - Starting backup...")
        _ = try await self.backup(String(user.exchangeUserId), withMethod: .iCloud)
        self.logger.debug("ViewController.handleiCloudBackup(): ✅ Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleiCloudBackup() - ❌ Error running backup: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleiCloudRecover(_: UIButton!) {
    Task {
      do {
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        self.startLoading()
        self.logger.debug("ViewController.handleiCloudRecover() - Starting recover...")
        let (ethereum, _) = try await recover(String(user.exchangeUserId), withBackupMethod: .iCloud)
        guard let address = ethereum else {
          self.logger.error("ViewController.handleiCloudRecover() - ❌ Wallet was recovered, but no address was found.")
          throw PortalExampleAppError.addressNotFound()
        }
        let debugMessage = "ViewController.handleiCloudRecover() - ✅ Wallet successfully recovered! Address: \(String(describing: address))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleiCloudRecover() - Error running recover: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handlePasskeyBackup(_: UIButton!) {
    Task {
      do {
        guard let userId = user?.exchangeUserId else {
          self.logger.error("ViewController.handlePasskeyBackup() - No userId found. Please login before using Portal.")
          return
        }
        self.startLoading()
        self.logger.debug("ViewController.handlPasskeyBackup() - Starting backup...")
        _ = try await self.backup(String(userId), withMethod: .Passkey)
        self.logger.debug("ViewController.handlePasskeyBackup(): ✅ Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyBackup() - Error running backup: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handlePasskeyRecover(_: UIButton!) {
    Task {
      do {
        guard let userId = user?.exchangeUserId else {
          self.logger.error("ViewController.handlePasskeyRecover() - No userId found. Please login before using Portal.")
          return
        }
        self.startLoading()
        self.logger.debug("ViewController.handlPasskeyRecover() - Starting recover...")
        let (ethereum, _) = try await recover(String(userId), withBackupMethod: .Passkey)
        guard let address = ethereum else {
          self.logger.error("ViewController.handleGenerate() - ❌ Wallet was recovered, but no address was found.")
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        let debugMessage = "ViewController.handlePasskeyRecover() - ✅ Wallet successfully recovered! Address: \(String(describing: address))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyBackup() - Error running recover: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handlePasswordBackup(_: UIButton!) {
    Task {
      do {
        guard let enteredPassword = await requestPassword(), !enteredPassword.isEmpty else {
          self.logger.error("ViewController.handlePasswordBackup() - ❌ No password set by user. Backup will not take place.")
          return
        }
        guard let userId = user?.exchangeUserId else {
          self.logger.error("ViewController.handlePasswordBackup() - No userId found. Please login before using Portal.")
          return
        }
        self.startLoading()
        // Set the Password for backup
        try self.portal?.setPassword(enteredPassword)
        self.logger.debug("ViewController.handlPasswordBackup() - Starting backup...")
        _ = try await self.backup(String(userId), withMethod: .Password)
        self.logger.debug("ViewController.handlePasskeyBackup(): ✅ Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyBackup() - Error running backup: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handlePasswordRecover(_: UIButton!) {
    Task {
      do {
        guard let portal = self.portal else {
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let enteredPassword = await requestPassword(), !enteredPassword.isEmpty else {
          self.logger.error("ViewController.handlePasswordRecover() - ❌ No password set by user. Recovery will not take place.")
          return
        }
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        self.startLoading()
        // Set the Password for backup
        try portal.setPassword(enteredPassword)
        self.logger.debug("ViewController.handlPasswordRecover() - Starting recover...")
        let (ethereum, solana) = try await recover(String(user.exchangeUserId), withBackupMethod: .Password)
        guard let address = ethereum else {
          self.logger.error("ViewController.handlePasswordRecover() - ❌ Wallet was recovered, but no address was found.")
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        let debugMessage = "ViewController.handlePasskeyRecover() - ✅ Wallet successfully recovered! Address: \(String(describing: address))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyBackup() - Error running recover: \(error.localizedDescription)")
      }
    }
  }

  // Portal API actions

  @IBAction func testGetNFTsTrxsBalancesSharesAndSimTrx() {
    Task {
      let chainId = "eip155:11155111"

      do {
        let erc20Balances = try await self.getBalances()
        print(erc20Balances)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched balances.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching balances: \(error.localizedDescription)")
        return
      }
      do {
        let nfts = try await self.getNFTs(chainId)
        print(nfts)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched NFTs.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching NFTs: \(error.localizedDescription)")
        return
      }
      do {
        let shares = try await self.getShareMetadata()
        print(shares)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched share metadata.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching share metadata: \(error.localizedDescription)")
      }
      do {
        let transactions = try await self.getTransactions(chainId)
        print(transactions)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched transactions.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching transactions: \(error.localizedDescription)")
        return
      }
      do {
        let address = await self.portal?.getAddress(chainId)
        let transaction = [
          "from": address,
          "to": self.sendAddress?.text ?? "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
          "value": "0x10",
        ]
        let simulatedTransaction = try await self.simulateTransaction(chainId, transaction: transaction)
        print(simulatedTransaction)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully simulated transaction.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error simulating transaction: \(error.localizedDescription)")
        return
      }
    }
  }

  @IBAction func sendPressed(_: UIButton!) {
    Task {
      do {
        _ = try await self.sendTransaction()
        self.logger.info("ViewController.handlSend() - ✅ Successfully sent transaction")
      } catch {
        self.logger.error("ViewController.handleSend() - ❌ Error sending transaction: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func usernameChanged(_: Any) {
    let hasUsername = self.username?.text?.count ?? 0 > 3

    self.signInButton?.isEnabled = hasUsername
    self.signUpButton?.isEnabled = hasUsername
  }

  @IBAction func testProviderRequests(_: UIButton) {
    Task {
      do {
        try await self.testSignerRequests()
        try await self.testTransactionRequests()
        try await self.testOtherRequests()

        self.logger.info("ViewController.testProviderRequests() - ✅ Successfully tested provider requests")
      } catch {
        self.logger.error("ViewController.testProviderRequests() - ❌ Error testing transactions: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handleSign() {
    Task {
      do {
        let chainId = "eip155:11155111"

        guard let portal else {
          self.logger.error("ViewController.handlSign() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let address = await portal.getAddress(chainId) else {
          self.logger.error("ViewController.handlSign() - ❌ Address not found")
          throw PortalExampleAppError.addressNotFound()
        }

        self.startLoading()
        let params = [address, "0xdeadbeef"]

        self.logger.debug("Params: \(params)")

        guard let response = try? await portal.request(chainId, withMethod: .eth_sign, andParams: params) else {
          self.logger.error("ViewController.handlSign() - ❌ Failed to process request")
          self.stopLoading()
          return
        }

        guard let signature = response.result as? String else {
          self.logger.error("ViewController.handlSign() - ❌ Invalid response type for request:")
          print(response.result)
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleSign() - ✅ Successfully signed message: \(signature)")
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSign() - ❌ Error signing message: \(error.localizedDescription)")
      }
    }
  }

  @IBAction func handlePersonalSign() {
    Task {
      do {
        let chainId = "eip155:11155111"

        guard let portal else {
          self.logger.error("ViewController.handlSign() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let address = await portal.getAddress(chainId) else {
          self.logger.error("ViewController.handlSign() - ❌ Address not found")
          throw PortalExampleAppError.addressNotFound()
        }

        self.startLoading()
        let params = ["0xdeadbeef", address]

        self.logger.debug("Params: \(params)")

        guard let response = try? await portal.request(chainId, withMethod: .personal_sign, andParams: params) else {
          self.logger.error("ViewController.handlSign() - ❌ Failed to process request")
          self.stopLoading()
          return
        }

        guard let signature = response.result as? String else {
          self.logger.error("ViewController.handlSign() - ❌ Invalid response type for request:")
          print(response.result)
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleSign() - ✅ Successfully signed message: \(signature)")
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSign() - ❌ Error signing message: \(error.localizedDescription)")
      }
    }
  }
  
  func handleSwaps() {
    do {
      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleSwaps() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }
      
      let swaps = PortalSwaps(apiKey: "6b634597-d4fc-4001-95e6-541de1d69fe8", portal: portal)
      
      swaps.getSources() { result in
        let source = result
        print("getSources response:", source)

        // Delay the second request by 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          let quoteArgs = QuoteArgs(
            buyToken: "0x68194a729c2450ad26072b3d33adacbcef39d574", // USDC on Sepolia
            sellToken: "ETH",
            sellAmount: "1"
          )
          
          let baseSepoliaChainId = "eip155:84532"
          swaps.getQuote(args: quoteArgs, forChainId: baseSepoliaChainId) { result in
            let quote = result
            print("getQuote response:", quote)

            self.logger.info("ViewController.handleSwaps() - ✅ Successfully called get sources + quotes")
          }

          self.stopLoading()
        }
      }
    } catch {
      self.stopLoading()
      self.logger.error("ViewController.handleSwaps() - ❌ Error signing message: \(error.localizedDescription)")
    }
  }
}

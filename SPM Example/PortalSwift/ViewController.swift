//
//  ViewController.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import os.log
import PortalSwift
import SwiftUI
import UIKit

struct UserResult: Codable {
  var clientApiKey: String
  var clientId: String
  var exchangeUserId: Int
  var username: String
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
  @IBOutlet var statusLabel: UILabel?

  // Buttons
  @IBOutlet var dappBrowserButton: UIButton?
  @IBOutlet var testSimulateTransactionButton: UIButton?
  @IBOutlet var generateButton: UIButton?
  @IBOutlet var generateSolanaButton: UIButton!
  @IBOutlet var logoutButton: UIButton?
  @IBOutlet var portalConnectButton: UIButton?

  @IBOutlet var personalSignButton: UIButton?
  @IBOutlet var rawSignButton: UIButton?
  @IBOutlet var signButton: UIButton?
  @IBOutlet var signInButton: UIButton?
  @IBOutlet var signUpButton: UIButton?
  @IBOutlet var testButton: UIButton?
  @IBOutlet var deleteKeychainButton: UIButton?
  @IBOutlet var testNFTsTrxsBalancesSimTrxButton: UIButton?
  @IBOutlet var ejectButton: UIButton?
  @IBOutlet var ejectAllButton: UIButton?
  @IBOutlet var receiveAssetButton: UIButton?
  @IBOutlet var sendAssetButton: UIButton?
  @IBOutlet var generateSolanaAndBackupShares: UIButton!

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

  private var refreshBalanceTimer: Timer?

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

  private var portal: PortalProtocol? {
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

  private let logger = Logger()
  private let requests = PortalRequests()

  private let successStatus = "✅ Success"
  private let failureStatus = "❌ Failure"

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
    guard let client = try await portal.client else {
      self.logger.error("ViewController.backup() - Client unavailable.")
      throw PortalExampleAppError.clientInformationUnavailable()
    }

    self.logger.debug("ViewController.backup() - Starting backup...")
    let (cipherText, storageCallback) = try await portal.backupWallet(withMethod) { status in
      self.logger.debug("ViewController.backup() - Backup progress callback with status: \(status.status.rawValue), \(status.done)")
    }

    let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

    if !backupWithPortal {
      guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(userId)/cipher-text") else {
        throw URLError(.badURL)
      }
      let payload = [
        "backupMethod": withMethod.rawValue,
        "cipherText": cipherText
      ]

      struct ResponseType: Decodable {
        let message: String?
      }

      let request = PortalAPIRequest(url: url, method: .post, payload: payload)
      let result = try await requests.execute(request: request, mappingInResponse: ResponseType.self)
      try await storageCallback()

      return result.message ?? ""
    }

    return ""
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
      self.showStatusView(message: "\(self.successStatus) Deleted keychain data")
      self.logger.debug("ViewController.deleteKeychain() - ✅ Deleted keychain data")
    } catch {
      self.showStatusView(message: "\(self.failureStatus) Error deleting keychain data: \(error)")
      self.logger.error("ViewController.deleteKeychain() - ❌ Error deleting keychain data: \(error)")
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
      self.logger.error("ViewController.eject() - ❌ Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    var cipherText: String?
    var organizationShare: String?

    guard let client = try await portal.client else {
      throw PortalExampleAppError.clientInformationUnavailable("No client found.")
    }

    let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

    if !backupWithPortal {
      guard let cipherTextUrl = URL(
        string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(withBackupMethod.rawValue)"
      ) else {
        throw URLError(.badURL)
      }

      let cipherTextRequest = PortalAPIRequest(url: cipherTextUrl)
      let cipherTextResponse = try await requests.execute(request: cipherTextRequest, mappingInResponse: CipherTextResult.self)
      cipherText = cipherTextResponse.cipherText

      guard let organizationBackupShareUrl = URL(
        string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(withBackupMethod.rawValue)-SECP256K1"
      ) else {
        throw URLError(.badURL)
      }

      let organizationBackupShareRequest = PortalAPIRequest(url: organizationBackupShareUrl)
      let organizationBackupShareResponse = try await requests.execute(request: cipherTextRequest, mappingInResponse: OrgShareResult.self)

      organizationShare = organizationBackupShareResponse.orgShare
    } else {
      var walletId: String? = nil

      for wallet in client.wallets {
        if wallet.curve == .SECP256K1 {
          for backupSharePair in wallet.backupSharePairs {
            if backupSharePair.status == .completed, backupSharePair.backupMethod == withBackupMethod {
              walletId = wallet.id
              break
            }
          }
        }
      }

      guard let walletId else {
        throw PortalExampleAppError.clientInformationUnavailable("Could not find Ethereum backup share for backup method.")
      }

      guard let prepareEjectUrl = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/prepare-eject") else {
        throw URLError(.badURL)
      }

      let prepareEjectRequest = PortalAPIRequest(url: prepareEjectUrl, method: .post, payload: ["walletId": walletId])
      let prepareEjectResponse = try await requests.execute(request: prepareEjectRequest, mappingInResponse: String.self)

      print("Ethereum Wallet ejectable until \(prepareEjectResponse)")
    }

    let privateKey = try await portal.eject(
      withBackupMethod,
      withCipherText: cipherText,
      andOrganizationBackupShare: organizationShare
    )

    return privateKey
  }

  public func ejectAll(_ withBackupMethod: BackupMethods) async throws -> [PortalNamespace: String] {
    guard let portal else {
      self.logger.error("ViewController.eject() - ❌ Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let user else {
      self.logger.error("ViewController.eject() - ❌ User not logged in.")
      throw PortalExampleAppError.userNotLoggedIn()
    }
    guard let config else {
      self.logger.error("ViewController.eject() - ❌ Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    var cipherText: String?
    var organizationShare: String?
    var organizationSolanaShare: String? = nil

    guard let client = try await portal.client else {
      throw PortalExampleAppError.clientInformationUnavailable("No client found.")
    }

    let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

    if !backupWithPortal {
      guard let cipherTextUrl = URL(
        string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(withBackupMethod.rawValue)"
      ) else {
        throw URLError(.badURL)
      }

      let cipherTextRequest = PortalAPIRequest(url: cipherTextUrl)
      let cipherTextResponse = try await requests.execute(request: cipherTextRequest, mappingInResponse: CipherTextResult.self)

      cipherText = cipherTextResponse.cipherText

      guard let organizationBackupShareUrl = URL(
        string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(withBackupMethod.rawValue)-SECP256K1"
      ) else {
        throw URLError(.badURL)
      }
      let organizationBackupShareRequest = PortalAPIRequest(url: organizationBackupShareUrl)
      let organizationBackupShareResponse = try await requests.execute(request: organizationBackupShareRequest, mappingInResponse: OrgShareResult.self)

      organizationShare = organizationBackupShareResponse.orgShare

      guard let organizationSolanaBackupShareUrl = URL(
        string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(withBackupMethod.rawValue)-ED25519"
      ) else {
        throw URLError(.badURL)
      }
      let organizationSolanaBackupShareRequest = PortalAPIRequest(url: organizationSolanaBackupShareUrl)
      let organizationSolanaBackupShareResponse = try? await requests.execute(request: organizationSolanaBackupShareRequest, mappingInResponse: OrgShareResult.self)
      if let organizationSolanaBackupShareResponse {
        organizationSolanaShare = organizationSolanaBackupShareResponse.orgShare
      }
    } else {
      var walletId: String?
      var walletIdEd25519: String? = nil

      for wallet in client.wallets {
        if wallet.curve == .SECP256K1 {
          for backupSharePair in wallet.backupSharePairs {
            if backupSharePair.status == .completed, backupSharePair.backupMethod == withBackupMethod {
              walletId = wallet.id
              break
            }
          }
        } else if wallet.curve == .ED25519 {
          for backupSharePair in wallet.backupSharePairs {
            if backupSharePair.status == .completed, backupSharePair.backupMethod == withBackupMethod {
              walletIdEd25519 = wallet.id
              break
            }
          }
        }
      }

      guard let walletId else {
        throw PortalExampleAppError.clientInformationUnavailable("Could not find Ethereum backup share for backup method.")
      }

      guard let prepareEjectUrl = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/prepare-eject") else {
        throw URLError(.badURL)
      }
      let prepareEjectRequest = PortalAPIRequest(url: prepareEjectUrl, method: .post, payload: ["walletId": walletId])
      let prepareEjectResponse = try await requests.execute(request: prepareEjectRequest, mappingInResponse: String.self)

      print("Ethereum Wallet ejectable until \(prepareEjectResponse)")

      if let walletIdEd25519 {
        let prepareEjectEd25519Request = PortalAPIRequest(url: prepareEjectUrl, method: .post, payload: ["walletId": walletIdEd25519])
        let prepareEjectResponseEd25519 = try await requests.execute(request: prepareEjectEd25519Request, mappingInResponse: String.self)

        print("Solana Wallet ejectable until \(prepareEjectResponseEd25519)")
      }
    }

    let privateKey = try await portal.ejectPrivateKeys(
      withBackupMethod,
      withCipherText: cipherText,
      andOrganizationBackupShare: organizationShare,
      andOrganizationSolanaBackupShare: organizationSolanaShare
    )

    return privateKey
  }

  public func generate() async throws -> PortalCreateWalletResponse {
    guard let portal else {
      self.logger.error("PortalWrapper.generate() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.createWallet(usingProgressCallback: nil)
  }

  public func generateSolana() async throws -> String {
    guard let portal else {
      self.logger.error("PortalWrapper.generateSolana() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.createSolanaWallet(usingProgressCallback: nil)
  }

  func getBalances() async throws -> [FetchedBalance] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    let chainId = "eip155:11155111"
    let balances = try await portal.getBalances(chainId)

    return balances
  }

  func getAssets(for chainId: String) async throws -> AssetsResponse {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    let assets = try await portal.getAssets(chainId)

    return assets
  }

  public func getGasPrice(_ chainId: String) async throws {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    let gasPriceResponse = try await portal.request(chainId, withMethod: .eth_gasPrice, andParams: [])

    print("Gas price response: \(gasPriceResponse)")

    //    return gasPriceResponse.result
  }

  public func testSolGetTransaction(_ chainId: String = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1") async throws {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    let result = try await portal.request(chainId, withMethod: .sol_getTransaction, andParams: ["2smd9TtRShhQAQneoeQ2Ezbu62wQ5Jrg4atzW7kU8E98cigDEt5UVv18QRpcGVtinoiH5muMuDj3Ay3veJhF5a1b"])

    print("sol_getTransaction response: \(result)")
  }

  func buildEip155Transaction(chainId: String = "eip155:11155111", params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.buildEip155Transaction(chainId: chainId, params: params)
  }

  func buildSolanaTransaction(chainId: String = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.buildSolanaTransaction(chainId: chainId, params: params)
  }

  public func getNftAssets(_ chainId: String) async throws -> [NftAsset] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.getNftAssets(chainId)
  }

  public func getWalletCapabilities() async throws -> WalletCapabilitiesResponse {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.getWalletCapabilities()
  }

  public func getShareMetadata() async throws -> [FetchedSharePair] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    let backupShares = try await portal.getBackupShares(nil)
    self.logger.info("ViewController.getShareMetadata() - ✅ Successfully fetched backup shares.")

    let signingShares = try await portal.getSigningShares(nil)
    self.logger.info("ViewController.getShareMetadata() - ✅ Successfully fetched signing shares.")

    let shares = backupShares + signingShares
    return shares
  }

  public func getTransactions(_ chainId: String) async throws -> [FetchedTransaction] {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }
    return try await portal.getTransactions(chainId, limit: nil, offset: nil, order: nil)
  }

  public func recover(_ userId: String, withBackupMethod: BackupMethods) async throws -> PortalRecoverWalletResponse {
    guard let portal else {
      self.logger.error("ViewController.recover() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }
    guard let config else {
      self.logger.error("ViewController.recover() - Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    var cipherText: String? = nil

    guard let client = try await portal.client else {
      throw PortalExampleAppError.clientInformationUnavailable("Could not fetch client.")
    }

    let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

    if !backupWithPortal {
      guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(userId)/cipher-text/fetch?backupMethod=\(withBackupMethod.rawValue)") else {
        throw URLError(.badURL)
      }
      let request = PortalAPIRequest(url: url)
      let response = try await requests.execute(request: request, mappingInResponse: CipherTextResult.self)
      cipherText = response.cipherText
    }

    return try await portal.recoverWallet(withBackupMethod, withCipherText: cipherText) { status in
      self.logger.debug("ViewController.recover() - Recover progress callback with status: \(status.status.rawValue), \(status.done)")
    }
  }

  public func sendTransaction() async throws -> String {
    guard let portal else {
      self.logger.error("ViewController.sendTransaction() - ❌ Portal not initialized.")
      throw PortalExampleAppError.portalNotInitialized()
    }
    let chainId = "eip155:11155111"

    let transactionParam = BuildTransactionParam(
      to: self.sendAddress?.text ?? "",
      token: "NATIVE",
      amount: "0.0001"
    )

    // Build the transaction using Portal
    let transactionResponse = try await portal.buildEip155Transaction(chainId: chainId, params: transactionParam)

    let sendTransactionResponse = try await portal.request(chainId, withMethod: .eth_sendTransaction, andParams: [transactionResponse.transaction])

    guard let transactionHash = sendTransactionResponse.result as? String else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    print("✅ Transaction hash: \(transactionHash)")

    return transactionHash
  }

  public func simulateTransaction(_ chainId: String, transaction: Any) async throws -> SimulatedTransaction {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.simulateTransaction(chainId, from: transaction)
  }

  public func evaluateTransaction(
    chainId: String,
    transaction: EvaluateTransactionParam,
    operationType: EvaluateTransactionOperationType? = nil
  ) async throws -> BlockaidValidateTrxRes {
    guard let portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    return try await portal.evaluateTransaction(chainId: chainId, transaction: transaction, operationType: operationType)
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
      self.logger.error("ViewController.testProviderRequest() - ❌ Error executing `\(method.rawValue)` request: \(error)")
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
      ProviderRequest(method: .eth_getStorageAt, params: [address, "0x0", "latest"])
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
      "value": "0x9184e72a"
    ]

    let signerRequests = [
      ProviderRequest(method: .eth_sign, params: [address, "0xdeadbeaf"]),
      ProviderRequest(method: .personal_sign, params: ["0xdeadbeaf", address]),
      ProviderRequest(method: .eth_signTransaction, params: [fakeTransaction])
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
      "value": "0x9184e72a"
    ]
    let requests = [
      ProviderRequest(method: .eth_call, params: [fakeTransaction]),
      ProviderRequest(method: .eth_estimateGas, params: [fakeTransaction]),
      ProviderRequest(method: .eth_sendTransaction, params: [fakeTransaction]),
      ProviderRequest(method: .eth_signTransaction, params: [fakeTransaction])
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
      ProviderRequest(method: .wallet_watchAsset, params: [])
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

        let request = PortalAPIRequest(url: url, method: .post, payload: payload)
        let user = try await requests.execute(request: request, mappingInResponse: UserResult.self)

        self.user = user
        return user
      }

      throw URLError(.badURL)
    } catch {
      self.logger.error("ViewController.signIn() - Unable to sign in: \(error)")
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

        let request = PortalAPIRequest(url: url, method: .post, payload: payload)
        let user = try await requests.execute(request: request, mappingInResponse: UserResult.self)

        self.user = user
        return user
      }

      throw URLError(.badURL)
    } catch {
      self.logger.error("ViewController.signUp() - Unable to sign up: \(error)")
      throw error
    }
  }

  /***********************************************
   * Setup functions
   ***********************************************/

  public func loadApplicationConfig() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        self.logger.error("PortalWrapper.init - Couldn't load info.plist dictionary.")
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
      guard let BACKUP_WITH_PORTAL: String = infoDictionary["BACKUP_WITH_PORTAL"] as? String else {
        self.logger.error("Error: The environment variable `BACKUP_WITH_PORTAL` is not set or is empty. Please ensure that `BACKUP_WITH_PORTAL=true` or `BACKUP_WITH_PORTAL=false` is included in your Secrets.xcconfig file, and that `BACKUP_WITH_PORTAL=$(BACKUP_WITH_PORTAL)` is referenced correctly in your App's info.plist.")
        throw PortalExampleAppError.environmentNotSet()
      }

      let debugMessage = "ViewController.loadApplicationConfig() - Found environment: \(ENV)"
      self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")

      switch ENV {
      case "prod", "production":
        let custodianServerUrl = BACKUP_WITH_PORTAL == "true" ? "https://prod-portalex-backup-with-portal.onrender.com" : "https://portalex-mpc.portalhq.io"

        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.io",
          custodianServerUrl: custodianServerUrl,
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.io",
          webAuthnHost: "backup.web.portalhq.io",
          relyingParty: "portalhq.io",
          enclaveMPCHost: "mpc-client.portalhq.io"
        )
      case "stage", "staging":
        let custodianServerUrl = BACKUP_WITH_PORTAL == "true" ? "https://staging-portalex-backup-with-portal.onrender.com" : "https://staging-portalex-mpc-service.onrender.com"

        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.dev",
          custodianServerUrl: custodianServerUrl,
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.dev",
          webAuthnHost: "backup.portalhq.dev",
          relyingParty: "portalhq.dev",
          enclaveMPCHost: "mpc-client.portalhq.dev"
        )
      default:
        self.config = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "localhost:3001",
          custodianServerUrl: "http://localhost:3010",
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "localhost:3002",
          webAuthnHost: "backup.portalhq.dev",
          relyingParty: "portalhq.dev",
          enclaveMPCHost: "mpc-client.portalhq.dev"
        )
      }

      Settings.shared.portalConfig.appConfig = self.config
    } catch {
      self.logger.error("ViewController.loadApplicationConfig() - Error loading application config: \(error)")
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
      self.activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
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
    guard let balance = balanceResponse.result as? PortalProviderRpcResponse else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    if let balanceHex = balance.result {
      let balance = self.parseETHBalanceHex(hex: balanceHex)
      DispatchQueue.main.async {
        self.ethBalanceInformation?.text = "ETH Balance: \(balance) ETH"
      }
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
        featureFlags: FeatureFlags(
          isMultiBackupEnabled: true,
          useEnclaveMPCApi: true
        ),
        apiHost: config.apiUrl,
        mpcHost: config.mpcUrl,
        enclaveMPCHost: config.enclaveMPCHost
      )

      try portal.setGDriveConfiguration(clientId: config.googleClientId, backupOption: .appDataFolder)
      try portal.setGDriveView(self)
      try portal.setPasskeyAuthenticationAnchor(self.view.window!)
      try portal.setPasskeyConfiguration(relyingParty: config.relyingParty, webAuthnHost: config.webAuthnHost)
      // The apikey from Portal class is private within the Portal SDK class, so it must not be accessible from outside. We already have the clientApiKey from user
      self.logger.info("ViewController.registerPortal() - Portal API Key: \(user.clientApiKey)")

      portal.on(event: Events.PortalSigningRequested, callback: { [weak portal] data in
        portal?.emit(Events.PortalSigningApproved, data: data)
      })

      portal.on(event: Events.PortalSignatureReceived) { (data: Any) in
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
          self.addressInformation?.text = "N/A"
          if let address = try? await self.portal?.addresses[.eip155], address != nil {
            self.addressInformation?.text = address
            self.startRefreshBalanceTimer()
          } else {
            self.stopRefreshBalanceTimer()
          }

          let availableRecoveryMethods = try await self.portal?.availableRecoveryMethods(nil) ?? []
          let walletExists = try await self.portal?.doesWalletExist(nil) ?? false
          let solanaWalletExists = try await self.portal?.doesWalletExist("solana") ?? false
          var isWalletOnDevice = false
          do {
            isWalletOnDevice = try await self.portal?.isWalletOnDevice(nil) ?? false
          } catch {
            self.logger.error("ViewController.UpdateUIComponents() - ❌ portal.isWalletOnDevice() failed with: \(error)")
          }

          do {
            let isWalletBackedUp = try await self.portal?.isWalletBackedUp(nil)
            if isWalletBackedUp ?? false {
              print("isWalletBackedUp: Wallet is backed up already: \(String(describing: isWalletBackedUp))")
            } else {
              print("isWalletBackedUp: Wallet is not backed up.")
            }
          } catch {
            print("❌ Unable to check if wallet is backed up: \(error)")
          }

          do {
            let isWalletRecoverable = try await self.portal?.isWalletRecoverable(nil)
            if isWalletRecoverable ?? false {
              print("isWalletRecoverable: Wallet is recoverable up already: \(String(describing: isWalletRecoverable))")
            } else {
              print("isWalletRecoverable: Wallet is not recoverable.")
            }
          } catch {
            print("❌ Unable to check if wallet is recoverable : \(error)")
          }

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

          // generate Solana button
          self.generateSolanaButton.isEnabled = !solanaWalletExists
          self.generateSolanaButton.isHidden = self.portal == nil
          if let generateSolanaButton = self.generateSolanaButton {
            generateSolanaButton.setTitle(solanaWalletExists ? "Solana Wallet already exists" : "Create Solana Wallet", for: .normal)
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
          self.rawSignButton?.isEnabled = walletExists && isWalletOnDevice
          self.rawSignButton?.isHidden = !walletExists || !isWalletOnDevice
          self.sendButton?.isEnabled = walletExists && isWalletOnDevice
          self.sendButton?.isHidden = !walletExists || !isWalletOnDevice
          self.sendUniButton?.isEnabled = walletExists && isWalletOnDevice
          self.sendUniButton?.isHidden = !walletExists || !isWalletOnDevice

          // Other management buttons
          self.deleteKeychainButton?.isEnabled = walletExists && isWalletOnDevice
          self.deleteKeychainButton?.isHidden = !walletExists || !isWalletOnDevice
          self.ejectButton?.isEnabled = availableRecoveryMethods.count > 0
          self.ejectButton?.isHidden = availableRecoveryMethods.count == 0
          self.ejectAllButton?.isEnabled = availableRecoveryMethods.count > 0
          self.ejectAllButton?.isHidden = availableRecoveryMethods.count == 0

          // Test Receive + Send Assets
          self.receiveAssetButton?.isEnabled = walletExists && isWalletOnDevice
          self.receiveAssetButton?.isHidden = !walletExists || !isWalletOnDevice
          self.sendAssetButton?.isEnabled = walletExists && isWalletOnDevice
          self.sendAssetButton?.isHidden = !walletExists || !isWalletOnDevice

          // Test Generate Solana and backup shares
          self.generateSolanaAndBackupShares.isHidden = self.user == nil

          // Portal test functions
          self.testButton?.isEnabled = walletExists && isWalletOnDevice
          self.testButton?.isHidden = !walletExists || !isWalletOnDevice
          self.testNFTsTrxsBalancesSimTrxButton?.isEnabled = walletExists && isWalletOnDevice
          self.testNFTsTrxsBalancesSimTrxButton?.isHidden = !walletExists || !isWalletOnDevice

          // Test Simulate Transactions functions
          self.testSimulateTransactionButton?.isEnabled = walletExists && isWalletOnDevice
          self.testSimulateTransactionButton?.isHidden = !walletExists || !isWalletOnDevice

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
        self.showStatusView(message: "\(self.successStatus) Signed in!")
        self.portal = try await self.registerPortal()
        self.logger.debug("ViewController.handleSignIn() - ✅ Initialized. Updating UI Components.")
        self.updateUIComponents()
        try await self.populateEthBalance()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSignIn() - ❌ Error signing in: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error signing in \(error)")
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
        self.showStatusView(message: "\(self.successStatus) Signed up!")
        self.portal = try await self.registerPortal()
        self.logger.debug("ViewController.handleSignUp() - ✅ Portal initialized!")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSignUp() - ❌ Error signing up: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error signing up \(error)")
      }
    }
  }

  // Portal wallet actions

  @IBAction func handleDeleteKeychain(_: Any) {
    Task {
      guard let portal else {
        self.showStatusView(message: "\(self.failureStatus) Error Deleting Keychain - Portal not initialized.")
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
        self.showStatusView(message: "\(self.successStatus) Private key: \(privateKey)")
      } catch {
        self.stopLoading()
        print("⚠️", error)
        self.logger.error("ViewController.handleEject() - Error ejecting wallet: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error ejecting wallet \(error)")
      }
    }
  }

  @IBAction func handleEjectAll(_: UIButton) {
    Task {
      do {
        guard let enteredPassword = await requestPassword(), !enteredPassword.isEmpty else {
          self.logger.error("ViewController.handleEject() - ❌ No password set by user. Eject will not take place.")
          return
        }

        try self.portal?.setPassword(enteredPassword)

        let privateKey = try await ejectAll(.Password)

        self.logger.info("ViewController.handleEject() - ✅ Successfully ejected wallet. Private key: \(privateKey)")
        self.showStatusView(message: "\(self.successStatus) Private key: \(privateKey)")
      } catch {
        self.stopLoading()
        print("⚠️", error)
        self.logger.error("ViewController.handleEject() - Error ejecting wallet: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error ejecting wallet \(error)")
      }
    }
  }

  @IBAction func handleReceiveAsset(_: UIButton) {
    Task {
      do {
        self.startLoading()

        let chainId = "eip155:11155111"
        let params = FundParams(amount: "0.01", token: "NATIVE")

        let response = try await portal?.receiveTestnetAsset(chainId: chainId, params: params)

        if let txHash = response?.data?.txHash {
          self.logger.info("ViewController.handleReceiveAsset() - ✅ Successfully created transaction to fund account")
          self.showStatusView(message: "\(self.successStatus) Successfully created transaction to fund account")
          self.logger.info("ViewController.handleReceiveAsset() - ✅ Transaction Hash: \(txHash)")
          try await self.populateEthBalance()
        }

        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("Error sending transaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error sending transaction: \(error)")
      }
    }
  }

  @IBAction func handleSendAsset(_: UIButton) {
    Task {
      do {
        self.startLoading()

        let chainId = "eip155:11155111"
        let params = SendAssetParams(to: "0xdFd8302f44727A6348F702fF7B594f127dE3A902", amount: "0.001", token: "NATIVE")

        let response = try await portal?.sendAsset(chainId: chainId, params: params)

        if let txHash = response?.txHash {
          self.logger.info("ViewController.handleSendAsset() - ✅ Successfully sent transaction")
          self.showStatusView(message: "\(self.successStatus) Successfully sent transaction")
          self.logger.info("ViewController.handleSendAsset() - ✅ Transaction Hash: \(txHash)")
          try await self.populateEthBalance()
        }

        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("Error sending transaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error sending transaction: \(error)")
      }
    }
  }

  @IBAction func handleGenerateSolanaAndBackupShares(_: Any) {
    Task {
      do {
        self.startLoading()
        self.logger.debug("ViewController.handleGenerateSolanaAndBackupShares() - Starting generate Solana wallet then backup...")
        let result = try await self.generateSolanaWalletAndBackup(withMethod: .iCloud)
        self.logger.debug("ViewController.handleGenerateSolanaAndBackupShares(): ✅ Successfully generated Solana wallet and backed up. Solana Address: \(result.solanaAddress)")
        self.showStatusView(message: "\(self.successStatus) Successfully generated Solana wallet and backed up. Solana Address: \(result.solanaAddress)")
        self.updateUIComponents()
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("Error generating Solana wallet and backup shares: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error generating Solana wallet and backup shares: \(error)")
      }
    }
  }

  private func generateSolanaWalletAndBackup(withMethod: BackupMethods) async throws -> (solanaAddress: String, cipherText: String) {
    guard let portal else {
      self.logger.error("ViewController.generateSolanaWalletAndBackup() - Portal not initialized. Please call registerPortal().")
      throw PortalExampleAppError.portalNotInitialized()
    }

    guard let config else {
      self.logger.error("ViewController.generateSolanaWalletAndBackup() - Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    guard let user else {
      throw PortalExampleAppError.userNotLoggedIn()
    }

    let generateSolanaResult = try await portal.generateSolanaWalletAndBackupShares(.iCloud) { _ in
    }

    guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text") else {
      throw URLError(.badURL)
    }
    let payload = [
      "backupMethod": withMethod.rawValue,
      "cipherText": generateSolanaResult.cipherText
    ]

    let request = PortalAPIRequest(url: url, method: .post, payload: payload)
    let result = try await requests.execute(request: request, mappingInResponse: String.self)

    try await generateSolanaResult.storageCallback()

    return (generateSolanaResult.solanaAddress, generateSolanaResult.cipherText)
  }

  public func sendSepoliaTransaction() async throws -> String {
    guard let portal else {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Portal not initialized.")
      throw PortalExampleAppError.portalNotInitialized()
    }

    let chainId = "eip155:11155111"
    guard let address = await portal.getAddress(chainId) else {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Address not found.")
      throw PortalExampleAppError.addressNotFound()
    }

    guard let user else {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ User not logged in.")
      throw PortalExampleAppError.userNotLoggedIn()
    }

    guard let config else {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Application configuration not set.")
      throw PortalExampleAppError.configurationNotSet()
    }

    _ = try await self.getGasPrice(chainId)

    let configURL = config.custodianServerUrl
    guard let url = URL(string: "\(configURL)/mobile/\(user.exchangeUserId)/transfer") else {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Invalid URL.")
      throw PortalExampleAppError.custodianServerUrlNotSet()
    }

    let payload =
      [
        "chainId": "11155111",
        "address": address,
        "amount": "0.001"
      ]

    do {
      let request = PortalAPIRequest(url: url, method: .post, payload: payload)
      let jsonDictionary = try await requests.execute(request: request, mappingInResponse: [String: String].self)
      guard let txnHash = jsonDictionary["txHash"] else {
        self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Invalid response type for request.")
        throw PortalExampleAppError.invalidResponseTypeForRequest()
      }

      return txnHash
    } catch {
      self.logger.error("ViewController.sendSepoliaTransaction() - ❌ Error: \(error)")
      throw error
    }
  }

  @IBAction func handleETHProviderHelperMethod(_: Any) {
    Task { @MainActor in
      portal?.ethGasPrice(completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethGasPrice result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethGasPrice result: \(String(describing: result))")
        }
      })

      let transactionParam = ETHTransactionParam(from: "4cd042bba0da4b3f37ea36e8a2737dce2ed70db7", to: "4cd042bba0da4b3f37ea36e8a2737dce2ed70db7", value: "0.0001")
      portal?.ethEstimateGas(transaction: transactionParam, completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethEstimateGas result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethEstimateGas result: \(String(describing: result))")
        }
      })

      portal?.ethGetBalance(completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethGetBalance result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethGetBalance result: \(String(describing: result))")
        }
      })

      portal?.ethSignTransaction(transaction: transactionParam, completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethSignTransaction result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethSignTransaction result: \(String(describing: result))")
        }
      })

      portal?.ethSendTransaction(transaction: transactionParam, completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethSendTransaction result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethSendTransaction result: \(String(describing: result))")
        }
      })

      portal?.ethSign(message: "0xdeadbeef", completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethSign result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethSign result: \(String(describing: result))")
        }
      })

      portal?.ethSignTypedDataV3(message: "0xdeadbeef", completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethSignTypedDataV3 result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethSignTypedDataV3 result: \(String(describing: result))")
        }
      })

      portal?.ethSignTypedData(message: "0xdeadbeef", completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved ethSignTypedData result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved ethSignTypedData result: \(String(describing: result))")
        }
      })

      portal?.personalSign(message: "0xdeadbeef", completion: { result in
        if let data = result.data {
          print("ViewController.handleETHProviderHelperMethod(): ✅ Successfully retrieved personalSign result.data: \(String(describing: data))")
        } else {
          print("ViewController.handleETHProviderHelperMethod(): ❌ failed to retrieved personalSign result: \(String(describing: result))")
        }
      })
    }
  }

  @IBAction func handleGenerate(_: UIButton!) {
    Task {
      do {
        self.startLoading()
        let (ethereum, _) = try await generate()
        let debugMessage = "ViewController.handleGenerate() - ✅ Wallet successfully created! Address: \(String(describing: ethereum))"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet generated")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGenerate() - ❌ Error creating wallet: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error creating wallet \(error)")
      }
    }
  }

  @IBAction func handleGenerateSolana(_: Any) {
    Task {
      do {
        self.startLoading()
        let solanaAddress = try await generateSolana()
        let debugMessage = "ViewController.handleGenerateSolana() - ✅ Solana wallet successfully created! Address: \(solanaAddress)"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Solana wallet generated")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGenerateSolana() - ❌ Error creating Solana wallet: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error creating Solana wallet \(error)")
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
        self.logger.debug("ViewController.handleGdriveBackup(): ✅ Successfully sent custodian cipherText.")
        self.showStatusView(message: "\(self.successStatus) Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGdriveBackup() - ❌ Error running backup: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running backup \(error)")
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
        let (ethereum, solana) = try await recover(String(user.exchangeUserId), withBackupMethod: .GoogleDrive)
        let debugMessage = "ViewController.handleGdriveRecover() - ✅ Wallet successfully recovered! ETH address: \(ethereum), Solana address: \(solana ?? "N/A")"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet successfully recovered!")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleGdriveRecover() - Error running recover: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running recover \(error)")
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
        self.showStatusView(message: "\(self.successStatus) Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleiCloudBackup() - ❌ Error running backup: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running backup \(error)")
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
        let (ethereum, solana) = try await recover(String(user.exchangeUserId), withBackupMethod: .iCloud)
        let debugMessage = "ViewController.handleiCloudRecover() - ✅ Wallet successfully recovered! ETH address: \(ethereum), Solana address: \(solana ?? "N/A")"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet successfully recovered!")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleiCloudRecover() - Error running recover: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running recover \(error)")
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
        self.showStatusView(message: "\(self.successStatus) Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyBackup() - Error running backup: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running backup \(error)")
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
        let (ethereum, solana) = try await recover(String(userId), withBackupMethod: .Passkey)
        let debugMessage = "ViewController.handlePasskeyRecover() - ✅ Wallet successfully recovered! ETH address: \(ethereum), Solana address: \(solana ?? "N/A")"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet successfully recovered!")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasskeyRecover() - Error running recover: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running recover \(error)")
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
        self.logger.debug("ViewController.handlePasswordBackup(): ✅ Successfully sent custodian cipherText.")
        self.showStatusView(message: "\(self.successStatus) Successfully sent custodian cipherText.")
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasswordBackup() - Error running backup: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running backup \(error)")
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
        let debugMessage = "ViewController.handlePasswordRecover() - ✅ Wallet successfully recovered! ETH address: \(ethereum), Solana address: \(solana ?? "N/A")"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet successfully recovered!")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePasswordRecover() - Error running recover: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error running recover \(error)")
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
        self.showStatusView(message: "\(self.successStatus) Successfully fetched balances.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching balances: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching balances \(error)")
        return
      }
      do {
        let assets = try await self.getAssets(for: "eip155:11155111")
        print(assets)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched  assets for chain eip155:11155111.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched assets for chain eip155:11155111.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching assets  for chain eip155:11155111: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching assets  for chain eip155:11155111 \(error)")
        return
      }

      do {
        let assets = try await self.getAssets(for: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
        print(assets)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched  assets for chain solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched assets for chain solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching assets  for chain solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching assets  for chain solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1 \(error)")
        return
      }
      do {
        let nfts = try await self.getNftAssets(chainId)
        print(nfts)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched NFT Assets.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched NFT Assets.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching NFT Assets: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching NFT Assets \(error)")
        return
      }
      do {
        let shares = try await self.getShareMetadata()
        print(shares)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched share metadata.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched share metadata.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching share metadata: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching share metadata \(error)")
      }
      do {
        let transactions = try await self.getTransactions(chainId)
        print(transactions)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched transactions.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched transactions.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching transactions: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching transactions \(error)")
        return
      }
      do {
        let address = await self.portal?.getAddress(chainId)
        let toAddress = (self.sendAddress?.text?.isEmpty ?? true) ? "0xdFd8302f44727A6348F702fF7B594f127dE3A902" : self.sendAddress?.text
        let transaction = [
          "from": address,
          "to": toAddress,
          "value": "0x10"
        ]
        let simulatedTransaction = try await self.simulateTransaction(chainId, transaction: transaction)
        print(simulatedTransaction)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully simulated transaction.")
        self.showStatusView(message: "\(self.successStatus) Successfully simulated transaction.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error simulating transaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error simulating transaction \(error)")
        return
      }

      // evaluate transaction
      let address = await self.portal?.getAddress(chainId)
      var toAddress = "0xdFd8302f44727A6348F702fF7B594f127dE3A902"
      if let sendAddress = self.sendAddress?.text, !sendAddress.isEmpty {
        toAddress = sendAddress
      }

      let evaluateTransactionParams = EvaluateTransactionParam(to: toAddress, value: "0x10", data: nil, maxFeePerGas: nil, maxPriorityFeePerGas: nil, gas: nil, gasPrice: nil)
      for operationType in EvaluateTransactionOperationType.allCases {
        do {
          print("Running evaluate transaction with operation type: \(operationType.rawValue)")
          let result = try await self.evaluateTransaction(
            chainId: chainId,
            transaction: evaluateTransactionParams,
            operationType: operationType
          )
          print(result)
          self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully evaluated transaction with operation type: \(operationType.rawValue).")
          self.showStatusView(message: "\(self.successStatus) Successfully evaluated transaction with operation type: \(operationType.rawValue).")
        } catch {
          self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error evaluating transaction with operation type: \(operationType.rawValue), Error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Error evaluating transaction with operation type: \(operationType.rawValue), Error: \(error)")
        }
      }

      do {
        try await testSolGetTransaction("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully executed sol_getTransaction request.")
        self.showStatusView(message: "\(self.successStatus) Successfully executed sol_getTransaction request.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error executing sol_getTransaction request: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error executing sol_getTransaction request: \(error)")
      }

      do {
        let buildTransactionParam = BuildTransactionParam(
          to: "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
          token: "ETH",
          amount: "0.001"
        )
        let eip155Transaction = try await self.buildEip155Transaction(params: buildTransactionParam)
        print(eip155Transaction)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched buildEip155Transaction.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched buildEip155Transaction.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching buildEip155Transaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching buildEip155Transaction \(error)")
        return
      }

      do {
        let buildTransactionParam = BuildTransactionParam(
          to: "GPsPXxoQA51aTJJkNHtFDFYui5hN5UxcFPnheJEHa5Du",
          token: "SOL",
          amount: "0.001"
        )
        let solanaTransaction = try await self.buildSolanaTransaction(params: buildTransactionParam)
        print(solanaTransaction)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched buildSolanaTransaction.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched buildSolanaTransaction.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching buildSolanaTransaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching buildSolanaTransaction \(error)")
        return
      }

      do {
        let walletCapabilities = try await self.getWalletCapabilities()
        print(walletCapabilities)
        self.logger.info("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ✅ Successfully fetched getWalletCapabilities.")
        self.showStatusView(message: "\(self.successStatus) Successfully fetched getWalletCapabilities.")
      } catch {
        self.logger.error("ViewController.testGetNFTsTrxsBalancesSharesAndSimTrx() - ❌ Error fetching getWalletCapabilities: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error fetching getWalletCapabilities \(error)")
        return
      }
    }
  }

  @IBAction func sendPressed(_: UIButton!) {
    Task {
      do {
        let trxHash = try await self.sendTransaction()
        self.logger.info("ViewController.handlSend() - ✅ Successfully sent transaction Trx Hash: \(trxHash)")
        self.showStatusView(message: "\(self.successStatus), Trx Hash: \(trxHash)")
      } catch {
        self.logger.error("ViewController.handleSend() - ❌ Error sending transaction: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error sending transaction \(error)")
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
        self.showStatusView(message: "\(self.successStatus) Successfully tested provider requests")
      } catch {
        self.logger.error("ViewController.testProviderRequests() - ❌ Error testing transactions: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error testing transactions \(error)")
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

        let response = try await portal.request(chainId, withMethod: .eth_sign, andParams: params)

        guard let signature = response.result as? String else {
          self.logger.error("ViewController.handlSign() - ❌ Invalid response type for request:")
          print(response.result)
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleSign() - ✅ Successfully signed message: \(signature)")
        self.showStatusView(message: "\(self.successStatus) Successfully signed message")
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSign() - ❌ Error signing message: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error signing message \(error)")
      }
    }
  }

  @IBAction func handlePersonalSign() {
    Task {
      do {
        let chainId = "eip155:11155111"

        guard let portal else {
          self.logger.error("ViewController.handlePersonalSign() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let address = await portal.getAddress(chainId) else {
          self.logger.error("ViewController.handlePersonalSign() - ❌ Address not found")
          throw PortalExampleAppError.addressNotFound()
        }

        self.startLoading()
        let params = ["0xdeadbeef", address]

        self.logger.debug("Params: \(params)")

        guard let response = try? await portal.request(chainId, withMethod: .personal_sign, andParams: params) else {
          self.logger.error("ViewController.handlePersonalSign() - ❌ Failed to process request")
          self.stopLoading()
          return
        }

        guard let signature = response.result as? String else {
          self.logger.error("ViewController.handlePersonalSign() - ❌ Invalid response type for request:")
          print(response.result)
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handlePersonalSign() - ✅ Successfully signed message: \(signature)")
        self.showStatusView(message: "\(self.successStatus) Successfully signed message")
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handlePersonalSign() - ❌ Error signing message: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error signing message \(error)")
      }
    }
  }

  @IBAction func handleRawSign() {
    Task {
      do {
        let chainId = "eip155:11155111"

        guard let portal else {
          self.logger.error("ViewController.handleRawSign() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }

        self.startLoading()

        let response = try await portal.rawSign(message: "74657374", chainId: chainId)

        guard let signature = response.result as? String else {
          self.logger.error("ViewController.handleRawSign() - ❌ Invalid response type for request:")
          print(response.result)
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleRawSign() - ✅ Successfully signed message: \(signature)")
        self.showStatusView(message: "\(self.successStatus) Successfully signed message")
        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleRawSign() - ❌ Error signing message: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Error signing message \(error)")
      }
    }
  }

  @IBAction func handleSwaps() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary,
            let SWAPS_API_KEY: String = infoDictionary["SWAPS_API_KEY"] as? String
      else {
        self.logger.error("ViewController.handleSwaps() - ❌ Error: Do you have `SWAPS_API_KEY=$(SWAPS_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleSwaps() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }

      let swaps: PortalSwapsProtocol = PortalSwaps(apiKey: SWAPS_API_KEY, portal: portal)
      let customChainId = "eip155:11155111"

      Task {
        do {
          let resourcesResult = try await swaps.getSources(forChainId: customChainId)
          print("getSources response:", resourcesResult)
        } catch {
          self.logger.error("ViewController.handleSwaps() - ❌ Unable to get sources with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get sources with error: \(error)")
          self.stopLoading()
        }

        let quoteArgs = QuoteArgs(
          buyToken: "0x68194a729c2450ad26072b3d33adacbcef39d574", // USDC on Sepolia
          sellToken: "ETH",
          sellAmount: "1000"
        )

        var quoteResult: Quote
        do {
          quoteResult = try await swaps.getQuote(args: quoteArgs, forChainId: customChainId)

        } catch {
          self.logger.error("ViewController.handleSwaps() - ❌ Unable to get quote with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get quote with error: \(error)")
          self.stopLoading()
          return
        }

        do {
          let sendTransactionResponse = try await portal.request(customChainId, withMethod: .eth_sendTransaction, andParams: [quoteResult.transaction])
          print("sendTransactionResponse", sendTransactionResponse)
          guard let transactionHash = sendTransactionResponse.result as? String else {
            throw PortalExampleAppError.invalidResponseTypeForRequest()
          }

          self.logger.info("ViewController.handleSwaps() - ✅ Successfully called get sources + quotes + submitted trx: \(transactionHash)")
          self.showStatusView(message: "\(self.successStatus) Successfully called get sources + quotes + submitted trx: \(transactionHash)")
        } catch {
          print("Error sending transaction", error)
        }
      }
    } catch {
      self.stopLoading()
      self.logger.error("ViewController.handleSwaps() - ❌ Error swap: \(error)")
      self.showStatusView(message: "\(self.failureStatus) Error swap: \(error)")
    }
  }

  // Method to display status messages on the UI
  func showStatusView(message: String) {
    self.statusLabel?.text = message
  }

  @IBAction func handleSolanaSendTrx() {
    Task {
      do {
        self.startLoading()

        guard let portal = self.portal else {
          self.logger.error("ViewController.handleSolanaSendTrx() - ❌ Portal or address not initialized/found")
          self.stopLoading()
          return
        }

        // Setup and address retrieval
        let chainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1" // Devnet

        let params = SendAssetParams(to: "75ZfLXXsSpycDvHTQuHnGQuYgd2ihb6Bu4viiCCQ7P4H", amount: "0.001", token: "NATIVE")

        let response = try await portal.sendAsset(chainId: chainId, params: params)

        self.logger.info("ViewController.handleSolanaSendTrx() - ✅ Successfully sent transaction")
        self.showStatusView(message: "\(self.successStatus) Successfully sent transaction")
        self.logger.info("ViewController.handleSolanaSendTrx() - ✅ Transaction Hash: \(response.txHash )")

        self.stopLoading()
      } catch {
        self.stopLoading()
        self.logger.error("ViewController.handleSolanaSendTrx() - ❌ Generic error: \(error)")
      }
    }
  }

  @available(iOS 17.0, *)
  @IBAction func didPressSettings(_: Any) {
    do {
      try openSettingsPage()
    } catch {
      print("ViewController.didPressSettings() - ❌ Cannot open settings. \(error)")
    }
  }
}

// MARK: - ETH balance refresh

@available(iOS 16.0, *)
extension ViewController {
  private func startRefreshBalanceTimer() {
    self.refreshBalanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task {
        do {
          try await self.populateEthBalance()
        } catch {
          print("Failed to refresh the the ETH balance. \(error)")
        }
      }
    }
    self.refreshBalanceTimer?.fire()
  }

  private func stopRefreshBalanceTimer() {
    self.refreshBalanceTimer?.invalidate()
  }
}

// MARK: - Settings

@available(iOS 17.0, *)
extension ViewController {
  func openSettingsPage() throws {
    guard let portal = self.portal else {
      throw PortalExampleAppError.portalNotInitialized()
    }

    let settingsView = SettingsView(portal: portal)
    let hostingController = UIHostingController(rootView: settingsView)
    self.present(hostingController, animated: true, completion: nil)
  }
}

//
//  Portal.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import Mpc

/// The main Portal class.
public class Portal {
  public var address: String? {
    return self.keychain.legacyAddress
  }

  public var client: ClientResponse? {
    get async throws { return try await self.api.client }
  }

  public var chainId: Int? {
    self.provider.chainId
  }

  public let api: PortalApi
  public let apiKey: String
  public let autoApprove: Bool
  public var backup: BackupOptions?
  public let isMocked: Bool
  public let keychain: PortalKeychain
  public let mpc: PortalMpc
  public var rpcConfig: [String: String]
  private let binary: Mobile
  private let featureFlags: FeatureFlags?

  public let provider: PortalProvider

  private let apiHost: String
  private let mpcHost: String
  private let version: String

  /// Create a Portal instance. This initializer is used by unit tests and mocks.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can obtain this through Portal's REST API.
  ///   - withRpcConfig: A dictionary of CAIP-2 Blockchain IDs (keys) and RPC URLs (values) in `[String:String]` format.
  ///   - featureFlags: (optional) a set of flags to opt into new or experimental features
  ///   - isSimulator: (optional) Whether you are testing on the iOS simulator or not.
  ///   - autoApprove: (optional) Auto-approve transactions.
  ///   - apiHost: (optional) Portal's API host.
  ///   - mpcHost: (optional) Portal's MPC API host.

  public init(
    _ apiKey: String,
    withRpcConfig: [String: String],
    // Optional
    autoApprove: Bool = false,
    featureFlags: FeatureFlags? = nil,
    version: String = "v6",
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    isMocked: Bool = false
  ) throws {
    if version != "v6" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v6' is currently supported.")
    }

    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.binary = isMocked ? MockMobileWrapper() : MobileWrapper()
    self.featureFlags = featureFlags
    self.isMocked = isMocked
    self.mpcHost = mpcHost
    self.rpcConfig = withRpcConfig
    self.version = version

    // Creating this as a variable first so it's usable to
    // fetch the client in the Task at the end of the initializer
    let api = PortalApi(apiKey: apiKey, apiHost: apiHost)

    self.api = api
    self.keychain = PortalKeychain()
    self.mpc = PortalMpc(apiKey: apiKey, api: self.api, keychain: self.keychain, mobile: MobileWrapper())
    self.provider = try PortalProvider(
      apiKey: apiKey,
      rpcConfig: withRpcConfig,
      keychain: self.keychain,
      autoApprove: autoApprove,
      apiHost: apiHost,
      mpcHost: mpcHost,
      featureFlags: featureFlags
    )

    // Initialize with PasskeyStorage by default
    if #available(iOS 16, *) {
      self.mpc.registerBackupMethod(.Passkey, withStorage: PasskeyStorage())
    }
    // Initialize with PasswordStorage by default
    self.mpc.registerBackupMethod(.Password, withStorage: PasswordStorage())
    // Initialize with iCloudStorage by default
    self.mpc.registerBackupMethod(.iCloud, withStorage: ICloudStorage())

    // Capture analytics.
    Task {
      do {
        if let client = try await api.client {
          _ = try await api.identify(["clientId": AnyEncodable(client.id)])
          _ = try await api.track(MetricsEvents.portalInitialized.rawValue, withProperties: [:])
        }
      } catch {
        // Do nothing to prevent failing from metrics.
      }
    }
  }

  @available(*, deprecated, renamed: "Portal", message: "We've updated our constructor to be more streamlined and support multiple wallets. Please see the migration guide at https://docs.portalhq.io/resources/migrating-from-v3-to-v4/")
  public init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychain,
    gatewayConfig: [Int: String],
    // Optional
    isSimulator: Bool = false,
    version: String = "v6",
    autoApprove: Bool = false,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    featureFlags: FeatureFlags? = nil,
    isMocked: Bool = false
  ) throws {
    // Basic setup
    self.binary = isMocked ? MockMobileWrapper() : MobileWrapper()
    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.backup = backup
    self.isMocked = isMocked
    self.keychain = keychain
    self.mpcHost = mpcHost
    self.version = version
    self.featureFlags = featureFlags

    if version != "v6" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v6' is currently supported.")
    }

    //  Handle the legacy use case of using Ethereum references as keys
    let rpcConfig: [String: String] = Dictionary(gatewayConfig.map { key, value in
      let newKey = "eip155:\(key)"
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })
    self.rpcConfig = rpcConfig

    // Initialize the PortalProvider
    self.provider = try PortalProvider(
      apiKey: apiKey,
      rpcConfig: rpcConfig,
      keychain: keychain,
      autoApprove: autoApprove,
      apiHost: apiHost,
      mpcHost: mpcHost,
      version: version,
      featureFlags: featureFlags
    )

    // Retain backward compatible chainId behavior
    self.provider.chainId = chainId

    // Initialize the Portal API
    let api = PortalApi(apiKey: apiKey, apiHost: apiHost, provider: self.provider, featureFlags: self.featureFlags)
    self.api = api
    keychain.api = api

    // This is to mimic the blocking behavior of the legacy GetClient() implementation
    // It ensures address information is available at the completion of the initialization
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      // Load client metadata
      try await keychain.loadMetadata()
      semaphore.signal()
    }
    semaphore.wait()

    // Initialize Mpc
    self.mpc = PortalMpc(
      apiKey: apiKey,
      api: self.api,
      keychain: keychain,
      isSimulator: isSimulator,
      host: mpcHost,
      version: version,
      mobile: self.binary,
      apiHost: self.apiHost,
      featureFlags: self.featureFlags
    )

    // Ensure storage adapters have access to the Portal API
    if let gDrive = backup.gdrive {
      self.mpc.registerBackupMethod(.GoogleDrive, withStorage: gDrive)
    }
    if let iCloud = backup.icloud {
      self.mpc.registerBackupMethod(.iCloud, withStorage: iCloud)
    }
    if let passwords = backup.passwordStorage {
      self.mpc.registerBackupMethod(.Password, withStorage: passwords)
    }
    if #available(iOS 16, *) {
      if let passkeys = backup.passkeyStorage {
        passkeys.apiKey = apiKey
        mpc.registerBackupMethod(.Passkey, withStorage: passkeys)
      }
    }

    // Capture analytics.
    Task {
      do {
        if let client = try await api.client {
          _ = try await api.identify(["clientId": AnyEncodable(client.id)])
          _ = try await api.track(MetricsEvents.portalInitialized.rawValue, withProperties: [:])
        }
      } catch {
        // Do nothing to prevent failing from metrics.
      }
    }
  }

  /// Create a Portal instance. This initializer is used by unit tests and mocks.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can obtain this through Portal's REST API.
  ///   - backup: The backup options to use.
  ///   - chainId: The chainId you want the provider to use.
  ///   - keychain: An instance of PortalKeychain.
  ///   - gatewayConfig: A dictionary of chainIds (keys) and gateway URLs (values).
  ///   - mpc:  Portal's mpc class
  ///   - api:  Portal's api class
  ///   - binary: Portal's mpc binary class
  ///   - isSimulator: (optional) Whether you are testing on the iOS simulator or not.
  ///   - address: (optional) An address.
  ///   - apiHost: (optional) Portal's API host.
  ///   - autoApprove: (optional) Auto-approve transactions.
  ///   - mpcHost: (optional) Portal's MPC API host.

  @available(*, deprecated, renamed: "Portal", message: "We've updated our constructor to be more streamlined and support multiple wallets. Please see the migration guide at https://docs.portalhq.io/resources/migrating-from-v3-to-v4/")
  public init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychain,
    gatewayConfig: [Int: String],
    // Optional
    isSimulator: Bool = false,
    version: String = "v6",
    autoApprove: Bool = false,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    mpc: PortalMpc?,
    api: PortalApi?,
    binary: Mobile?,
    featureFlags: FeatureFlags? = nil,
    isMocked: Bool = false
  ) throws {
    // Basic setup
    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.binary = binary ?? MobileWrapper()
    self.isMocked = isMocked
    self.keychain = keychain
    self.mpcHost = mpcHost
    self.version = version
    self.featureFlags = featureFlags

    if version != "v6" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v6' is currently supported.")
    }

    //  Handle the legacy use case of using Ethereum references as keys
    let rpcConfig: [String: String] = Dictionary(gatewayConfig.map { key, value in
      let newKey = "eip155:\(key)"
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })
    self.rpcConfig = rpcConfig

    // Initialize the PortalProvider
    self.provider = isMocked
      ? try MockPortalProvider(
        apiKey: apiKey,
        rpcConfig: rpcConfig,
        keychain: keychain,
        autoApprove: autoApprove,
        apiHost: apiHost,
        mpcHost: mpcHost,
        version: version,
        featureFlags: featureFlags
      )
      : try PortalProvider(
        apiKey: apiKey,
        rpcConfig: rpcConfig,
        keychain: keychain,
        autoApprove: autoApprove,
        apiHost: apiHost,
        mpcHost: mpcHost,
        version: version,
        featureFlags: featureFlags
      )

    self.provider.chainId = chainId

    // Initialize the Portal API
    let api = api ?? PortalApi(apiKey: apiKey, apiHost: apiHost, provider: self.provider)
    self.api = api
    keychain.api = api

    // This is to mimic the blocking behavior of the legacy GetClient() implementation
    // It ensures address information is available at the completion of the initialization
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      // Load client metadata
      try await keychain.loadMetadata()
      semaphore.signal()
    }
    semaphore.wait()

    // Initialize Mpc
    self.mpc = mpc ?? PortalMpc(
      apiKey: apiKey,
      api: self.api,
      keychain: keychain,
      isSimulator: isSimulator,
      host: mpcHost,
      version: version,
      mobile: self.binary
    )

    if let gDrive = backup.gdrive {
      self.mpc.registerBackupMethod(.GoogleDrive, withStorage: gDrive)
    }
    if let iCloud = backup.icloud {
      self.mpc.registerBackupMethod(.iCloud, withStorage: iCloud)
    }
    if let passwords = backup.passwordStorage {
      self.mpc.registerBackupMethod(.Password, withStorage: passwords)
    }
    if #available(iOS 16, *) {
      if let passkeys = backup.passkeyStorage {
        passkeys.apiKey = apiKey
        self.mpc.registerBackupMethod(.Passkey, withStorage: passkeys)
      }
    }

    // Capture analytics.
    Task {
      do {
        if let client = try await api.client {
          _ = try await api.identify(["clientId": AnyEncodable(client.id)])
          _ = try await api.track(MetricsEvents.portalInitialized.rawValue, withProperties: [:])
        }
      } catch {
        // Do nothing to prevent failing from metrics.
      }
    }
  }

  /**********************************
   * Public functions
   **********************************/

  // Primitive helpers

  public func getAddress(_ forChainId: String) async -> String? {
    do {
      let address = try await keychain.getAddress(forChainId)

      return address
    } catch {
      return nil
    }
  }

  @available(iOS 16, *)
  public func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws {
    try self.mpc.setPasskeyAuthenticationAnchor(anchor)
  }

  public func setPassword(_ value: String) throws {
    try self.mpc.setPassword(value)
  }

  // Wallet lifecycle helpers

  public func availableRecoveryMethods(_ forChainId: String? = nil) async throws -> [BackupMethods] {
    if let client = try await client {
      // Filter by chainId if one is provided
      if let chainId = forChainId {
        let chainIdParts = chainId.split(separator: ":").map(String.init)
        guard let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = keychain.metadata?.namespaces[namespace] else {
          throw PortalClassError.unsupportedChainId(chainId)
        }
        let curveWallet = client.wallets.first { wallet in
          wallet.curve == curve
        }
        guard let wallet = curveWallet else {
          throw PortalClassError.noWalletFoundForChain(chainId)
        }

        let availableRecoveryMethods = wallet.backupSharePairs.filter { share in
          share.status == .completed
        }.map { share in
          share.backupMethod
        }

        return availableRecoveryMethods
      } else {
        let availableRecoveryMethods = client.wallets.map { wallet in
          wallet.backupSharePairs.filter { share in
            share.status == .completed
          }.map { share in
            share.backupMethod
          }
        }.flatMap { $0 }

        return availableRecoveryMethods
      }
    }

    throw PortalClassError.clientNotAvailable
  }

  public func doesWalletExist(_ forChainId: String? = nil) async throws -> Bool {
    if let client = try await client {
      // Filter by chainId if one is provided
      if let chainId = forChainId {
        let chainIdParts = chainId.split(separator: ":").map(String.init)
        if let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = keychain.metadata?.namespaces[namespace] {
          let curveWallet = client.wallets.first { wallet in
            wallet.curve == curve
          }
          if let wallet = curveWallet {
            let share = wallet.signingSharePairs.first { signingShare in
              signingShare.status == .completed
            }

            return share != nil
          }
        }

        return false
      } else {
        let wallets = client.wallets
        let shares = client.wallets.map { wallet in
          wallet.signingSharePairs.first { signingShare in
            signingShare.status == .completed
          }
        }

        return wallets.count > 0 && shares.count > 0
      }
    }

    throw PortalClassError.clientNotAvailable
  }

  public func isWalletBackedUp(_ forChainId: String? = nil) async throws -> Bool {
    if let client = try await client {
      // Filter by chainId if one is provided
      if let chainId = forChainId {
        let chainIdParts = chainId.split(separator: ":").map(String.init)
        if let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = keychain.metadata?.namespaces[namespace] {
          let curveWallet = client.wallets.first { wallet in
            wallet.curve == curve
          }
          if let wallet = curveWallet {
            let share = wallet.backupSharePairs.first { signingShare in
              signingShare.status == .completed
            }

            return share != nil
          }
        }

        return false
      } else {
        let wallets = client.wallets
        let shares = client.wallets.map { wallet in
          wallet.backupSharePairs.first { signingShare in
            signingShare.status == .completed
          }
        }

        return wallets.count > 0 && shares.count > 0
      }
    }

    throw PortalClassError.clientNotAvailable
  }

  public func isWalletOnDevice(_ forChainId: String? = nil) async throws -> Bool {
    let shares = try await keychain.getShares()
    // Filter by chainId if one is provided
    if let chainId = forChainId {
      let chainIdParts = chainId.split(separator: ":").map(String.init)
      guard let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = keychain.metadata?.namespaces[namespace] else {
        throw PortalClassError.unsupportedChainId(chainId)
      }

      if let _ = shares[curve.rawValue] {
        return true
      }

      return false
    } else {
      let validShare = shares.values.first { share in
        !share.id.isEmpty
      }

      return validShare != nil
    }
  }

  public func isWalletRecoverable(_ forChainId: String? = nil) async throws -> Bool {
    let availableRecoveryMethods = try await availableRecoveryMethods(forChainId)

    return availableRecoveryMethods.count > 0
  }

  // Wallet management

  public func backupWallet(
    _ method: BackupMethods,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> PortalBackupWalletResponse {
    // Run backup
    let response = try await mpc.backup(method, usingProgressCallback: usingProgressCallback)

    // Build the storage callback
    let storageCallback: () async throws -> Void = {
      try await self.api.updateShareStatus(
        .backup,
        status: .STORED_CLIENT_BACKUP_SHARE,
        sharePairIds: response.shareIds
      )
    }

    return PortalBackupWalletResponse(
      cipherText: response.cipherText,
      storageCallback: storageCallback
    )
  }

  public func createWallet(usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> [PortalNamespace: String?] {
    let addresses = try await mpc.generate(withProgressCallback: usingProgressCallback)

    return addresses
  }

  public func eject(_ method: BackupMethods, withCipherText: String, andOrganizationBackupShare: String) async throws -> String {
    let privateKey = try await mpc.eject(method, withCipherText: withCipherText, andOrganizationBackupShare: andOrganizationBackupShare)

    return privateKey
  }

  public func recoverWallet(
    _ method: BackupMethods,
    withCipherText: String,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> [PortalNamespace: String?] {
    let addresses = try await mpc.recover(method, withCipherText: withCipherText, usingProgressCallback: usingProgressCallback)

    return addresses
  }

  public func registerBackupMethod(_ method: BackupMethods, withStorage: PortalStorage) {
    self.mpc.registerBackupMethod(method, withStorage: withStorage)
  }

  /**********************************
   * Deprecated functions
   **********************************/

  /**********************************
   * Wallet Helper Methods
   **********************************/

  @available(*, deprecated, renamed: "backupWallet", message: "Please use the async implamentation of backupWallet()")
  public func backupWallet(
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.backup(method: method, backupConfigs: backupConfigs, completion: completion, progress: progress)
  }

  @available(*, deprecated, renamed: "createWallet", message: "Please use the async implementation of createWallet()")
  public func createWallet(
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.generate(completion: completion, progress: progress)
  }

  @available(*, deprecated, renamed: "recoverWallet", message: "Please use the async implementation of recoverWallet()")
  public func recoverWallet(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.recover(cipherText: cipherText, method: method, backupConfigs: backupConfigs, completion: completion, progress: progress)
  }

  @available(*, deprecated, renamed: "eject", message: "Please use the async implementation of eject()")
  public func ejectPrivateKey(
    clientBackupCiphertext: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    orgBackupShare: String,
    completion: @escaping (Result<String>) -> Void
  ) {
    self.mpc.ejectPrivateKey(clientBackupCiphertext: clientBackupCiphertext, method: method, backupConfigs: backupConfigs, orgBackupShare: orgBackupShare, completion: completion)
  }

  public func provisionWallet(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.recoverWallet(cipherText: cipherText, method: method, backupConfigs: backupConfigs, completion: completion, progress: progress)
  }

  /**********************************
   * Provider Helper Methods
   **********************************/

  public func emit(_ event: Events.RawValue, data: Any) {
    _ = self.provider.emit(event: event, data: data)
  }

  public func ethEstimateGas(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.EstimateGas.rawValue,
      params: [transaction]
    ), completion: completion)
  }

  public func ethGasPrice(
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.GasPrice.rawValue,
      params: []
    ), completion: completion)
  }

  public func ethGetBalance(
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.GetBalance.rawValue,
      params: [address, "latest"]
    ), completion: completion)
  }

  public func ethSendTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [transaction]
    ), completion: completion)
  }

  public func ethSign(message: String, completion: @escaping (Result<RequestCompletionResult>) -> Void) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }

    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.Sign.rawValue,
      params: [
        address,
        message,
      ]
    ), completion: completion)
  }

  public func ethSignTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SignTransaction.rawValue,
      params: [transaction]
    ), completion: completion)
  }

  public func ethSignTypedDataV3(
    message: String,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }

    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.SignTypedDataV3.rawValue,
      params: [address, message]
    ), completion: completion)
  }

  public func ethSignTypedData(
    message: String,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }

    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.SignTypedDataV4.rawValue,
      params: [address, message]
    ), completion: completion)
  }

  public func on(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.on(event: event, callback: callback)
  }

  public func once(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.once(event: event, callback: callback)
  }

  public func personalSign(
    message: String,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }

    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.PersonalSign.rawValue,
      params: [
        message,
        address,
      ]
    ), completion: completion)
  }

  public func request(
    method: ETHRequestMethods.RawValue,
    params: [Any],
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    do {
      let encodedParams = try params.map { param in
        try AnyEncodable(param)
      }
      self.provider.request(payload: ETHRequestPayload(
        method: method,
        params: encodedParams
      ), completion: completion)
    } catch {
      completion(Result(error: error))
    }
  }

  /// Set the chainId on the instance and update MPC and Provider chainId
  /// - Parameters:
  ///   - to: The chainId to use for processing wallet transactions
  /// - Returns: Void
  public func setChainId(to: Int) throws {
    _ = try self.provider.setChainId(value: to)
  }

  /****************************************
   * Keychain Helper Methods
   ****************************************/

  public func deleteAddress() throws {
    try self.keychain.deleteAddress()
  }

  public func deleteSigningShare() throws {
    try self.keychain.deleteSigningShare()
  }

  /****************************************
   * Portal Connect Helper Methods
   ****************************************/

  public func createPortalConnectInstance(
    webSocketServer: String = "connect.portalhq.io"
  ) throws -> PortalConnect {
    try PortalConnect(
      self.apiKey,
      self.provider.chainId ?? 11_155_111,
      self.keychain,
      self.rpcConfig,
      webSocketServer,
      self.autoApprove,
      self.apiHost,
      self.mpcHost,
      self.version
    )
  }
}

/*****************************************
 * Supporting Enums & Structs
 *****************************************/

enum PortalClassError: Error, Equatable {
  case clientNotAvailable
  case noWalletFoundForChain(String)
  case unsupportedChainId(String)
}

enum PortalProviderError: Error, Equatable {
  case invalidChainId(_ message: String)
  case invalidRequestParams
  case invalidRpcResponse
  case noAddress
  case noRpcUrlFoundForChainId(_ message: String)
  case unableToEncodeParams
  case unsupportedRequestMethod(_ message: String)
}

/// The list of backup methods for PortalSwift.
public enum BackupMethods: String, Codable {
  case GoogleDrive = "GDRIVE"
  case iCloud = "ICLOUD"
  case local = "CUSTOM"
  case Password = "PASSWORD"
  case Passkey = "PASSKEY"
  case Unknown = "UNKNOWN"

  init?(fromString: String) {
    self.init(rawValue: fromString)
  }
}

/// Gateway URL errors.
public enum PortalArgumentError: Error {
  case invalidGatewayConfig
  case noGatewayConfigForChain(chainId: Int)
  case versionNoLongerSupported(message: String)
  case unableToGetClient
}

public enum PortalCurve: String, Codable {
  case ED25519
  case SECP256K1
}

public enum PortalNamespace: String, Codable {
  case eip155
  case solana
}

public enum PortalSharePairStatus: String, Codable {
  case completed
  case incomplete
}

public enum PortalSharePairType: String, Codable {
  case backup
  case signing
}

//
//  Portal.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import AuthenticationServices
import Foundation
import SolanaSwift

/// The main Portal class.
public class Portal {
  @available(*, deprecated, renamed: "addresses", message: "Please use the async getter for `addresses`")
  public var address: String? {
    self.keychain.legacyAddress
  }

  public var addresses: [PortalNamespace: String?] {
    get async throws {
      try await self.keychain.getAddresses()
    }
  }

  public var client: ClientResponse? {
    get async throws { try await self.api.client }
  }

  public var chainId: Int? {
    self.provider.chainId
  }

  public let api: PortalApiProtocol
  let apiKey: String
  public let autoApprove: Bool
  public var gatewayConfig: [Int: String] = [:]
  public var provider: PortalProviderProtocol
  public var rpcConfig: [String: String]

  private let apiHost: String
  private var backup: BackupOptions?
  private let binary: Mobile
  private let featureFlags: FeatureFlags?
  private var keychain: PortalKeychainProtocol
  private let mpc: PortalMpcProtocol
  private let mpcHost: String
  private let version: String

  /// Create a Portal instance. This initializer is used by unit tests and mocks.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can obtain this through Portal's REST API.
  ///   - withRpcConfig: (optional) A dictionary of CAIP-2 Blockchain IDs (keys) and RPC URLs (values) in `[String:String]` format.
  ///   - featureFlags: (optional) a set of flags to opt into new or experimental features
  ///   - isSimulator: (optional) Whether you are testing on the iOS simulator or not.
  ///   - autoApprove: (optional) Auto-approve transactions.
  ///   - apiHost: (optional) Portal's API host.
  ///   - mpcHost: (optional) Portal's MPC API host.

  public init(
    _ apiKey: String,
    withRpcConfig: [String: String] = [:],
    // Optional
    autoApprove: Bool = false,
    featureFlags: FeatureFlags? = nil,
    version: String = "v6",
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    api: PortalApiProtocol? = nil,
    binary: Mobile? = nil,
    gDrive: GDriveStorage? = nil,
    iCloud: ICloudStorage? = nil,
    keychain: PortalKeychainProtocol? = nil,
    mpc: PortalMpcProtocol? = nil,
    passwords: PasswordStorage? = nil
  ) throws {
    if version != "v6" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v6' is currently supported.")
    }

    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.binary = binary ?? MobileWrapper()
    self.featureFlags = featureFlags
    self.keychain = keychain ?? PortalKeychain()
    self.mpcHost = mpcHost
    self.rpcConfig = withRpcConfig.isEmpty ? Portal.buildDefaultRpcConfig(apiHost) : withRpcConfig
    self.version = version

    self.provider = try PortalProvider(
      apiKey: apiKey,
      rpcConfig: self.rpcConfig,
      keychain: self.keychain,
      autoApprove: autoApprove,
      mpcHost: mpcHost,
      featureFlags: featureFlags
    )

    // Creating this as a variable first so it's usable to
    // fetch the client in the Task at the end of the initializer
    let api = api ?? PortalApi(apiKey: apiKey, apiHost: apiHost, provider: provider)
    self.api = api
    self.keychain.api = api
    self.provider.api = api

    self.mpc = mpc ?? PortalMpc(apiKey: apiKey, api: self.api, keychain: self.keychain, host: mpcHost, mobile: self.binary, featureFlags: featureFlags)

    // Handle iCloud storage
    let iCloudStorage: ICloudStorage
    if let iCloud = iCloud {
      iCloud.mobile = self.binary
      iCloudStorage = iCloud
    } else {
      iCloudStorage = ICloudStorage(mobile: self.binary)
    }

    // Handle GDrive storage
    let gDriveStorage: GDriveStorage
    if let gDrive = gDrive {
      gDrive.mobile = self.binary
      gDriveStorage = gDrive
    } else {
      gDriveStorage = GDriveStorage(mobile: self.binary)
    }

    // Initialize with PasskeyStorage by default
    if #available(iOS 16, *) {
      self.mpc.registerBackupMethod(
        .Passkey,
        withStorage: PasskeyStorage()
      )
    }
    self.mpc.registerBackupMethod(
      .Password,
      withStorage: passwords ?? PasswordStorage()
    )
    self.mpc.registerBackupMethod(
      .iCloud,
      withStorage: iCloudStorage
    )
    self.mpc.registerBackupMethod(
      .GoogleDrive,
      withStorage: gDriveStorage
    )
    self.mpc.registerBackupMethod(
      .local,
      withStorage: LocalFileStorage()
    )

    // Capture metrics.
    Task {
      if let client = try? await api.client {
        _ = try? await api.identify([
          "id": AnyCodable(client.id),
          "custodianId": AnyCodable(client.custodian.id)
        ])
        _ = try? await api.track(
          MetricsEvents.portalInitialized.rawValue,
          withProperties: [:]
        )
      }
    }
  }

  @available(*, deprecated, renamed: "Portal", message: "We've updated our constructor to be more streamlined and support multiple wallets. Please see the migration guide at https://docs.portalhq.io/resources/migrating-from-v3-to-v4/")
  public init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychainProtocol,
    gatewayConfig: [Int: String],
    // Optional
    isSimulator: Bool = false,
    version: String = "v6",
    autoApprove: Bool = false,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    featureFlags: FeatureFlags? = nil
  ) throws {
    // Basic setup
    self.binary = MobileWrapper()
    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.backup = backup
    self.gatewayConfig = gatewayConfig
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
      mpcHost: mpcHost,
      version: version,
      featureFlags: featureFlags
    )

    // Retain backward compatible chainId behavior
    self.provider.chainId = chainId

    // Initialize the Portal API
    let api = PortalApi(apiKey: apiKey, apiHost: apiHost, provider: self.provider, featureFlags: self.featureFlags)
    self.api = api
    self.keychain.api = api

    // This is to mimic the blocking behavior of the legacy GetClient() implementation
    // It ensures address information is available at the completion of the initialization
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      // Load client metadata
      try await keychain.loadMetadata()
      semaphore.signal()
    }
    semaphore.wait()
    // End legacy GetClient() implementation

    print("Portal initializer done!")

    // Initialize Mpc
    self.mpc = PortalMpc(
      apiKey: apiKey,
      api: self.api,
      keychain: keychain,
      host: mpcHost,
      isSimulator: isSimulator,
      version: version,
      mobile: self.binary,
      apiHost: self.apiHost,
      featureFlags: self.featureFlags
    )

    // Ensure storage adapters have access to the Portal API
    if let gDrive = backup.gdrive {
      gDrive.mobile = self.binary
      self.mpc.registerBackupMethod(.GoogleDrive, withStorage: gDrive)
    }
    if let iCloud = backup.icloud {
      iCloud.mobile = self.binary
      self.mpc.registerBackupMethod(.iCloud, withStorage: iCloud)
    }
    if let local = backup.local {
      self.mpc.registerBackupMethod(.local, withStorage: local)
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
      if let client = try? await api.client {
        _ = try? await api.identify(["id": AnyCodable(client.id), "custodianId": AnyCodable(client.custodian.id)])
        _ = try? await api.track(MetricsEvents.portalInitialized.rawValue, withProperties: [:])
      }
    }
  }

  /**********************************
   * Public functions
   **********************************/

  // Primitive helpers

  public func registerBackupMethod(_ method: BackupMethods, withStorage: PortalStorage) {
    self.mpc.registerBackupMethod(method, withStorage: withStorage)
  }

  /// Configures Google Drive settings for the SDK.
  ///
  /// This method allows you to configure where backups are stored in Google Drive:
  /// - **App Data Folder**: A hidden, app-specific storage area that is not visible to the user in their Google Drive interface. This is ideal for sensitive data or configurations that the user doesn't need to manage directly.
  /// - **Google Drive Files**: A visible folder in the user's Google Drive, accessible and manageable by the user. This is suitable for backups the user might want to view, share, or organize manually.
  ///
  /// - Parameters:
  ///   - clientId: The client ID for the Google Drive integration.
  ///   - folderName: The name of the folder to be used for storing data in Google Drive. Defaults to `"_PORTAL_MPC_DO_NOT_DELETE_"`.
  ///
  /// - Throws: An error if the Google Drive configuration fails.
  ///
  /// Use this method to set up Google Drive integration for backing and recover.
  @available(*, deprecated, message: "Use setGDriveConfiguration(clientId:backupOption:) instead.")
  public func setGDriveConfiguration(
    clientId: String,
    folderName: String = "_PORTAL_MPC_DO_NOT_DELETE_"
  ) throws {
    try self.mpc.setGDriveConfiguration(clientId: clientId, backupOption: .gdriveFolder(folderName: folderName))
  }

  /// Configures Google Drive settings for the SDK with a specified backup option.
  ///
  /// This method allows you to set up Google Drive integration and choose the backup storage strategy using the `GDriveBackupOption` enum.
  ///
  /// - Parameters:
  ///   - clientId: The client ID for the Google Drive integration.
  ///   - backupOption: An option from the `GDriveBackupOption` enum that specifies the backup/recover storage type:
  ///     - `appDataFolder`: Stores backups in the hidden, app-specific "App Data Folder" in Google Drive. This folder is not visible to the user.
  ///     - `appDataFolderWithFallback`: Attempts to store backups and recover using the "App Data Folder". If recover fails, it automatically falls back to a user-visible Google Drive.
  ///     - `gdriveFolder(folderName: String)`: Stores backups in a user-visible folder in Google Drive with the specified `folderName`.
  ///
  /// - Throws: An error if the Google Drive configuration fails.
  ///
  /// ## Important Notes:
  /// - The `appDataFolder` and `appDataFolderWithFallback` options are supported starting from SDK version 4.2.0. Those options cannot be used with an earlier SDK version, backups stored in the App Data Folder will be lost.
  /// - Choose the appropriate backup option based on your application's requirements. For example, use the `App Data Folder` for sensitive or hidden backups, and a visible folder for backups the user may want to manage manually.
  public func setGDriveConfiguration(clientId: String, backupOption: GDriveBackupOption) throws {
    try self.mpc.setGDriveConfiguration(clientId: clientId, backupOption: backupOption)
  }

  /// Sets the view controller to be used for presenting Google Drive-related UI.
  ///
  /// - Parameter view: A `UIViewController` instance that will be used to present Google Drive UI components.
  ///
  /// - Throws: An error if the Google Drive view configuration fails.
  ///
  /// Use this method to specify the view controller that handles Google Drive-related interactions or presentations.
  public func setGDriveView(_ view: UIViewController) throws {
    try self.mpc.setGDriveView(view)
  }

  @available(iOS 16, *)
  public func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws {
    try self.mpc.setPasskeyAuthenticationAnchor(anchor)
  }

  @available(iOS 16, *)
  public func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws {
    try self.mpc.setPasskeyConfiguration(relyingParty: relyingParty, webAuthnHost: webAuthnHost)
  }

  public func setPassword(_ value: String) throws {
    try self.mpc.setPassword(value)
  }

  // Wallet management helpers

  public func backupWallet(
    _ method: BackupMethods,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> (cipherText: String, storageCallback: () async throws -> Void) {
    // Run backup
    let response = try await mpc.backup(method, usingProgressCallback: usingProgressCallback)

    // Build the storage callback
    let storageCallback: () async throws -> Void = {
      try await self.api.updateShareStatus(
        .backup,
        status: .STORED_CLIENT_BACKUP_SHARE,
        sharePairIds: response.shareIds
      )
      try await self.api.refreshClient()
      try await self.keychain.loadMetadata()
    }

    return (
      cipherText: response.cipherText,
      storageCallback: storageCallback
    )
  }

  public func createWallet(usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> PortalCreateWalletResponse {
    let addresses = try await mpc.generate(withProgressCallback: usingProgressCallback)

    guard let ethereumAddress = addresses[.eip155] ?? nil,
          let solanaAddress = addresses[.solana] ?? nil
    else {
      throw PortalClassError.cannotCreateWallet
    }

    return PortalCreateWalletResponse(
      ethereum: ethereumAddress,
      solana: solanaAddress
    )
  }

  /// You should only call this function if you are upgrading from v3 to v4.
  public func createSolanaWallet(usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> String {
    let addresses = try await mpc.generateSolanaWallet(usingProgressCallback: usingProgressCallback)
    return addresses
  }

  public func eject(
    _ method: BackupMethods,
    withCipherText: String? = nil,
    andOrganizationBackupShare: String? = nil
  ) async throws -> String {
    let privateKeys = try await mpc.eject(
      method,
      withCipherText: withCipherText,
      andOrganizationBackupShare: andOrganizationBackupShare,
      andOrganizationSolanaBackupShare: nil,
      usingProgressCallback: nil
    )

    guard let privateKey = privateKeys[.eip155] else {
      throw MpcError.unableToEjectWallet("No Ethereum private key found.")
    }

    return privateKey
  }

  public func ejectPrivateKeys(
    _ method: BackupMethods,
    withCipherText: String? = nil,
    andOrganizationBackupShare: String? = nil,
    andOrganizationSolanaBackupShare: String? = nil
  ) async throws -> [PortalNamespace: String] {
    let privateKeys = try await mpc.eject(
      method,
      withCipherText: withCipherText,
      andOrganizationBackupShare: andOrganizationBackupShare,
      andOrganizationSolanaBackupShare: andOrganizationSolanaBackupShare,
      usingProgressCallback: nil
    )

    return privateKeys
  }

  public func recoverWallet(
    _ method: BackupMethods,
    withCipherText: String? = nil,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> PortalRecoverWalletResponse {
    let addresses = try await mpc.recover(method, withCipherText: withCipherText, usingProgressCallback: usingProgressCallback)

    guard let ethereumAddress = addresses[.eip155] ?? nil
    else {
      throw PortalClassError.cannotRecoverWallet
    }

    return PortalRecoverWalletResponse(
      ethereum: ethereumAddress,
      solana: addresses[.solana] ?? nil
    )
  }

  /// You should only call this function if you are upgrading from v3 to v4.
  public func generateSolanaWalletAndBackupShares(
    _ method: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> (solanaAddress: String, cipherText: String, storageCallback: () async throws -> Void) {
    // Run generateSolanaWalletAndBackupShares
    let result = try await mpc.generateSolanaWalletAndBackupShares(backupMethod: method, usingProgressCallback: usingProgressCallback)

    // Build the storage callback
    let storageCallback: () async throws -> Void = {
      try await self.api.updateShareStatus(
        .backup,
        status: .STORED_CLIENT_BACKUP_SHARE,
        sharePairIds: result.backupResponse.shareIds
      )
      try await self.api.refreshClient()
    }

    return (
      solanaAddress: result.solanaAddress,
      cipherText: result.backupResponse.cipherText,
      storageCallback: storageCallback
    )
  }

  // Keychain helpers

  public func deleteShares() async throws {
    try await self.keychain.deleteShares()
  }

  public func getAddress(_ forChainId: String) async -> String? {
    do {
      let address = try await keychain.getAddress(forChainId)

      return address
    } catch {
      return nil
    }
  }

  public func getAddresses() async throws -> [PortalNamespace: String?] {
    try await self.keychain.getAddresses()
  }

  // Provider helpers

  public func emit(_ event: Events.RawValue, data: Any) {
    _ = self.provider.emit(event: event, data: data)
  }

  public func on(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.on(event: event, callback: callback)
  }

  public func once(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.once(event: event, callback: callback)
  }

  public func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [Any]?) async throws -> PortalProviderResult {
    guard let andParams = andParams else {
      throw PortalProviderError.invalidRequestParams
    }

    let params = andParams.map { param in
      AnyCodable(param)
    }

    return try await self.provider.request(chainId, withMethod: withMethod, andParams: params, connect: nil)
  }

  public func request(_ chainId: String, withMethod: String, andParams: [Any]) async throws -> PortalProviderResult {
    guard let method = PortalRequestMethod(rawValue: withMethod) else {
      throw PortalProviderError.unsupportedRequestMethod(withMethod)
    }

    return try await self.request(chainId, withMethod: method, andParams: andParams)
  }

  public func getRpcUrl(forChainId: String) async -> String? {
    return try? self.provider.getRpcUrl(forChainId)
  }

  // Wallet lifecycle helpers

  public func availableRecoveryMethods(_ forChainId: String? = nil) async throws -> [BackupMethods] {
    if let client = try await client {
      // Filter by chainId if one is provided
      if let chainId = forChainId {
        let chainIdParts = chainId.split(separator: ":").map(String.init)
        guard let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = try await keychain.metadata?.namespaces[namespace] else {
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
        if let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = try await keychain.metadata?.namespaces[namespace] {
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
        if let namespace = PortalNamespace(rawValue: chainIdParts[0]), let curve = try await keychain.metadata?.namespaces[namespace] {
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
        let shares = client.wallets.compactMap { wallet in
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

      guard chainIdParts.count > 0
      else {
        throw PortalClassError.invalidChainId(chainId)
      }

      guard let namespace = PortalNamespace(rawValue: chainIdParts[0]),
            let curve = try await keychain.metadata?.namespaces[namespace]
      else {
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

  // Api helpers

  public func getBalances(_ chainId: String) async throws -> [FetchedBalance] {
    try await self.api.getBalances(chainId)
  }

  public func getAssets(_ chainId: String) async throws -> AssetsResponse {
    try await self.api.getAssets(chainId)
  }

  public func getBackupShares(_ chainId: String? = nil) async throws -> [FetchedSharePair] {
    guard let client = try await client else {
      throw PortalClassError.clientNotAvailable
    }

    // Handle specific chainId
    if let chainId {
      let namespaceString = chainId.split(separator: ":").map(String.init)[0]
      guard let namespace = PortalNamespace(rawValue: namespaceString) else {
        throw PortalClassError.unsupportedChainId(chainId)
      }
      guard let curve = try await keychain.metadata?.namespaces[namespace] else {
        throw PortalClassError.unsupportedChainId(chainId)
      }
      let wallet = client.wallets.first { wallet in
        wallet.curve == curve
      }
      guard let wallet else {
        throw PortalClassError.noWalletFoundForChain(chainId)
      }

      return try await self.api.getSharePairs(.backup, walletId: wallet.id)
    }

    let walletIds = client.wallets.map(\.id)
    var sharePairGroups: [[FetchedSharePair]] = []
    try await withThrowingTaskGroup(of: [FetchedSharePair].self) { group in
      for id in walletIds {
        group.addTask {
          try await self.api.getSharePairs(.backup, walletId: id)
        }
      }

      // Collect results as tasks complete
      for try await sharePairs in group {
        sharePairGroups.append(sharePairs)
      }
    }

    return sharePairGroups.flatMap { $0 }
  }

  public func getNftAssets(_ chainId: String) async throws -> [NftAsset] {
    try await self.api.getNftAssets(chainId)
  }

  public func getSigningShares(_ chainId: String? = nil) async throws -> [FetchedSharePair] {
    guard let client = try await client else {
      throw PortalClassError.clientNotAvailable
    }

    // Handle specific chainId
    if let chainId {
      let namespaceString = chainId.split(separator: ":").map(String.init)[0]
      guard let namespace = PortalNamespace(rawValue: namespaceString) else {
        throw PortalClassError.unsupportedChainId(chainId)
      }
      guard let curve = try await keychain.metadata?.namespaces[namespace] else {
        throw PortalClassError.unsupportedChainId(chainId)
      }
      let wallet = client.wallets.first { wallet in
        wallet.curve == curve
      }
      guard let wallet else {
        throw PortalClassError.noWalletFoundForChain(chainId)
      }

      return try await self.api.getSharePairs(.signing, walletId: wallet.id)
    }

    let walletIds = client.wallets.map(\.id)
    var sharePairGroups: [[FetchedSharePair]] = []
    try await withThrowingTaskGroup(of: [FetchedSharePair].self) { group in
      for id in walletIds {
        group.addTask {
          try await self.api.getSharePairs(.signing, walletId: id)
        }
      }

      // Collect results as tasks complete
      for try await sharePairs in group {
        sharePairGroups.append(sharePairs)
      }
    }

    return sharePairGroups.flatMap { $0 }
  }

  public func getTransactions(
    _ chainId: String,
    limit: Int? = nil,
    offset: Int? = nil,
    order: TransactionOrder? = nil
  ) async throws -> [FetchedTransaction] {
    try await self.api.getTransactions(chainId, limit: limit, offset: offset, order: order)
  }

  public func evaluateTransaction(
    chainId: String,
    transaction: EvaluateTransactionParam,
    operationType: EvaluateTransactionOperationType? = nil
  ) async throws -> BlockaidValidateTrxRes {
    return try await api.evaluateTransaction(
      chainId: chainId,
      transaction: transaction,
      operationType: operationType
    )
  }

  public func buildEip155Transaction(chainId: String, params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse {
    return try await api.buildEip155Transaction(chainId: chainId, params: params)
  }

  public func buildSolanaTransaction(chainId: String, params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse {
    return try await api.buildSolanaTransaction(chainId: chainId, params: params)
  }

  public func getWalletCapabilities() async throws -> WalletCapabilitiesResponse {
    return try await api.getWalletCapabilities()
  }

  /**********************************
   * Deprecated functions
   **********************************/

  @available(*, deprecated, renamed: "evaluateTransaction", message: "Please use evaluateTransaction().")
  public func simulateTransaction(_ chainId: String, from: Any) async throws -> SimulatedTransaction {
    let transaction = AnyCodable(from)
    return try await self.api.simulateTransaction(transaction, withChainId: chainId)
  }

  @available(*, deprecated, renamed: "backupWallet", message: "Please use the async implementation of backupWallet()")
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

  public func ethEstimateGas(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.EstimateGas.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
  }

  public func ethGasPrice(
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.GasPrice.rawValue,
      params: []
    ), completion: completion, connect: nil)
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
    ), completion: completion, connect: nil)
  }

  public func ethSendTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
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
        message
      ]
    ), completion: completion, connect: nil)
  }

  public func ethSignTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SignTransaction.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
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
    ), completion: completion, connect: nil)
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
    ), completion: completion, connect: nil)
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
        address
      ]
    ), completion: completion, connect: nil)
  }

  public func request(
    method: ETHRequestMethods.RawValue,
    params: [Any],
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    let encodedParams = params.map { param in
      AnyCodable(param)
    }
    self.provider.request(payload: ETHRequestPayload(
      method: method,
      params: encodedParams
    ), completion: completion, connect: nil)
  }

  // Solana Methods
  public func sendSol(_ lamports: UInt64, to: String, withChainId chainId: String) async throws -> String {
    // Format Solana to and from addresses
    guard let fromAddress = try await self.addresses[.solana] else {
      throw MpcError.addressNotFound("No solana address found. Have you run generate or recover? Reach out to portal support.")
    }
    let fromPublicKey = try SolanaSwift.PublicKey(string: fromAddress)
    let toPublicKey = try SolanaSwift.PublicKey(string: to)

    // Create the transfer instruction
    let transferInstruction = SystemProgram.transferInstruction(
      from: fromPublicKey,
      to: toPublicKey,
      lamports: lamports
    )

    // Get the most recent blockhash
    let blockhashResponse = try await request(chainId, withMethod: .sol_getLatestBlockhash, andParams: [])
    guard let blockhashResResult = blockhashResponse.result as? SolGetLatestBlockhashResponse else {
      throw PortalSolError.failedToGetLatestBlockhash
    }

    // Initialize the transaction
    let transaction = SolanaSwift.Transaction(
      instructions: [transferInstruction],
      recentBlockhash: blockhashResResult.result.value.blockhash,
      feePayer: fromPublicKey
    )

    // Format the transaction
    let message = try transaction.compileMessage()

    let solanaRequest = self.createSolanaRequest(solanaMessage: message)

    let txResponse = try await request(chainId, withMethod: .sol_signAndSendTransaction, andParams: [solanaRequest])

    guard let txHash = txResponse.result as? String else {
      throw PortalSolError.failedToGetTransactionHash
    }
    return txHash
  }

  public func createSolanaRequest(solanaMessage message: Message) -> SolanaRequest {
    let solanaHeader = SolanaHeader(numRequiredSignatures: message.header.numRequiredSignatures, numReadonlySignedAccounts: message.header.numReadonlySignedAccounts, numReadonlyUnsignedAccounts: message.header.numReadonlyUnsignedAccounts)

    let solanaInstructions = message.instructions.map { SolanaInstruction(from: $0) }
    let accountKeys = message.accountKeys.map(\.base58EncodedString)

    return SolanaRequest(signatures: nil, message: SolanaMessage(accountKeys: accountKeys, header: solanaHeader, recentBlockhash: message.recentBlockhash, instructions: solanaInstructions))
  }

  /// Set the chainId on the instance and update MPC and Provider chainId
  /// - Parameters:
  ///   - to: The chainId to use for processing wallet transactions
  /// - Returns: Void
  @available(*, deprecated, renamed: "REMOVED", message: "The PortalProvider class will be chain agnostic very soon. Please update to the chainId-specific implementations of all Provider helper methods as this function will be removed in the future.")
  public func setChainId(to: Int) throws {
    _ = try self.provider.setChainId(value: to, connect: nil)
  }

  /****************************************
   * Keychain Helper Methods
   ****************************************/

  @available(*, deprecated, renamed: "REMOVED", message: "The PortalKeychain now manages metadata internally based on Portal's server state. This function will be removed in the future.")
  public func deleteAddress() throws {
    try self.keychain.deleteAddress()
  }

  @available(*, deprecated, renamed: "deleteShares", message: "The Portal SDK is now multi-wallet. Please update to the multi-wallet-compatible deleteShares() as this function will be removed in the future.")
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
      self.featureFlags,
      webSocketServer,
      self.autoApprove,
      self.apiHost,
      self.mpcHost,
      self.version
    )
  }

  private static func buildDefaultRpcConfig(_ apiHost: String) -> [String: String] {
    [
      "eip155:1": "https://\(apiHost)/rpc/v1/eip155/1", // Ethereum Mainnet
      "eip155:137": "https://\(apiHost)/rpc/v1/eip155/137", // Polygon Mainnet
      "eip155:8453": "https://\(apiHost)/rpc/v1/eip155/8453", // Base Mainnet
      "eip155:80002": "https://\(apiHost)/rpc/v1/eip155/80002", // Polygon Amoy
      "eip155:84532": "https://\(apiHost)/rpc/v1/eip155/84532", // Base Testnet
      "eip155:11155111": "https://\(apiHost)/rpc/v1/eip155/11155111", // Ethereum Sepolia
      "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "https://\(apiHost)/rpc/v1/solana/5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", // Solana Mainnet
      "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1": "https://\(apiHost)/rpc/v1/solana/EtWTRABZaYq6iMfeYKouRu166VU2xqa1" // Solana Testnet
    ]
  }
}

/*****************************************
 * Supporting Enums & Structs
 *****************************************/

enum PortalClassError: LocalizedError, Equatable {
  case clientNotAvailable
  case noWalletFoundForChain(String)
  case unsupportedChainId(String)
  case cannotCreateWallet
  case cannotRecoverWallet
  case invalidChainId(String)
}

enum PortalProviderError: LocalizedError, Equatable {
  case invalidChainId(_ message: String)
  case invalidRequestParams
  case invalidRpcResponse
  case noAddress
  case noRpcUrlFoundForChainId(_ message: String)
  case noSignatureFoundInSignResult
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

/// The list of Google Drive backup options.
public enum GDriveBackupOption: Equatable {
  case appDataFolder
  case appDataFolderWithFallback
  case gdriveFolder(folderName: String)
}

/// Gateway URL errors.
public enum PortalArgumentError: LocalizedError {
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

public enum PortalSolError: LocalizedError {
  case failedToGetLatestBlockhash
  case failedToGetTransactionHash
}

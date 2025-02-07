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

  /// Registers a storage implementation for a specific backup method.
  ///
  /// This method allows you to provide custom storage implementations for different
  /// backup methods. Use this to customize how backup data is stored and retrieved.
  ///
  /// - Parameters:
  ///   - method: The backup method to register. Supported methods include:
  ///     - `.GoogleDrive`: Google Drive storage
  ///     - `.iCloud`: iCloud storage
  ///     - `.Password`: Password-protected storage
  ///     - `.Passkey`: Passkey authentication storage
  ///     - `.local`: Local storage
  ///     - `.Unknown`: Can be used for custom storage
  ///   - withStorage: A custom implementation of `PortalStorage` protocol that handles
  ///     the storage operations for the specified backup method.
  ///
  /// - Note: Each backup method must have a registered storage implementation
  ///   before it can be used for backup or recovery operations.
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

  /// Sets the presentation anchor for passkey authentication dialogs.
  ///
  /// This method configures where passkey authentication UI components will be presented
  /// in your application's interface.
  ///
  /// - Parameter anchor: The window anchor where passkey authentication UI will be presented.
  ///
  /// - Throws: Errors if the passkey anchor configuration fails.
  ///
  /// - Note: Required to be called before using passkey backup or recovery methods.
  @available(iOS 16, *)
  public func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws {
    try self.mpc.setPasskeyAuthenticationAnchor(anchor)
  }

  /// Configures the passkey authentication settings.
  ///
  /// This method sets up the required configuration for using passkeys as a backup
  /// and authentication method.
  ///
  /// - Parameters:
  ///   - relyingParty: The relying party identifier for WebAuthn/passkey authentication.
  ///     This is typically your application's domain name.
  ///   - webAuthnHost: The WebAuthn host that will handle passkey operations.
  ///     This should match your application's authentication server.
  ///
  /// - Throws: Errors if the passkey configuration fails.
  ///
  /// - Note: Must be called before using passkey backup or recovery methods.
  ///   The relying party should match your application's domain name for security purposes.
  @available(iOS 16, *)
  public func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws {
    try self.mpc.setPasskeyConfiguration(relyingParty: relyingParty, webAuthnHost: webAuthnHost)
  }

  /// Sets the password used for the Password backup method.
  ///
  /// This method configures the password that will be used to encrypt and decrypt
  /// wallet backups when using the `.Password` backup method.
  ///
  /// - Parameter value: The password string to use for backup encryption/decryption.
  ///
  /// - Throws: `MpcError.backupMethodNotRegistered` if the Password backup method
  ///   has not been registered using `registerBackupMethod`.
  ///
  /// - Note: Must be called before using the `.Password` backup method for
  ///   wallet backup or recovery operations.
  public func setPassword(_ value: String) throws {
    try self.mpc.setPassword(value)
  }

  // Wallet management helpers

  /// Creates a backup of the wallet using the specified backup method.
  ///
  /// This method initiates the wallet backup process, which involves encrypting the wallet data
  /// and preparing it for storage. The progress of the backup can be monitored through the optional callback.
  ///
  /// - Parameters:
  ///   - method: The backup method to use. Supported methods include:
  ///     - `.GoogleDrive`: Back up to Google Drive
  ///     - `.iCloud`: Back up to iCloud
  ///     - `.Password`: Back up with password protection
  ///     - `.Passkey`: Back up with passkey authentication
  ///     - `.local`: Back up to local storage
  ///   - usingProgressCallback: Optional callback to track the backup progress.
  ///     The callback receives an `MpcStatus` object containing:
  ///     - `status`: The current operation being performed:
  ///       - `.readingShare`: Reading the share data
  ///       - `.generatingShare`: Creating the backup share
  ///       - `.parsingShare`: Processing the share data
  ///       - `.encryptingShare`: Encrypting the share data
  ///       - `.storingShare`: Saving the encrypted share
  ///       - `.done`: Process completed
  ///     - `done`: Boolean indicating whether the whole operation is complete
  ///
  /// - Returns: A tuple containing:
  ///   - `cipherText`: The encrypted backup data
  ///   - `storageCallback`: A callback function that must be called to complete the backup process
  ///     and update the server state
  ///
  /// - Throws: Various backup method-specific errors if the backup process fails
  ///
  /// - Note: The backup process is not complete until the storageCallback is executed successfully.
  ///   The callback updates the server state and refreshes local metadata.
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

  /// Creates a new wallet and generates addresses for supported chains.
  ///
  /// This method initiates the wallet creation process, which involves multiple steps such as
  /// generating shares, encrypting them, and storing them securely. The progress of these steps
  /// can be monitored through the optional callback.
  ///
  /// - Parameter usingProgressCallback: Optional callback to track the wallet creation progress.
  ///   The callback receives an `MpcStatus` object containing:
  ///   - `status`: The current operation being performed:
  ///     - `.generatingShare`: Creating the initial share
  ///     - `.parsingShare`: Processing the share data
  ///     - `.storingShare`: Saving the encrypted share
  ///     - `.done`: Process completed
  ///   - `done`: Boolean indicating whether the current operation is complete
  ///
  /// - Returns: A `PortalCreateWalletResponse` containing the generated Ethereum and Solana addresses.
  ///
  /// - Throws: `PortalClassError.cannotCreateWallet` if wallet creation fails.
  ///
  /// - Note: The callback is invoked multiple times during the wallet creation process,
  ///   allowing you to update your UI with the current progress.
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

  /// Creates a dedicated Solana wallet during v3 to v4 migration.
  ///
  /// This method is specifically designed for use during SDK version migration and should not be used
  /// in new implementations. For new wallet creation, use `createWallet()` instead.
  ///
  /// - Parameter usingProgressCallback: Optional callback to track the wallet creation progress.
  ///   The callback receives an `MpcStatus` object containing:
  ///   - `status`: The current operation being performed:
  ///     - `.generatingShare`: Creating the initial share
  ///     - `.parsingShare`: Processing the share data
  ///     - `.storingShare`: Saving the encrypted share
  ///     - `.done`: Process completed
  ///   - `done`: Boolean indicating whether the current operation is complete
  ///
  /// - Returns: The generated Solana wallet address as a string.
  ///
  /// - Throws: Various MPC-related errors if wallet generation fails.
  ///
  /// - Important: This function is only for v3 to v4 migration purposes.
  ///   New implementations should use `createWallet()` instead.
  public func createSolanaWallet(usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> String {
    let addresses = try await mpc.generateSolanaWallet(usingProgressCallback: usingProgressCallback)
    return addresses
  }

  /// Extracts the private key from the wallet using a specified backup method.
  ///
  /// This function allows you to retrieve the raw private key from a wallet after proving ownership
  /// through one of the supported backup methods. The private key can then be used to import the wallet
  /// into other applications or wallets.
  ///
  /// - Parameters:
  ///   - method: The backup method to use for authentication. Supported methods include:
  ///     - `.GoogleDrive`: Authenticate using Google Drive backup
  ///     - `.iCloud`: Authenticate using iCloud backup
  ///     - `.Password`: Authenticate using password
  ///     - `.Passkey`: Authenticate using passkey
  ///     - `.local`: Authenticate using local backup
  ///   - withCipherText: Optional cipher text from a previous backup. Required for some backup methods.
  ///   - andOrganizationBackupShare: Optional backup share provided by the organization.
  ///
  /// - Returns: The Ethereum private key as a hexadecimal string.
  ///
  /// - Throws:
  ///   - `MpcError.unableToEjectWallet` if no Ethereum private key is found
  ///   - Various backup method-specific errors if authentication fails
  ///
  /// - Warning: Providing the custodian backup share to the client device puts both MPC shares on a single device,
  ///   removing the multi-party security benefits of MPC. This operation should only be done for users who want
  ///   to move off of MPC and into a single private key. Use `portal.eject()` at your own risk!
  ///
  /// - Note: This method only returns the Ethereum private key. For multi-chain support,
  ///   use `ejectPrivateKeys()` instead.
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

  /// Extracts all private keys from the wallet using a specified backup method.
  ///
  /// This function allows you to retrieve the raw private keys for all supported chains after proving ownership
  /// through one of the supported backup methods. The private keys can then be used to import the wallet
  /// into other applications or wallets.
  ///
  /// - Parameters:
  ///   - method: The backup method to use for authentication. Supported methods include:
  ///     - `.GoogleDrive`: Authenticate using Google Drive backup
  ///     - `.iCloud`: Authenticate using iCloud backup
  ///     - `.Password`: Authenticate using password
  ///     - `.Passkey`: Authenticate using passkey
  ///     - `.local`: Authenticate using local backup
  ///   - withCipherText: Optional cipher text from a previous backup.
  ///   - andOrganizationBackupShare: Optional backup share provided by the organization for EVM chains.
  ///   - andOrganizationSolanaBackupShare: Optional backup share provided by the organization specifically for Solana.
  ///
  /// - Returns: A dictionary mapping `PortalNamespace` to private keys, where:
  ///   - `.eip155` key contains the Ethereum/EVM private key
  ///   - `.solana` key contains the Solana private key
  ///
  /// - Throws: Various backup method-specific errors if authentication fails.
  ///
  /// - Warning: Providing the custodian backup share to the client device puts both MPC shares on a single device,
  ///   removing the multi-party security benefits of MPC. This operation should only be done for users who want
  ///   to move off of MPC and into a single private key. Use `portal.ejectPrivateKeys()` at your own risk!
  ///
  /// - Note: This is the multi-chain version of `eject()`. Use this method when you need to
  ///   retrieve private keys for multiple chains simultaneously.
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

  /// Recovers a wallet using a specified backup method.
  ///
  /// This method initiates the wallet recovery process, which involves retrieving and reconstructing the wallet
  /// from a previous backup. The progress of the recovery steps can be monitored through the optional callback.
  ///
  /// - Parameters:
  ///   - method: The backup method to use for recovery. Supported methods include:
  ///     - `.GoogleDrive`: Recover from Google Drive backup
  ///     - `.iCloud`: Recover from iCloud backup
  ///     - `.Password`: Recover using password
  ///     - `.Passkey`: Recover using passkey
  ///     - `.local`: Recover from local backup
  ///   - withCipherText: Optional cipher text from a previous backup. Required for some backup methods.
  ///   - usingProgressCallback: Optional callback to track the recovery progress.
  ///     The callback receives an `MpcStatus` object containing:
  ///     - `status`: The current operation being performed:
  ///       - `.readingShare`: Reading the stored share
  ///       - `.decryptingShare`: Decrypting the share
  ///       - `.parsingShare`: Parsing the share data
  ///       - `.generatingShare`: Generating the share data
  ///       - `.storingShare`: Saving the recovered share
  ///       - `.done`: Process completed
  ///     - `done`: Boolean indicating whether the whole operation is complete
  ///
  /// - Returns: A `PortalRecoverWalletResponse` containing:
  ///   - `ethereum`: The recovered Ethereum address
  ///   - `solana`: The recovered Solana address, if available
  ///
  /// - Throws:
  ///   - `PortalClassError.cannotRecoverWallet` if the Ethereum address cannot be recovered
  ///   - Various backup method-specific errors if recovery fails
  ///
  /// - Note: The callback is invoked multiple times during the recovery process,
  ///   allowing you to update your UI with the current progress.
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

  /// Generates a Solana wallet and creates backup shares during v3 to v4 migration.
  ///
  /// This method is specifically designed for use during SDK version migration and should not be used
  /// in new implementations. For new wallet creation, use `createWallet()` instead.
  ///
  /// - Parameters:
  ///   - method: The backup method to use for storing the backup shares. Supported methods include:
  ///     - `.GoogleDrive`: Store in Google Drive
  ///     - `.iCloud`: Store in iCloud
  ///     - `.Password`: Protect with password
  ///     - `.Passkey`: Protect with passkey
  ///     - `.local`: Store locally
  ///   - usingProgressCallback: Optional callback to track the wallet creation progress.
  ///     The callback receives an `MpcStatus` object containing:
  ///     - `status`: The current operation being performed:
  ///       - `.generatingShare`: Creating the initial share
  ///       - `.parsingShare`: Processing the share data
  ///       - `.storingShare`: Saving the encrypted share
  ///       - `.readingShare`: Reading the stored share
  ///       - `.encryptingShare`: Encrypting the generated share
  ///       - `.decryptingShare`: Decrypting the share
  ///       - `.done`: Process completed
  ///     - `done`: Boolean indicating whether the whole operation is complete
  ///
  /// - Returns: A tuple containing:
  ///   - `solanaAddress`: The generated Solana wallet address
  ///   - `cipherText`: The encrypted backup data
  ///   - `storageCallback`: A callback function that must be called to complete the backup process
  ///
  /// - Throws: Various MPC-related errors if wallet generation or backup creation fails
  ///
  /// - Important: This function is only for v3 to v4 migration purposes.
  ///   New implementations should use `createWallet()` instead.
  ///
  /// - Note: The backup process is not complete until the storageCallback is executed successfully.
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

  /// Deletes all wallet shares from the device's keychain.
  ///
  /// This method removes all stored wallet shares from the device, effectively
  /// removing access to the wallet from this device. The wallet can be restored
  /// later using backup methods if they were previously configured.
  ///
  /// - Throws: Keychain-related errors if the deletion fails.
  ///
  /// - Warning: After calling this method, you will not be able to sign transactions
  ///   or access the wallet from this device until it is recovered using a backup method.
  public func deleteShares() async throws {
    try await self.keychain.deleteShares()
  }

  /// Retrieves the wallet address for a specific blockchain.
  ///
  /// This method attempts to fetch the wallet address associated with the specified
  /// chain ID from the device's keychain.
  ///
  /// - Parameter forChainId: The chain identifier
  ///
  /// - Returns: The wallet address as a string if found, nil otherwise.
  ///
  /// - Note: This method handles errors internally and returns nil instead of throwing.
  ///   For error handling, use `getAddresses()` instead.
  public func getAddress(_ forChainId: String) async -> String? {
    do {
      let address = try await keychain.getAddress(forChainId)

      return address
    } catch {
      return nil
    }
  }

  /// Retrieves all wallet addresses for supported blockchains.
  ///
  /// This method fetches all wallet addresses stored in the device's keychain across
  /// all supported blockchain namespaces.
  ///
  /// - Returns: A dictionary mapping `PortalNamespace` to optional wallet addresses, where:
  ///   - `.eip155` key contains the Ethereum/EVM address
  ///   - `.solana` key contains the Solana address
  ///
  /// - Throws: Keychain-related errors if the retrieval fails.
  ///
  /// - Note: Unlike `getAddress(_:)`, this method throws errors instead of returning nil
  ///   when access to the keychain fails.
  public func getAddresses() async throws -> [PortalNamespace: String?] {
    try await self.keychain.getAddresses()
  }

  // MARK: - Provider helpers

  /// Emits an event with associated data through the provider.
  ///
  /// This method allows you to emit custom events that can be listened to
  /// using the `on()` and `once()` methods.
  ///
  /// - Parameters:
  ///   - event: The event type to emit. Supported events include:
  ///     - `.ChainChanged`: Emitted when the active blockchain changes
  ///     - `.PortalConnectChainChanged`: Emitted when Portal Connect chain changes
  ///     - `.Connect`: Emitted on successful connection
  ///     - `.ConnectError`: Emitted when a connection error occurs
  ///     - `.Disconnect`: Emitted on disconnection
  ///     - `.PortalSignatureReceived`: Emitted when a signature is received
  ///     - `.PortalSigningApproved`: Emitted when signing is approved
  ///     - `.PortalSigningRejected`: Emitted when signing is rejected
  ///     - `.PortalConnectSigningRequested`: Emitted when Portal Connect requests signing
  ///     - `.PortalSigningRequested`: Emitted when signing is requested
  ///     - `.PortalGetSessionRequest`: Emitted for session requests
  ///     - `.PortalDappSessionRequested`: Emitted when a dApp requests a session
  ///     - `.PortalDappSessionApproved`: Emitted when a dApp session is approved
  ///     - `.PortalDappSessionRejected`: Emitted when a dApp session is rejected
  ///   - data: Any data to be passed along with the event.
  ///
  /// - Note: The emitted event can be captured by any listeners registered
  ///   for that specific event type.
  public func emit(_ event: Events.RawValue, data: Any) {
    _ = self.provider.emit(event: event, data: data)
  }

  /// Registers a callback to handle events emitted by the provider.
  ///
  /// This method sets up a persistent listener for a specific event type. The callback
  /// will be called every time the specified event is emitted.
  ///
  /// - Parameters:
  ///   - event: The event type to listen for. Supported events include:
  ///     - `.ChainChanged`: Triggered when the active blockchain changes
  ///     - `.PortalConnectChainChanged`: Triggered when Portal Connect chain changes
  ///     - `.Connect`: Triggered on successful connection
  ///     - `.ConnectError`: Triggered when a connection error occurs
  ///     - `.Disconnect`: Triggered on disconnection
  ///     - `.PortalSignatureReceived`: Triggered when a signature is received
  ///     - `.PortalSigningApproved`: Triggered when signing is approved
  ///     - `.PortalSigningRejected`: Triggered when signing is rejected
  ///     - `.PortalConnectSigningRequested`: Triggered when Portal Connect requests signing
  ///     - `.PortalSigningRequested`: Triggered when signing is requested
  ///     - `.PortalGetSessionRequest`: Triggered for session requests
  ///     - `.PortalDappSessionRequested`: Triggered when a dApp requests a session
  ///     - `.PortalDappSessionApproved`: Triggered when a dApp session is approved
  ///     - `.PortalDappSessionRejected`: Triggered when a dApp session is rejected
  ///   - callback: The function to be called when the event occurs. The callback receives
  ///     the event data as its parameter.
  ///
  /// - Note: The callback will continue to be called for all future events until explicitly
  ///   removed. For one-time event handling, use `once()` instead.
  public func on(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.on(event: event, callback: callback)
  }

  /// Registers a one-time callback to handle a single occurrence of an event.
  ///
  /// This method sets up a listener that will be triggered only once for the specified event type.
  /// After the event occurs and the callback is executed, the listener is automatically removed.
  ///
  /// - Parameters:
  ///   - event: The event type to listen for. Supported events include:
  ///     - `.ChainChanged`: Triggered when the active blockchain changes
  ///     - `.PortalConnectChainChanged`: Triggered when Portal Connect chain changes
  ///     - `.Connect`: Triggered on successful connection
  ///     - `.ConnectError`: Triggered when a connection error occurs
  ///     - `.Disconnect`: Triggered on disconnection
  ///     - `.PortalSignatureReceived`: Triggered when a signature is received
  ///     - `.PortalSigningApproved`: Triggered when signing is approved
  ///     - `.PortalSigningRejected`: Triggered when signing is rejected
  ///     - `.PortalConnectSigningRequested`: Triggered when Portal Connect requests signing
  ///     - `.PortalSigningRequested`: Triggered when signing is requested
  ///     - `.PortalGetSessionRequest`: Triggered for session requests
  ///     - `.PortalDappSessionRequested`: Triggered when a dApp requests a session
  ///     - `.PortalDappSessionApproved`: Triggered when a dApp session is approved
  ///     - `.PortalDappSessionRejected`: Triggered when a dApp session is rejected
  ///   - callback: The function to be called when the event occurs. The callback receives
  ///     the event data as its parameter.
  ///
  /// - Note: Unlike `on()`, this callback will only be executed once and then automatically
  ///   removed. For persistent event handling, use `on()` instead.
  public func once(event: Events.RawValue, callback: @escaping (Any) -> Void) {
    _ = self.provider.once(event: event, callback: callback)
  }

  /// Sends a blockchain request with the specified method and parameters.
  ///
  /// This method allows you to make RPC calls to various blockchain networks
  /// supported by Portal.
  ///
  /// - Parameters:
  ///   - chainId: The chain identifier.
  ///   - withMethod: The RPC method to call, specified using `PortalRequestMethod`
  ///   - andParams: Optional array of parameters for the RPC method. Must not be nil,
  ///     use an empty array if no parameters are needed.
  ///
  /// - Returns: A `PortalProviderResult` containing the response from the blockchain.
  ///
  /// - Throws:
  ///   - `PortalProviderError.invalidRequestParams` if andParams is nil
  ///   - Other blockchain-specific errors if the request fails
  ///
  /// - Note: Parameters are automatically converted to a format compatible with
  ///   blockchain RPC calls.
  public func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [Any] = []) async throws -> PortalProviderResult {
    let params = andParams.map { param in
      AnyCodable(param)
    }

    return try await self.provider.request(chainId, withMethod: withMethod, andParams: params, connect: nil)
  }

  public func getRpcUrl(forChainId: String) async -> String? {
    return try? self.provider.getRpcUrl(forChainId)
  }

  // MARK: - Wallet lifecycle helpers

  /// Retrieves the list of available backup methods that can be used for wallet recovery.
  ///
  /// This method checks all completed backup share pairs across wallets to determine which
  /// backup methods are available for recovery. The check can be performed for a specific
  /// blockchain or across all supported chains.
  ///
  /// - Parameter forChainId: Optional chain identifier
  ///   If nil, returns backup methods from all wallets.
  ///
  /// - Returns: An array of `BackupMethods` representing completed backups, which may include:
  ///   - `.GoogleDrive`: Google Drive backup
  ///   - `.iCloud`: iCloud backup
  ///   - `.Password`: Password-protected backup
  ///   - `.Passkey`: Passkey backup
  ///   - `.local`: Local backup
  ///
  /// - Throws:
  ///   - `PortalClassError.clientNotAvailable` if the client is not initialized
  ///   - When a specific chainId is provided:
  ///     - `PortalClassError.unsupportedChainId` if the chain's namespace is not supported
  ///     - `PortalClassError.noWalletFoundForChain` if no wallet exists for the specified chain
  ///
  /// - Note: The method only returns backup methods where the corresponding backup share pairs
  ///   have a status of `.completed`. Methods with incomplete or pending backups are excluded.
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

  /// Checks whether a wallet exists with completed signing shares.
  ///
  /// This method verifies the existence of a wallet by checking for completed signing shares.
  /// The check can be performed for a specific blockchain or across all supported chains.
  ///
  /// - Parameter forChainId: Optional chain identifier.
  ///   If nil, checks for wallets across all chains.
  ///
  /// - Returns: A boolean value indicating whether a wallet exists:
  ///   - When chainId is provided:
  ///     - Returns true if a wallet exists for the specified chain and has at least one completed signing share
  ///     - Returns false if no wallet exists or if no signing shares are completed
  ///   - When chainId is nil:
  ///     - Returns true if any wallet exists and has at least one completed signing share
  ///     - Returns false if no wallets exist or if no signing shares are completed
  ///
  /// - Throws: `PortalClassError.clientNotAvailable` if the client is not initialized
  ///
  /// - Note: The method checks for the presence of signing shares with a status of `.completed`.
  ///   Incomplete or pending signing shares are not considered when determining wallet existence.
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

  /// Checks whether a wallet has completed backups.
  ///
  /// This method verifies if backup shares have been successfully created and stored.
  /// The check can be performed for a specific blockchain or across all supported chains.
  ///
  /// - Parameter forChainId: Optional chain identifier.
  ///   If nil, checks backup status across all chains.
  ///
  /// - Returns: A boolean value indicating whether the wallet is backed up:
  ///   - When forChainId is provided:
  ///     - Returns true if a wallet exists for the specified chain and has at least one completed backup share
  ///     - Returns false if no wallet exists or if no backup shares are completed
  ///   - When forChainId is nil:
  ///     - Returns true if any wallet exists and has at least one completed backup share
  ///     - Returns false if no wallets exist or if no backup shares are completed
  ///
  /// - Throws: `PortalClassError.clientNotAvailable` if the client is not initialized
  ///
  /// - Note: The method only considers backup shares with a status of `.completed`.
  ///   Incomplete or pending backups are not considered when determining backup status.
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

  /// Checks whether wallet shares are present in the device's keychain.
  ///
  /// This method verifies if the signing shares required for wallet operations are stored
  /// in the device's local keychain. The check can be performed for a specific blockchain
  /// or across all supported chains.
  ///
  /// - Parameter forChainId: Optional chain identifier.
  ///   If nil, checks for any valid shares across all chains.
  ///
  /// - Returns: A boolean value indicating whether wallet shares exist on the device:
  ///   - When forChainId is provided:
  ///     - Returns true if shares exist for the specified chain
  ///     - Returns false if no shares are found for the chain
  ///   - When forChainId is nil:
  ///     - Returns true if any valid share exists (has non-empty ID)
  ///     - Returns false if no valid shares are found
  ///
  /// - Throws:
  ///   - `PortalClassError.invalidChainId` if the provided chain ID format is invalid
  ///   - `PortalClassError.unsupportedChainId` if the chain's namespace is not supported
  ///   - Various keychain-related errors if share retrieval fails
  ///
  /// - Note: This method checks for the physical presence of shares on the device,
  ///   regardless of their status. Use `doesWalletExist()` to verify if a wallet
  ///   is fully functional with completed shares.
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

  /// Checks whether the wallet can be recovered using any available backup methods.
  ///
  /// This method verifies if there are any completed backup methods that could be used
  /// to recover the wallet. The check can be performed for a specific blockchain or
  /// across all supported chains.
  ///
  /// - Parameter forChainId: Optional CAIP-2 chain identifier (e.g., "eip155:1" for Ethereum mainnet,
  ///   "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp" for Solana mainnet).
  ///   If nil, checks recovery options across all chains.
  ///
  /// - Returns: A boolean value indicating whether the wallet can be recovered:
  ///   - Returns true if at least one completed backup method is available
  ///   - Returns false if no completed backup methods are found
  ///
  /// - Throws:
  ///   - `PortalClassError.clientNotAvailable` if the client is not initialized
  ///   - `PortalClassError.unsupportedChainId` if the chain's namespace is not supported
  ///   - `PortalClassError.noWalletFoundForChain` if no wallet exists for the specified chain
  ///
  /// - Note: This method uses `availableRecoveryMethods()` internally to determine if
  ///   any completed backup methods exist.
  public func isWalletRecoverable(_ forChainId: String? = nil) async throws -> Bool {
    let availableRecoveryMethods = try await availableRecoveryMethods(forChainId)

    return availableRecoveryMethods.count > 0
  }

  // MARK: - Api helpers

  /// Retrieves token balances for the specified blockchain.
  ///
  /// This method fetches all token balances associated with the wallet on the
  /// specified blockchain network.
  ///
  /// - Parameter chainId: The chain identifier.
  ///
  /// - Returns: An array of `FetchedBalance` objects containing token balance information
  ///
  /// - Throws: Various API-related errors if the balance retrieval fails
  public func getBalances(_ chainId: String) async throws -> [FetchedBalance] {
    try await self.api.getBalances(chainId)
  }

  /// Retrieves a collection of assets (tokens and NFTs) for the specified blockchain.
  ///
  /// This method fetches all available assets associated with the wallet on the
  /// specified blockchain network, including both fungible tokens and NFTs.
  ///
  /// - Parameter chainId: The chain identifier.
  ///
  /// - Returns: An `AssetsResponse` object containing collections of both fungible
  ///   and non-fungible tokens
  ///
  /// - Throws: Various API-related errors if the asset retrieval fails
  ///
  /// - Note: For token balances only, use `getBalances(_:)`. For NFTs only, use `getNftAssets(_:)`.
  public func getAssets(_ chainId: String) async throws -> AssetsResponse {
    try await self.api.getAssets(chainId)
  }

  /// Retrieves backup share pairs for the wallet.
  ///
  /// This method fetches all backup share pairs, which represent the backup state of the wallet.
  /// The retrieval can be performed for a specific blockchain or across all supported chains.
  ///
  /// - Parameter chainId: Optional chain identifier.
  ///   If nil, retrieves backup shares for all chains.
  ///
  /// - Returns: An array of `FetchedSharePair` objects containing backup share information.
  ///   When no chainId is provided, returns a flattened array of backup shares from all wallets.
  ///
  /// - Throws:
  ///   - `PortalClassError.clientNotAvailable` if the client is not initialized
  ///   - When a specific chainId is provided:
  ///     - `PortalClassError.unsupportedChainId` if the chain's namespace is not supported
  ///     - `PortalClassError.noWalletFoundForChain` if no wallet exists for the specified chain
  ///   - Various API-related errors if share retrieval fails
  ///
  /// - Note: The method uses concurrent tasks to fetch shares from multiple wallets
  ///   when no specific chainId is provided, improving performance for multi-chain wallets.
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

  /// Retrieves NFT assets for the specified blockchain.
  ///
  /// This method fetches all NFTs (Non-Fungible Tokens) owned by the wallet on the
  /// specified blockchain network.
  ///
  /// - Parameter chainId: The chain identifier.
  ///
  /// - Returns: An array of `NftAsset` objects containing NFT information
  ///
  /// - Throws: Various API-related errors if the NFT retrieval fails
  ///
  /// - Note: For fungible token balances, use `getBalances(_:)` instead.
  ///   For both NFTs and tokens, use `getAssets(_:)`.
  public func getNftAssets(_ chainId: String) async throws -> [NftAsset] {
    try await self.api.getNftAssets(chainId)
  }

  /// Retrieves signing share pairs for the wallet.
  ///
  /// This method fetches all signing share pairs, which are used for transaction signing.
  /// The retrieval can be performed for a specific blockchain or across all supported chains.
  ///
  /// - Parameter chainId: Optional chain identifier.
  ///   If nil, retrieves signing shares for all chains.
  ///
  /// - Returns: An array of `FetchedSharePair` objects containing signing share information.
  ///   When no chainId is provided, returns a flattened array of signing shares from all wallets.
  ///
  /// - Throws:
  ///   - `PortalClassError.clientNotAvailable` if the client is not initialized
  ///   - When a specific chainId is provided:
  ///     - `PortalClassError.unsupportedChainId` if the chain's namespace is not supported
  ///     - `PortalClassError.noWalletFoundForChain` if no wallet exists for the specified chain
  ///   - Various API-related errors if share retrieval fails
  ///
  /// - Note: The method uses concurrent tasks to fetch shares from multiple wallets
  ///   when no specific chainId is provided, improving performance for multi-chain wallets.
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

  /// Retrieves transaction history for the specified blockchain.
  ///
  /// This method fetches a list of transactions associated with the wallet on the
  /// specified blockchain network. The results can be paginated and ordered.
  ///
  /// - Parameters:
  ///   - chainId: The chain identifier.
  ///   - limit: Optional maximum number of transactions to return.
  ///     If nil, returns all transactions.
  ///   - offset: Optional number of transactions to skip for pagination.
  ///     If nil, starts from the beginning.
  ///   - order: Optional `TransactionOrder` to specify the sort order of transactions `ASC` or `DESC`.
  ///
  /// - Returns: An array of `FetchedTransaction` objects containing transaction history
  ///
  /// - Throws: Various API-related errors if the transaction retrieval fails
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

  /// Builds an EIP-155 compliant transaction for Ethereum-compatible chains.
  ///
  /// This method constructs a transaction object following the EIP-155 specification,
  /// which adds replay protection to Ethereum transactions.
  ///
  /// - Parameters:
  ///   - chainId: The chain identifier.
  ///   - params: Transaction parameters specified in `BuildTransactionParam`
  ///
  /// - Returns: A `BuildEip115TransactionResponse` containing the constructed transaction
  ///
  /// - Throws: Various API-related errors if the transaction building fails
  ///
  /// - Note: Only valid for EVM-compatible chains. For Solana transactions,
  ///   use `buildSolanaTransaction(_:params:)` instead.
  public func buildEip155Transaction(chainId: String, params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse {
    return try await api.buildEip155Transaction(chainId: chainId, params: params)
  }

  /// Builds a Solana transaction.
  ///
  /// This method constructs a transaction object compatible with the Solana blockchain.
  ///
  /// - Parameters:
  ///   - chainId: The chain identifier.
  ///   - params: Transaction parameters specified in `BuildTransactionParam`
  ///
  /// - Returns: A `BuildSolanaTransactionResponse` containing the constructed transaction
  ///
  /// - Throws: Various API-related errors if the transaction building fails
  ///
  /// - Note: Only valid for Solana chains. For EVM-compatible chains,
  ///   use `buildEip155Transaction(_:params:)` instead.
  public func buildSolanaTransaction(chainId: String, params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse {
    return try await api.buildSolanaTransaction(chainId: chainId, params: params)
  }

  /// Retrieves the capabilities of the current wallet.
  ///
  /// This method fetches information about what features and operations are
  /// supported by the wallet, including supported chains and operations.
  ///
  /// - Returns: A `WalletCapabilitiesResponse` containing information about
  ///   supported wallet features and capabilities
  ///
  /// - Throws: Various API-related errors if the capabilities retrieval fails
  public func getWalletCapabilities() async throws -> WalletCapabilitiesResponse {
    return try await api.getWalletCapabilities()
  }

  /// Requests testnet assets (tokens/coins) for development and testing purposes.
  ///
  /// This method allows developers to receive test assets on supported testnet chains
  /// to facilitate development and testing of their applications.
  ///
  /// - Parameters:
  ///   - chainId: The CAIP-2 chain identifier (e.g., "eip155:11155111" for Ethereum Sepolia)
  ///   - params: Request parameters including:
  ///     - token: The token symbol to receive (e.g., "ETH" for Ethereum Sepolia)
  ///     - amount: The amount of tokens to request as a string (e.g. "0.01" is 0.01 Test ETH)
  ///
  /// - Returns: A `FundResponse` containing the transaction details and status
  ///
  /// - Throws: Various API-related errors if the funding request fails
  ///
  /// - Note: This method only works on testnet chains. Attempting to request
  ///   assets on mainnet chains will result in an error.
  public func receiveTestnetAsset(chainId: String, params: FundParams) async throws -> FundResponse {
    return try await api.fund(chainId: chainId, params: params)
  }

  /// Sends an asset (token) to a specified address.
  ///
  /// This method handles sending both native and token assets on supported chains. It automatically
  /// detects the chain type (EVM or Solana) and uses the appropriate transaction building and sending methods.
  ///
  /// - Parameters:
  ///   - chainId: The CAIP-2 chain identifier (e.g., "eip155:1" for Ethereum mainnet,
  ///     "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp" for Solana mainnet)
  ///   - params: Transaction parameters including:
  ///     - to: The recipient's address
  ///     - token: The token to send (use "NATIVE" for chain's native token)
  ///     - amount: The amount to send as a string
  ///
  /// - Returns: A SendAssetResponse containing:
  ///   - data: Transaction data including hash and explorer URL if successful
  ///   - metadata: Additional transaction metadata
  ///   - error: Error information if the transaction failed
  ///
  /// - Throws: Various errors if transaction building or sending fails
  ///
  /// - Note: Chain identifiers must follow CAIP-2 format (namespace:reference)
  public func sendAsset(chainId: String, params: SendAssetParams) async throws -> SendAssetResponse {
    // Validate required parameters
    guard !params.to.isEmpty, !params.token.isEmpty, !params.amount.isEmpty else {
      throw PortalClassError.invalidParameters("Missing required parameters: to, token, or amount")
    }

    // Get chain namespace
    let chainParts = chainId.split(separator: ":")
    guard chainParts.count == 2 else {
      throw PortalClassError.invalidChainId(chainId)
    }

    let namespace = PortalNamespace(rawValue: String(chainParts[0]))
    // Build the appropriate transaction based on chain type
    let transactionParam = BuildTransactionParam(
      to: params.to,
      token: params.token,
      amount: params.amount
    )

    switch namespace {
    case .eip155:
      // Build and send EVM transaction
      let transactionResponse = try await buildEip155Transaction(chainId: chainId, params: transactionParam)

      // Send the transaction using eth_sendTransaction
      let sendResponse = try await request(chainId, withMethod: .eth_sendTransaction, andParams: [transactionResponse.transaction])

      guard let txHash = sendResponse.result as? String else {
        throw PortalClassError.invalidResponseTypeForRequest
      }

      // Construct and return response
      return SendAssetResponse(txHash: txHash)

    case .solana:
      // Build and send Solana transaction
      let transactionResponse = try await buildSolanaTransaction(chainId: chainId, params: transactionParam)

      // Send the transaction using sol_signAndSendTransaction
      let sendResponse = try await request(chainId, withMethod: .sol_signAndSendTransaction, andParams: [transactionResponse.transaction])

      guard let txHash = sendResponse.result as? String else {
        throw PortalClassError.invalidResponseTypeForRequest
      }

      // Construct and return response
      return SendAssetResponse(txHash: txHash)

    default:
      throw PortalClassError.unsupportedChainId(chainId)
    }
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

  @available(*, deprecated, message: "Use request(_:withMethod:andParams:) with a default value for andParams instead.")
  public func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [Any]?) async throws -> PortalProviderResult {
    guard let andParams = andParams else {
      throw PortalProviderError.invalidRequestParams
    }

    let params = andParams.map { param in
      AnyCodable(param)
    }

    return try await self.request(chainId, withMethod: withMethod, andParams: andParams)
  }

  /// Sends a blockchain request with the specified method string and parameters.
  ///
  /// This method is an alternative version of `request(_:withMethod:andParams:)` that
  /// accepts a string method name instead of a `PortalRequestMethod` enum value.
  ///
  /// - Parameters:
  ///   - chainId: The chain identifier
  ///   - withMethod: The RPC method name as a string
  ///   - andParams: Array of parameters for the RPC method
  ///
  /// - Returns: A `PortalProviderResult` containing the response from the blockchain.
  ///
  /// - Throws:
  ///   - `PortalProviderError.unsupportedRequestMethod` if the method string is not a valid
  ///     `PortalRequestMethod`
  ///   - Other errors from the underlying `request(_:withMethod:andParams:)` call
  ///
  /// - Note: This is a convenience wrapper that converts the method string to a
  ///   `PortalRequestMethod` enum value before making the request.
  @available(*, deprecated, message: "Use request(_:withMethod:andParams:) with PortalRequestMethod instead of String.")
  public func request(_ chainId: String, withMethod: String, andParams: [Any]) async throws -> PortalProviderResult {
    guard let method = PortalRequestMethod(rawValue: withMethod) else {
      throw PortalProviderError.unsupportedRequestMethod(withMethod)
    }

    return try await self.request(chainId, withMethod: method, andParams: andParams)
  }

  /// Provisions a wallet using backup data.
  ///
  /// This method recovers a wallet using provided backup data and configures it
  /// for use on this device.
  ///
  /// - Parameters:
  ///   - cipherText: The encrypted backup data used for wallet recovery
  ///   - method: The backup method used to store the wallet
  ///   - backupConfigs: Optional configuration for the backup method
  ///   - completion: Callback that receives the Result of the operation
  ///   - progress: Optional callback to track the provisioning progress.
  ///     The callback receives an `MpcStatus` object containing:
  ///     - `status`: The current operation being performed:
  ///       - `.readingShare`: Reading the stored share
  ///       - `.decryptingShare`: Decrypting the share
  ///       - `.parsingShare`: Parsing the share data
  ///       - `.generatingShare`: Generating the share data
  ///       - `.storingShare`: Saving the recovered share
  ///       - `.done`: Process completed
  ///     - `done`: Boolean indicating whether the whole operation is complete
  public func provisionWallet(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.recoverWallet(cipherText: cipherText, method: method, backupConfigs: backupConfigs, completion: completion, progress: progress)
  }

  /// Estimates the gas required for an Ethereum transaction.
  ///
  /// This method calculates the estimated gas units needed to execute the
  /// specified Ethereum transaction.
  ///
  /// - Parameters:
  ///   - transaction: The Ethereum transaction parameters
  ///   - completion: Callback that receives the gas estimation result.
  ///     The callback is invoked with:
  ///     - A successful `RequestCompletionResult` containing the estimated gas amount
  ///     - An error if the estimation fails
  ///
  /// - Note: This is a convenience wrapper around the `eth_estimateGas` RPC method.
  ///   The estimate may vary from the actual gas used in the final transaction.
  public func ethEstimateGas(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.EstimateGas.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
  }

  /// Retrieves the current gas price on the Ethereum network.
  ///
  /// This method fetches the current gas price in wei from the Ethereum network.
  ///
  /// - Parameter completion: Callback that receives the gas price result.
  ///   The callback is invoked with:
  ///   - A successful `RequestCompletionResult` containing the current gas price in wei
  ///   - An error if the price fetch fails
  ///
  /// - Note: This is a convenience wrapper around the `eth_gasPrice` RPC method.
  ///   Gas prices can be volatile and may change rapidly.
  public func ethGasPrice(
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.GasPrice.rawValue,
      params: []
    ), completion: completion, connect: nil)
  }

  /// Retrieves the ETH balance for the current wallet address.
  ///
  /// This method fetches the native ETH balance for the wallet's Ethereum address.
  ///
  /// - Parameter completion: Callback that receives the balance result.
  ///   The callback is invoked with:
  ///   - A successful `RequestCompletionResult` containing the balance in wei
  ///   - An error if the balance fetch fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_getBalance` RPC method
  ///   - The balance is returned for the latest block
  ///   - Requires the wallet address to be available, otherwise returns
  ///     `PortalProviderError.noAddress`
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

  /// Sends an Ethereum transaction to the network.
  ///
  /// This method broadcasts a signed Ethereum transaction to the network
  /// for processing.
  ///
  /// - Parameters:
  ///   - transaction: The Ethereum transaction parameters to be sent
  ///   - completion: Callback that receives the transaction result.
  ///     The callback is invoked with:
  ///     - A successful `TransactionCompletionResult` containing the transaction hash
  ///     - An error if the transaction fails to send
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_sendTransaction` RPC method
  ///   - The transaction is automatically signed before being sent
  public func ethSendTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
  }

  /// Signs an Ethereum message using the wallet's private key.
  ///
  /// This method produces an Ethereum-specific signature for the provided message
  /// using the current wallet address.
  ///
  /// - Parameters:
  ///   - message: The message to be signed
  ///   - completion: Callback that receives the signing result.
  ///     The callback is invoked with:
  ///     - A successful `RequestCompletionResult` containing the signature
  ///     - An error if the signing fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_sign` RPC method
  ///   - Requires the wallet address to be available, otherwise returns
  ///     `PortalProviderError.noAddress`
  ///   - Signs messages using the Ethereum personal message signing format
  ///     which adds a prefix to prevent signing arbitrary transactions
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

  /// Signs an Ethereum transaction without broadcasting it to the network.
  ///
  /// This method creates a cryptographic signature for an Ethereum transaction
  /// using the wallet's private key, but does not send it to the network.
  ///
  /// - Parameters:
  ///   - transaction: The Ethereum transaction parameters to be signed
  ///   - completion: Callback that receives the signing result.
  ///     The callback is invoked with:
  ///     - A successful `TransactionCompletionResult` containing the signed transaction
  ///     - An error if the signing fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_signTransaction` RPC method
  ///   - Unlike `ethSendTransaction`, this method only signs the transaction and
  ///     returns the signed transaction data without broadcasting it
  ///   - The signed transaction can later be broadcast using `ethSendTransaction`
  public func ethSignTransaction(
    transaction: ETHTransactionParam,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
    self.provider.request(payload: ETHTransactionPayload(
      method: ETHRequestMethods.SignTransaction.rawValue,
      params: [transaction]
    ), completion: completion, connect: nil)
  }

  /// Signs typed data according to EIP-712 (v3) specification.
  ///
  /// This method signs structured data following the EIP-712 v3 standard,
  /// providing a more secure way to sign structured data in Ethereum applications.
  ///
  /// - Parameters:
  ///   - message: JSON-encoded string of the typed data to be signed,
  ///     must follow the EIP-712 schema
  ///   - completion: Callback that receives the signing result.
  ///     The callback is invoked with:
  ///     - A successful `RequestCompletionResult` containing the signature
  ///     - An error if the signing fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_signTypedData_v3` RPC method
  ///   - Requires the wallet address to be available, otherwise returns
  ///     `PortalProviderError.noAddress`
  ///   - The message must be a properly formatted EIP-712 typed data structure
  ///   - For the latest version of typed data signing, consider using
  ///     `ethSignTypedData` (v4) instead
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

  /// Signs typed data according to EIP-712 (v4) specification.
  ///
  /// This method signs structured data following the latest EIP-712 v4 standard,
  /// providing the most secure and feature-complete way to sign structured data
  /// in Ethereum applications.
  ///
  /// - Parameters:
  ///   - message: JSON-encoded string of the typed data to be signed,
  ///     must follow the EIP-712 schema
  ///   - completion: Callback that receives the signing result.
  ///     The callback is invoked with:
  ///     - A successful `RequestCompletionResult` containing the signature
  ///     - An error if the signing fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `eth_signTypedData_v4` RPC method
  ///   - Requires the wallet address to be available, otherwise returns
  ///     `PortalProviderError.noAddress`
  ///   - The message must be a properly formatted EIP-712 typed data structure
  ///   - This is the recommended method for signing typed data, as it includes
  ///     all improvements and security features from previous versions
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

  /// Signs a message using the Ethereum personal message format.
  ///
  /// This method signs a message using the personal_sign format, which adds
  /// a prefix to prevent malicious DApps from tricking users into signing
  /// transactions.
  ///
  /// - Parameters:
  ///   - message: The message to be signed
  ///   - completion: Callback that receives the signing result.
  ///     The callback is invoked with:
  ///     - A successful `RequestCompletionResult` containing the signature
  ///     - An error if the signing fails
  ///
  /// - Note:
  ///   - This is a convenience wrapper around the `personal_sign` RPC method
  ///   - Requires the wallet address to be available, otherwise returns
  ///     `PortalProviderError.noAddress`
  ///   - The message is automatically prefixed with "\x19Ethereum Signed Message:\n"
  ///     before signing
  ///   - This method is commonly used by DApps for user authentication
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

  // MARK: - Solana Methods

  /// Sends SOL tokens to a specified Solana address.
  ///
  /// This method constructs and sends a Solana transfer transaction for sending SOL
  /// tokens to another address.
  ///
  /// - Parameters:
  ///   - lamports: Amount of lamports to send (1 SOL = 1,000,000,000 lamports)
  ///   - to: The recipient's Solana address
  ///   - withChainId: The CAIP-2 chain identifier (e.g.,
  ///     "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp" for Solana mainnet)
  ///
  /// - Returns: The transaction hash (signature) as a string
  ///
  /// - Throws:
  ///   - `MpcError.addressNotFound` if no Solana address is found for the wallet
  ///   - `PortalSolError.failedToGetLatestBlockhash` if unable to get the latest blockhash
  ///   - `PortalSolError.failedToGetTransactionHash` if transaction signing/sending fails
  ///   - Errors from `SolanaSwift.PublicKey` initialization if addresses are invalid
  ///
  /// - Note:
  ///   - The wallet must have a Solana address. Run generate or recover if needed.
  ///   - The transaction is automatically signed and sent to the network
  ///   - The fee is paid by the sender's address
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

  /// Creates a Solana request object from a compiled message.
  ///
  /// This method transforms a Solana message into a format suitable for
  /// signing and sending to the network.
  ///
  /// - Parameter message: The compiled Solana message containing transaction details
  ///
  /// - Returns: A `SolanaRequest` object containing:
  ///   - Header information about required signatures
  ///   - Base58-encoded account keys
  ///   - Recent blockhash
  ///   - Transaction instructions
  ///
  /// - Note: This is an internal helper method used by `sendSol` to prepare
  ///   transactions for signing and sending.
  ///   The signatures field is intentionally set to nil as they will be
  ///   added during the signing process.
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

  /// Creates an instance of Portal Connect for remote transaction signing.
  ///
  /// This method instantiates a Portal Connect object that enables remote
  /// transaction signing capabilities using WebSocket communication.
  ///
  /// - Parameter webSocketServer: The WebSocket server hostname to connect to.
  ///   Defaults to "connect.portalhq.io"
  ///
  /// - Returns: A configured `PortalConnect` instance
  ///
  /// - Throws: Various initialization errors if Portal Connect setup fails
  ///
  /// - Note:
  ///   - Uses the current Portal instance's configuration for setup
  ///   - If no chainId is set, defaults to Sepolia testnet (11155111)
  ///   - The WebSocket server must be accessible from the client device
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
      "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1": "https://\(apiHost)/rpc/v1/solana/EtWTRABZaYq6iMfeYKouRu166VU2xqa1" // Solana Devnet
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
  case invalidResponseTypeForRequest
  case invalidParameters(String)
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

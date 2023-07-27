//
//  Portal.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

/// The main Portal class.
public class Portal {
  public var address: String? {
    do {
      return try self.keychain.getAddress()
    } catch {
      return nil
    }
  }

  public var chainId: Int {
    return self.provider.chainId
  }

  public let api: PortalApi
  public let apiKey: String
  public let autoApprove: Bool
  public let backup: BackupOptions
  public var client: Client?
  public let gatewayConfig: [Int: String]
  public let keychain: PortalKeychain
  public let mpc: PortalMpc
  public let provider: PortalProvider

  private let apiHost: String
  private let mpcHost: String
  private let version: String

  /// Create a Portal instance.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can obtain this through Portal's REST API.
  ///   - backup: The backup options to use.
  ///   - chainId: The chainId you want the provider to use.
  ///   - keychain: An instance of PortalKeychain.
  ///   - gatewayConfig: A dictionary of chainIds (keys) and gateway URLs (values).
  ///   - isSimulator: (optional) Whether you are testing on the iOS simulator or not.
  ///   - address: (optional) An address.
  ///   - apiHost: (optional) Portal's API host.
  ///   - autoApprove: (optional) Auto-approve transactions.
  ///   - mpcHost: (optional) Portal's MPC API host.
  public init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychain,
    gatewayConfig: [Int: String],
    // Optional
    isSimulator: Bool = false,
    version: String = "v4",
    autoApprove: Bool = false,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io"
  ) throws {
    // Basic setup
    self.apiHost = apiHost
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.backup = backup
    self.gatewayConfig = gatewayConfig
    self.client = try Portal.getClient(apiHost, apiKey)
    keychain.clientId = self.client?.id
    self.keychain = keychain
    self.mpcHost = mpcHost
    self.version = version

    if version != "v4" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v4' is currently supported.")
    }

    // Initialize the PortalProvider
    self.provider = try PortalProvider(
      apiKey: apiKey,
      chainId: chainId,
      gatewayConfig: gatewayConfig,
      keychain: keychain,
      autoApprove: autoApprove,
      apiHost: apiHost,
      mpcHost: mpcHost,
      version: version
    )

    // Initialize the Portal API
    let api = PortalApi(apiKey: apiKey, apiHost: apiHost, provider: provider)
    self.api = api

    // Ensure storage adapters have access to the Portal API
    if backup.gdrive != nil {
      backup.gdrive?.api = api
    }
    if backup.icloud != nil {
      backup.icloud?.api = api
    }

    // Initialize Mpc
    self.mpc = PortalMpc(
      apiKey: apiKey,
      api: api,
      keychain: keychain,
      storage: backup,
      isSimulator: isSimulator,
      host: mpcHost,
      version: version
    )
  }

  /**********************************
   * Wallet Helper Methods
   **********************************/

  public func backupWallet(
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.backup(method: method, completion: completion, progress: progress)
  }

  public func createWallet(
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.generate(completion: completion, progress: progress)
  }

  public func recoverWallet(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    self.mpc.recover(cipherText: cipherText, method: method, completion: completion, progress: progress)
  }

  /**********************************
   * Provider Helper Methods
   **********************************/

  public func emit(_ event: Events.RawValue, data: Any) {
    _ = self.provider.emit(event: event, data: data)
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

  public func ethSignTypedData(
    transaction: String,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) {
    guard let address = provider.address else {
      completion(Result(error: PortalProviderError.noAddress))
      return
    }

    self.provider.request(payload: ETHRequestPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [address, transaction]
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
    self.provider.request(payload: ETHRequestPayload(
      method: method,
      params: params
    ), completion: completion)
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
    return try PortalConnect(
      self.apiKey,
      self.provider.chainId,
      self.keychain,
      self.gatewayConfig,
      webSocketServer,
      self.autoApprove,
      self.apiHost,
      self.mpcHost,
      self.version
    )
  }

  /****************************************
   * Private Methods
   ****************************************/

  private static func getClient(_ apiHost: String, _ apiKey: String) throws -> Client {
    // Create URL.
    let apiUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"

    // Call the MPC service to retrieve the client.
    let response = MobileGetMe("\(apiUrl)/api/v1/clients/me", apiKey)

    // Parse the client.
    let jsonData = response.data(using: .utf8)!
    let clientResult: ClientResult = try JSONDecoder().decode(ClientResult.self, from: jsonData)

    guard clientResult.error.code == 0 else {
      throw PortalMpcError(clientResult.error)
    }

    guard let client = clientResult.data else {
      throw PortalArgumentError.unableToGetClient
    }

    return client
  }
}

/*****************************************
 * Supporting Enums & Structs
 *****************************************/

enum PortalProviderError: Error {
  case noAddress
}

/// The list of backup methods for PortalSwift.
public enum BackupMethods: String {
  case GoogleDrive = "gdrive"
  case iCloud = "icloud"
  case local
}

/// A struct with the backup options (gdrive and/or icloud) initialized.
public struct BackupOptions {
  public var gdrive: GDriveStorage?
  public var icloud: ICloudStorage?
  public var local: Storage?

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  public init(gdrive: GDriveStorage) {
    self.gdrive = gdrive
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(icloud: ICloudStorage) {
    self.icloud = icloud
  }

  public init(local: Storage) {
    self.local = local
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(gdrive: GDriveStorage, icloud: ICloudStorage) {
    self.gdrive = gdrive
    self.icloud = icloud
  }

  subscript(key: String) -> Any? {
    switch key {
    case BackupMethods.GoogleDrive.rawValue:
      return self.gdrive
    case BackupMethods.iCloud.rawValue:
      return self.icloud
    case BackupMethods.local.rawValue:
      return self.local
    default:
      return nil
    }
  }
}

/// Gateway URL errors.
public enum PortalArgumentError: Error {
  case invalidGatewayConfig
  case noGatewayConfigForChain(chainId: Int)
  case versionNoLongerSupported(message: String)
  case unableToGetClient
}

//
//  Portal.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

public protocol PortalDelegate {
  func didReceiveSigningRequest(_ data: Any)
  func didReceiveSigningResult(_ data: RequestCompletionResult)
}

extension PortalDelegate {
  func didReceiveSigningResult(_ data: RequestCompletionResult) {
    print("[Portal] Received signing result with no delegate method found. \(data)")
  }
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
      return gdrive
    case BackupMethods.iCloud.rawValue:
      return icloud
    case BackupMethods.local.rawValue:
      return local
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

/// Determines the appropriate Gateway URL to use for the current chainId
/// - Parameters:
///   - gatewayConfig: A dictionary of chainIds (keys) and gateway URLs (values).
///   - chainId: The chainId we should use, such as 5 (Goerli).
/// - Throws: PortalArgumentError.noGatewayConfigForChain with the chainId.
/// - Returns: The URL to be used for Gateway requests.
private func getGatewayUrl(gatewayConfig: [Int: String], chainId: Int) throws -> String {
  if gatewayConfig[chainId] == nil {
    throw PortalArgumentError.noGatewayConfigForChain(chainId: chainId)
  }

  return gatewayConfig[chainId]!
}

/// The main Portal class.
public class Portal {
  public var address: String = ""
  public var api: PortalApi
  public var apiHost: String
  public var apiKey: String
  public var backup: BackupOptions
  public var client: Client?
  public var chainId: Int
  public var autoApprove: Bool
  public var isSimulator: Bool
  public var keychain: PortalKeychain
  public var mpc: PortalMpc
  public var provider: PortalProvider
  public var gatewayConfig: [Int: String]
  public var version: String

  private var _delegate: PortalDelegate?
  public var delegate: PortalDelegate? {
    get {
      return _delegate
    }

    set(delegate) {
      _delegate = delegate
      provider.delegate = delegate
    }
  }

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
    mpcHost: String = "mpc.portalhq.io",
    address: String = ""
  ) throws {
    // Basic setup
    self.apiKey = apiKey
    self.backup = backup
    self.chainId = chainId
    self.gatewayConfig = gatewayConfig
    client = try Portal.getClient(apiHost, apiKey)
    keychain.clientId = client?.id
    self.keychain = keychain

    // Other stuff
    self.autoApprove = autoApprove
    self.isSimulator = isSimulator
    self.apiHost = apiHost

    if version != "v4" {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v4' is currently supported.")
    }

    self.version = version

    if !address.isEmpty {
      self.address = address
    }

    // Initialize the Portal API
    let api = PortalApi(address: self.address, apiKey: apiKey, chainId: chainId, apiHost: apiHost)
    self.api = api

    // Ensure storage adapters have access to the Portal API
    if backup.gdrive != nil {
      backup.gdrive?.api = api
    }
    if backup.icloud != nil {
      backup.icloud?.api = api
    }

    // Determine the Gateway URL for the current chain
    let gatewayUrl = try getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)

    // Initialize the PortalProvider
    provider = try PortalProvider(
      apiKey: apiKey,
      chainId: chainId,
      gatewayUrl: gatewayUrl,
      keychain: keychain,
      autoApprove: autoApprove,
      mpcHost: mpcHost,
      version: version
    )

    // Initialize Mpc
    mpc = PortalMpc(
      apiKey: apiKey,
      chainId: chainId,
      keychain: keychain,
      storage: backup,
      gatewayUrl: gatewayUrl,
      api: self.api,
      isSimulator: isSimulator,
      mpcHost: mpcHost,
      version: version
    )
  }

  /// Set the address on the instance and update the Provider address
  /// - Parameters:
  ///   - to: The address to be used for wallet transactions
  /// - Returns: Void
  public func setAddress(to: String?) {
    let address = to != nil ? to : mpc.getAddress()

    if address != nil {
      self.address = address!

      provider.setAddress(value: address!)
      api.address = address!
    }
  }

  /// Set the chainId on the instance and update MPC and Provider chainId
  /// - Parameters:
  ///   - to: The chainId to use for processing wallet transactions
  /// - Returns: Void
  public func setChainId(to: Int) throws {
    if chainId != to {
      chainId = to

      // Get a fresh gatewayUrl
      let gatewayUrl = try getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)

      // Update MPC
      mpc.setChainId(chainId: to)
      mpc.setGatewayUrl(gatewayUrl: gatewayUrl)

      // Update the Provider
      provider.chainId = to
      provider.rpc = HttpRequester(baseUrl: gatewayUrl)

      // Update the API instance
      api.chainId = to
    }
  }

  public func updateAutoApprove(value: Bool) {
    autoApprove = value
    provider.autoApprove = value
  }

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

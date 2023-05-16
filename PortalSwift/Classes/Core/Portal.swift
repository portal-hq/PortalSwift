//
//  Portal.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The list of backup methods for PortalSwift.
public enum BackupMethods: String {
  case GoogleDrive = "gdrive"
  case iCloud = "icloud"
  case Portal = "portal"
}

/// A struct with the backup options (gdrive and/or icloud) initialized.
public struct BackupOptions {
  public var gdrive: GDriveStorage?
  public var icloud: ICloudStorage?
  public var portal: PortalStorage?
  
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
  
  public init(portal: PortalStorage) {
    self.portal = portal
  }
  
  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(gdrive: GDriveStorage, icloud: ICloudStorage) {
    self.gdrive = gdrive
    self.icloud = icloud
  }
  
  subscript(key: String) -> Any? {
    switch(key) {
    case BackupMethods.GoogleDrive.rawValue:
      return self.gdrive
    case BackupMethods.iCloud.rawValue:
      return self.icloud
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
}

/// Determines the appropriate Gateway URL to use for the current chainId
/// - Parameters:
///   - gatewayConfig: A dictionary of chainIds (keys) and gateway URLs (values).
///   - chainId: The chainId we should use, such as 5 (Goerli).
/// - Throws: PortalArgumentError.noGatewayConfigForChain with the chainId.
/// - Returns: The URL to be used for Gateway requests.
private func getGatewayUrl(gatewayConfig: Dictionary<Int, String>, chainId: Int) throws -> String {
  if (gatewayConfig[chainId] == nil) {
    throw PortalArgumentError.noGatewayConfigForChain(chainId: chainId)
  }
  
  return gatewayConfig[chainId]!
}

/// The main Portal class.
public class Portal {
  public var address: String = ""
  public var api: PortalApi
  public var apiKey: String
  public var backup: BackupOptions
  public var chainId: Int
  public var autoApprove: Bool
  public var isSimulator: Bool
  public var keychain: PortalKeychain
  public var mpc: PortalMpc
  public var provider: PortalProvider
  public var gatewayConfig: Dictionary<Int, String>
  public var version: String
  
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
    chainId: Int,
    gatewayConfig: Dictionary<Int, String>,
    // Optional
    backup: BackupOptions = BackupOptions(portal: PortalStorage()),
    keychain: PortalKeychain = PortalKeychain(),
    isSimulator: Bool = false,
    version: String = "v3",
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
    self.keychain = keychain
    
    // Other stuff
    self.autoApprove = autoApprove
    self.isSimulator = isSimulator
    
    if (version != "v3") {
      throw PortalArgumentError.versionNoLongerSupported(message: "MPC Version is not supported. Only version 'v3' is currently supported.")
    }
    
    self.version = version
    
    if (!address.isEmpty) {
      self.address = address
    }
    
    // Initialize the Portal API
    let api = PortalApi(apiKey: apiKey, apiHost: apiHost)
    self.api = api
    
    // Ensure storage adapters have access to the Portal API
    if (backup.gdrive != nil) {
      backup.gdrive?.api = api
    }
    if (backup.icloud != nil) {
      backup.icloud?.api = api
    }
    
    // Determine the Gateway URL for the current chain
    let gatewayUrl = try getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)
    
    // Initialize the PortalProvider
    self.provider = try PortalProvider(
      apiKey: apiKey,
      chainId: chainId,
      gatewayUrl: gatewayUrl,
      autoApprove: autoApprove,
      mpcHost: mpcHost,
      version: version
    )
    
    // Initialize Mpc
    self.mpc = PortalMpc(
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
  public func setAddress(to: String?) -> Void {
    let address = to != nil ? to : mpc.getAddress()
    
    if (address != nil) {
      self.address = address!
      
      provider.setAddress(value: address!)
    }
  }
  
  /// Set the chainId on the instance and update MPC and Provider chainId
  /// - Parameters:
  ///   - to: The chainId to use for processing wallet transactions
  /// - Returns: Void
  public func setChainId(to: Int) throws -> Void {
    if (self.chainId != to) {
      self.chainId = to
      
      // Get a fresh gatewayUrl
      let gatewayUrl = try getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)
      
      // Update MPC
      mpc.setChainId(chainId: to)
      mpc.setGatewayUrl(gatewayUrl: gatewayUrl)
      
      // Update the Provider
      provider.chainId = to
      provider.rpc = HttpRequester(baseUrl: gatewayUrl)
    }
  }
}

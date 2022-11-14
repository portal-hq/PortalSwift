//
//  Portal.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum BackupMethods: String {
  case GoogleDrive = "gdrive"
  case iCloud = "icloud"
}

public struct BackupOptions {
  public var gdrive: GDriveStorage?
  public var icloud: ICloudStorage?
  
  public init(gdrive: GDriveStorage) {
    self.gdrive = gdrive
  }
  
  public init(icloud: ICloudStorage) {
    self.icloud = icloud
  }
  
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

public enum PortalArgumentError: Error {
  case invalidGatewayConfig
  case noGatewayConfigForChain(chainId: Int)
}

/// Determines the appropriate Gateway URL to use for the current chainId
///
/// - Returns: The URL to be used for Gateway requests
private func getGatewayUrl(gatewayConfig: Dictionary<Int, String>, chainId: Int) throws -> String {
  if (gatewayConfig[chainId] == nil) {
    throw PortalArgumentError.noGatewayConfigForChain(chainId: chainId)
  }
  
  return gatewayConfig[chainId]!
}

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
  
  public init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychain,
    gatewayConfig: Dictionary<Int, String>,
    // Optional
    isSimulator: Bool = false,
    address: String = "",
    apiHost: String = "api.portalhq.io",
    autoApprove: Bool = false,
    mpcHost: String = "mpc.portalhq.io"
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
      gatewayUrl: gatewayUrl
    )
    
    // Initialize Mpc
    self.mpc = PortalMpc(
      apiKey: apiKey,
      chainId: chainId,
      keychain: keychain,
      storage: backup,
      gatewayUrl: gatewayUrl,
      isSimulator: isSimulator,
      mpcHost: mpcHost
    )
  }
  
  /// Set the address on the instance and update the Provider address
  ///
  /// - Parameters:
  ///   - to: The address to be used for wallet transactions
  ///
  /// - Returns: Void
  public func setAddress(to: String?) -> Void {
    let address = to != nil ? to : mpc.address
    
    if (address != nil) {
      self.address = address!
      
      provider.setAddress(value: address!)
    }
  }
  
  /// Set the chainId on the instance and update MPC and Provider chainId
  ///
  /// - Parameters:
  ///   - to: The chainId to use for processing wallet transactions
  ///
  /// - Returns: Void
  public func setChainId(to: Int) throws -> Void {
    if (self.chainId != to) {
      self.chainId = to
      
      // Get a fresh gatewayUrl
      let gatewayUrl = try getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)

      // Update MPC
      mpc.chainId = to
      mpc.gatewayUrl = gatewayUrl

      // Update the Provider
      provider.chainId = to
      provider.rpc = HttpRequester(baseUrl: gatewayUrl)
    }
  }
}

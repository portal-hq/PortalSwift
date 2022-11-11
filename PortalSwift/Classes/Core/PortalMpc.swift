//
//  Mpc.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc. on 11/10/22.
//

import Foundation

public class PortalMpc {
  public var address: String?
  public var apiKey: String
  public var chainId: Int
  public var mpcHost: String
  public var isSimulator: Bool
  public var keychain: PortalKeychain
  public var gatewayUrl: String
  public var portal: Portal?
  
  init(
    apiKey: String,
    chainId: Int,
    keychain: PortalKeychain,
    gatewayUrl: String,
    isSimulator: Bool = false,
    mpcHost: String = "mpc.portalhq.io"
  ) {
    // Basic setup
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayUrl = gatewayUrl
    self.keychain = keychain
    
    // Other stuff
    self.isSimulator = isSimulator
    self.mpcHost = String(format: "https://%@", mpcHost)
  }
}

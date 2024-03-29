//
//  MockPortal.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortal: Portal {
  override public init(
    apiKey: String,
    backup _: BackupOptions,
    chainId _: Int,
    keychain: PortalKeychain,
    gatewayConfig: [Int: String],
    // Optional
    isSimulator _: Bool = false,
    version _: String = "v6",
    autoApprove: Bool = false,
    apiHost: String = "api.portalhq.io",
    mpcHost _: String = "mpc.portalhq.io",
    featureFlags _: FeatureFlags? = nil,
    isMocked _: Bool = true
  ) throws {
    //  Handle the legacy use case of using Ethereum references as keys
    let rpcConfig: [String: String] = Dictionary(gatewayConfig.map { key, value in
      let newKey = "eip155:\(key)"
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })

    let provider = try MockPortalProvider(
      apiKey: apiKey,
      rpcConfig: rpcConfig,
      keychain: keychain,
      autoApprove: autoApprove
    )

    let api = MockPortalApi(
      apiKey: apiKey,
      apiHost: apiHost,
      provider: provider
    )

    try super.init(
      apiKey,
      withRpcConfig: rpcConfig
    )
  }
}

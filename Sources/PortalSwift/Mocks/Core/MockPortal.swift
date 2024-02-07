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
    isMocked _: Bool = true
  ) throws {
    let provider = try MockPortalProvider(
      apiKey: apiKey,
      chainId: chainId,
      gatewayConfig: gatewayConfig,
      keychain: keychain,
      autoApprove: autoApprove
    )

    let api = MockPortalApi(
      apiKey: apiKey,
      apiHost: apiHost,
      provider: provider
    )

    try super.init(
      apiKey: apiKey,
      backup: backup,
      chainId: chainId,
      keychain: keychain,
      gatewayConfig: gatewayConfig,
      isSimulator: isSimulator,
      version: version,
      autoApprove: autoApprove,
      apiHost: apiHost,
      mpcHost: mpcHost,
      mpc: MockPortalMpc(apiKey: apiKey, api: api, keychain: keychain, storage: backup, mobile: MockMobileWrapper()),
      api: api,
      binary: MockMobileWrapper(),
      featureFlags: featureFlags,
      isMocked: true
    )
  }
}

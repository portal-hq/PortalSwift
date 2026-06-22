//
//  Trading.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// The main entry point for trading-related functionality in the Portal SDK.
///
/// This class provides access to various trading providers and their capabilities.
/// Currently supports Lifi and 0X as trading providers.
public class Trading {
  /// Access to Lifi trading provider functionality.
  public var lifi: LifiProtocol

  /// Access to 0X trading provider functionality.
  public var zeroX: ZeroXProtocol

  /// Create an instance of Trading.
  /// - Parameters:
  ///   - api: The Portal API instance to use for trading operations.
  ///   - portal: The portal (or mock) providing `request` for high-level execution flows like `zeroX.tradeAsset` (can be `nil`, e.g. in tests).
  init(api: PortalApiProtocol, portal: ZeroXPortalDependency? = nil) {
    self.lifi = Lifi(api: api.lifi)
    self.zeroX = ZeroX(api: api.zeroX, portal: portal)
  }
}

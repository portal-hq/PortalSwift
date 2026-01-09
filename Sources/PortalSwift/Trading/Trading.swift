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
  /// - Parameter api: The Portal API instance to use for trading operations.
  init(api: PortalApiProtocol) {
    self.lifi = Lifi(api: api.lifi)
    self.zeroX = ZeroX(api: api.zeroX)
  }
}

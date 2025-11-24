//
//  Swap.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// The main entry point for swap-related functionality in the Portal SDK.
///
/// This class provides access to various swap providers and their capabilities.
/// Currently supports Lifi as a swap provider.
public class Swap {
  /// Access to Lifi swap provider functionality.
  public var lifi: LifiProtocol

  /// Create an instance of Swap.
  /// - Parameter api: The Portal API instance to use for swap operations.
  init(api: PortalApiProtocol) {
    self.lifi = Lifi(api: api.swapLifi)
  }
}

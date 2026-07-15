//
//  Yield.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// The main entry point for yield-related functionality in the Portal SDK.
///
/// This class provides access to various yield providers and their capabilities.
/// Currently supports YieldXyz as the primary yield provider.
public class Yield {
  /// Access to YieldXyz yield provider functionality.
  /// This property can be set for custom implementations.
  public var yieldxyz: YieldXyzProtocol

  /// Create an instance of Yield.
  /// - Parameters:
  ///   - api: The Portal API instance to use for yield operations.
  ///   - portal: The portal dependency used by high-level `deposit`/`withdraw` for signing,
  ///     address resolution and confirmation. May be `nil` when only low-level methods are used.
  init(api: PortalApiProtocol, portal: YieldXyzPortalDependency? = nil) {
    self.yieldxyz = YieldXyz(api: api.yieldxyz, portal: portal)
  }

  /// Returns the available validators for a native-staking yield.
  /// - Parameter yieldId: The yield identifier.
  /// - Returns: The validators for the yield.
  /// - Throws: `YieldXyzError.noValidators` if none are returned, or network errors.
  public func getValidators(yieldId: String) async throws -> [YieldXyzValidator] {
    try await yieldxyz.getValidators(yieldId: yieldId)
  }
}

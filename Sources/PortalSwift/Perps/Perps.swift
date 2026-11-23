//
//  Perps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for perpetual-futures functionality in the Portal SDK.
///
/// Currently supports Yield.xyz Perps.
public class Perps {
  /// Access to Yield.xyz Perps functionality.
  /// This property can be set for custom implementations.
  public var yieldxyz: YieldXyzPerpsProtocol

  /// Create an instance of Perps around a Yield.xyz Perps implementation, for example a test double
  /// for a `PortalProtocol` conformance.
  /// - Parameter yieldxyz: The Yield.xyz Perps implementation `yieldxyz` returns.
  public init(yieldxyz: YieldXyzPerpsProtocol) {
    self.yieldxyz = yieldxyz
  }

  /// Create an instance of Perps.
  /// - Parameters:
  ///   - api: The Portal API instance to use for perps operations.
  ///   - inFlightActions: The guard against executing one action twice at once. `Portal` passes the
  ///     one it owns, so the guard holds across every `Perps` it builds.
  ///   - dependencies: What the high-level `executeAction` / `signAndSubmitAction` need to sign and
  ///     confirm transactions, and the wallet address account requests default to (injected by
  ///     Portal).
  convenience init(
    api: PortalApiProtocol,
    inFlightActions: YieldXyzInFlightActions = YieldXyzInFlightActions(),
    dependencies: YieldXyzPerpsExecutionDependencies = YieldXyzPerpsExecutionDependencies()
  ) {
    self.init(yieldxyz: YieldXyzPerps(
      api: api.yieldxyzPerps,
      dependencies: dependencies,
      retryPolicy: .standard,
      inFlightActions: inFlightActions
    ))
  }
}

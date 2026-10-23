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

  /// Create an instance of Perps.
  /// - Parameters:
  ///   - api: The Portal API instance to use for perps operations.
  ///   - inFlightActions: The guard against executing one action twice at once. `Portal` passes the
  ///     one it owns, so the guard holds across every `Perps` it builds.
  ///   - dependencies: What the high-level `executeAction` / `signAndSubmitAction` need to sign and
  ///     confirm transactions, and the wallet address account requests default to (injected by
  ///     Portal).
  init(
    api: PortalApiProtocol,
    inFlightActions: YieldXyzInFlightActions = YieldXyzInFlightActions(),
    dependencies: YieldXyzPerpsExecutionDependencies = YieldXyzPerpsExecutionDependencies()
  ) {
    self.yieldxyz = YieldXyzPerps(
      api: api.yieldxyzPerps,
      dependencies: dependencies,
      retryPolicy: .standard,
      inFlightActions: inFlightActions
    )
  }
}

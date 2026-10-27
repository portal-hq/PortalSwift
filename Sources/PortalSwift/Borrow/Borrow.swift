//
//  Borrow.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for lending functionality in the Portal SDK.
///
/// Currently supports Yield.xyz Borrow.
public class Borrow {
  /// Access to Yield.xyz Borrow functionality.
  /// This property can be set for custom implementations.
  public var yieldxyz: YieldXyzBorrowProtocol

  /// Create an instance of Borrow.
  /// - Parameters:
  ///   - api: The Portal API instance to use for borrow operations.
  ///   - inFlightActions: The guard against executing one action twice at once. `Portal` passes the
  ///     one it owns, so the guard holds across every `Borrow` it builds.
  ///   - dependencies: What the high-level `executeAction` / `signAndSubmitAction` need to sign
  ///     transactions (injected by Portal).
  ///   - lookupEvmTransaction: Reads broadcast transactions back when `api.yieldxyzBorrow` cannot
  ///     (a custom implementation). Unlike `PortalYieldXyzBorrowApi`, which decodes only the hashes
  ///     and the user operation's outcome, Portal's fallback decodes the full
  ///     `getTransactionDetails` response, so a field missing from it fails the lookup.
  init(
    api: PortalApiProtocol,
    inFlightActions: YieldXyzInFlightActions = YieldXyzInFlightActions(),
    dependencies: YieldXyzBorrowExecutionDependencies = YieldXyzBorrowExecutionDependencies(),
    lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction? = nil
  ) {
    let borrowApi = api.yieldxyzBorrow
    self.yieldxyz = YieldXyzBorrow(
      api: borrowApi,
      dependencies: dependencies,
      lookupEvmTransaction: YieldXyzBorrow.lookup(from: borrowApi) ?? lookupEvmTransaction,
      inFlightActions: inFlightActions
    )
  }
}

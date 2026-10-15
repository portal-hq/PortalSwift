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
  ///   - dependencies: What the high-level `executeAction` / `signAndSubmitAction` need to sign
  ///     transactions (injected by Portal).
  ///   - lookupEvmTransaction: Reads broadcast transactions back when `api.yieldxyzBorrow` cannot
  ///     (a custom implementation).
  init(
    api: PortalApiProtocol,
    dependencies: YieldXyzBorrowExecutionDependencies = YieldXyzBorrowExecutionDependencies(),
    lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction? = nil
  ) {
    let borrowApi = api.yieldxyzBorrow
    self.yieldxyz = YieldXyzBorrow(
      api: borrowApi,
      dependencies: dependencies,
      lookupEvmTransaction: YieldXyzBorrow.lookup(from: borrowApi) ?? lookupEvmTransaction
    )
  }
}

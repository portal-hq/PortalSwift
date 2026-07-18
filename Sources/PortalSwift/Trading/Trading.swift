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
  ///   - signAndSendTransaction: Closure that signs and submits an EVM transaction (injected by Portal),
  ///     enabling the high-level `lifi.tradeAsset` bridging method.
  ///   - waitForConfirmation: Closure that waits for on-chain confirmation (injected by Portal),
  ///     enabling the high-level `lifi.tradeAsset` bridging method.
  init(
    api: PortalApiProtocol,
    signAndSendTransaction: LifiSignAndSendTransaction? = nil,
    waitForConfirmation: LifiWaitForConfirmation? = nil
  ) {
    self.lifi = Lifi(
      api: api.lifi,
      signAndSendTransaction: signAndSendTransaction,
      waitForConfirmation: waitForConfirmation
    )
    self.zeroX = ZeroX(api: api.zeroX)
  }
}

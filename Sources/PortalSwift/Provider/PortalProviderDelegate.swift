//
//  PortalProviderDelegate.swift
//  PortalSwift
//
//  Created by Blake Williams on 12/10/23.
//

import Foundation

public protocol PortalProviderDelegate {
  /**
   * Called when the chain has been changed
   * - Optional
   * - Receives the chainId as the argument of `didChaingeChain`
   */
  func portalProvider(_ provider: PortalProvider, didChangeChain: Int)

  /**
   * Called when the provider has connected to a chain
   * - Optional
   * - Receives the chainId as the argument of `didConnect`
   */
  func portalProvider(_ provider: PortalProvider, didConnect: Int)

  func portalProvider(_: PortalProvider, didReceiveResult result: SignerResult?, forPayload: ETHRequestPayload)

  func portalProvider(
    _: PortalProvider,
    didReceiveResult signature: SignerResult?,
    forPayload: ETHTransactionPayload
  )

  /**
   * Called when the provider receives a request to sign
   * - Required
   * - Receives the ETHRequestPayload for the signature as the argument for `didReceiveSigningRequest`
   * - Receives an inout `approved` Bool for the consumer to set as either true or false representing whether
   *   signing is approved or not
   */
  func portalProvider(_ provider: PortalProvider, didReceiveSigningRequest: ETHRequestPayload, approved: inout Bool)

  /**
   * Called when the provider receives a request to sign
   * - Required
   * - Receives the ETHTransactionPayload for the signature as the argument for `didReceiveSigningRequest`
   * - Receives an inout `approved` Bool for the consumer to set as either true or false representing whether
   *   signing is approved or not
   */
  func portalProvider(_ provider: PortalProvider, didReceiveSigningRequest: ETHTransactionPayload, approved: inout Bool)
}

public extension PortalProviderDelegate {
  func portalProvider(_: PortalProvider, didChangeChain _: Int) {
    // Defaults to a no-op
  }

  func portalProvider(_: PortalProvider, didConnect _: Int) {
    // Defaults to a no-op
  }

  func portalProvider(_: PortalProvider, didReceiveResult _: SignerResult?, forPayload _: ETHRequestPayload) {
    // Defaults to a no-op
  }

  func portalProvider(
    _: PortalProvider,
    didReceiveResult _: Any?,
    forPayload _: ETHTransactionPayload
  ) {
    // Defaults to a no-op
  }
}

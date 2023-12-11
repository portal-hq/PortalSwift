//
//  PortalConnectDelegate.swift
//  PortalSwift
//
//  Created by Blake Williams on 12/10/23.
//

import Foundation

public protocol PortalConnectDelegate: PortalProviderDelegate {
  /**
   * Called when the WalletConnect session is disconnected
   * - Optional
   */
  func portalConnect(_ connect: PortalConnect, didDisconnect: DisconnectData)

  /**
   * Called when an error is triggered on the PortalConnect instance
   * - Optional
   */
  func portalConnect(_ connect: PortalConnect, didReceiveError: ConnectError)

  /**
   * Called when a dApp requests a session
   * - Required
   * - Receives the ConnectData for the session proposal as the argument for `didReceiveDappSessionRequest`
   * - Receives an inout `approved` Bool for the consumer to set as either true or false representing whether
   *   the session is approved or not
   */
  func portalConnect(_ connect: PortalConnect, didReceiveDappSessionRequest: ConnectData, approved: inout Bool)
}

public extension PortalConnectDelegate {
  func portalConnect(_: PortalConnect, didDisconnect _: DisconnectData) {
    // Defaults to a no-op
  }

  func portalConnect(_: PortalConnect, didReceiveError _: ConnectError) {
    // Defaults to a no-op
  }
}

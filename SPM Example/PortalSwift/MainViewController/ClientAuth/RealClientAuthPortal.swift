//
//  RealClientAuthPortal.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// `AdoptablePortal` over a real `Portal`.
///
/// The only file in the Client Auth folder that mentions `PortalProtocol`, and therefore the
/// only one the unit-test bundle cannot exercise — so it is kept branch-free on purpose. Every
/// `if` added here is a line the adoption tests stop covering.
final class RealClientAuthPortal: AdoptablePortal {
  /// The chain ids this example app runs on, one per namespace it can hold a wallet in.
  ///
  /// `Portal.isWalletOnDevice(_:)` reads only the namespace half of a chain id, but it reads it
  /// through the real chain id string, so these are the app's own — the same values every other
  /// call site in `ViewController` passes. A namespace with no entry falls back to its bare
  /// namespace, which the SDK parses identically; that path exists so a future namespace on a
  /// client's metadata is asked about rather than silently skipped.
  private static let chainIds: [PortalNamespace: String] = [
    .eip155: "eip155:10143",
    .solana: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
  ]

  private let portal: PortalProtocol

  init(_ portal: PortalProtocol) {
    self.portal = portal
  }

  /// The first authenticated call of a session.
  ///
  /// `Portal.client` memoizes, so the address lookup below has already been paid for by the
  /// time it runs. A `nil` client means the credential resolved to no client at all, which is
  /// a failure to adopt, not an empty result.
  func getClient() async throws -> ClientResponse {
    guard let client = try await self.portal.client else {
      throw PortalExampleAppError.clientInformationUnavailable()
    }

    return client
  }

  /// Reads **server-side** client metadata, not device-local state.
  ///
  /// Blank and absent addresses are dropped at this seam. `Portal.getAddresses()` returns a
  /// `String?` per namespace and a client with no wallet is present with an empty address, so
  /// keeping those would report every new Client Auth client as already having a wallet and
  /// `autoCreateWallet` would never fire.
  func getAddresses() async throws -> WalletAddresses {
    let addresses = try await self.portal.getAddresses()

    return addresses.reduce(into: WalletAddresses()) { result, entry in
      guard let address = entry.value, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return
      }

      result[entry.key] = address
    }
  }

  /// Reads **device-local** state, unlike `getAddresses()` — the half of the wallet's status a
  /// server response cannot answer.
  ///
  /// The failure is deliberately allowed through rather than collapsed into `false`: reporting
  /// a wallet this device can sign with as missing its shares is a false alarm, and letting the
  /// throw out is what keeps `hasSharesOnDevice(_:_:)`'s "could not be asked" state reachable.
  func isWalletOnDevice(_ namespace: PortalNamespace) async throws -> Bool {
    try await self.portal.isWalletOnDevice(Self.chainIds[namespace] ?? namespace.rawValue)
  }

  /// Returns the creation response's own addresses rather than re-reading them.
  ///
  /// The SDK's client cache is not invalidated by wallet creation, so a re-read through
  /// `getAddresses()` would hand back the empty values from before the wallet existed.
  func createWallet() async throws -> WalletAddresses {
    let created = try await self.portal.createWallet(usingProgressCallback: nil)
    var addresses = WalletAddresses()

    if !created.ethereum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      addresses[.eip155] = created.ethereum
    }

    if !created.solana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      addresses[.solana] = created.solana
    }

    return addresses
  }
}

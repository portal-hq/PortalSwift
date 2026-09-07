//
//  SessionAdoption.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// Addresses keyed by namespace — the Swift shape of the RN example's `AddressesByNamespace`.
///
/// A non-optional `String` value on purpose: `Portal.getAddresses()` hands back
/// `[PortalNamespace: String?]`, where a namespace with no wallet is present with a `nil` or
/// blank address. `RealClientAuthPortal` drops those at the seam so that everything on this
/// side of it can read "the key exists" as "there is an address", which is what makes
/// `hasWallet(_:)` a one-liner instead of a three-way test repeated at every call site.
typealias WalletAddresses = [PortalNamespace: String]

/// The wallet surface session adoption needs.
///
/// A protocol rather than `Portal` itself because the example's unit-test bundle cannot build a
/// real `Portal` (its initializer reaches the Keychain and fires two eager `GET /clients/me`
/// calls). Every branch worth testing lives on this side of the seam;
/// `RealClientAuthPortal` is the only implementation that touches `Portal`.
protocol WalletCapablePortal: AnyObject {
  /// Addresses this client already has. Empty when there is no wallet.
  ///
  /// May throw — `resolveWallet(_:getMethods:reporter:)` treats a throw as "unknown", not as
  /// "none".
  func getAddresses() async throws -> WalletAddresses

  /// Whether this device holds the signing shares for `namespace`.
  ///
  /// A different question from `getAddresses()`, which reads server-side client metadata: a
  /// client keeps its wallet whatever happens to a device, so "this client has a wallet" and
  /// "this device can sign with it" can disagree — after a reinstall, or when the Keychain
  /// item was lost. Both answers are needed to describe the wallet honestly.
  ///
  /// May throw — a throw means "could not be asked", not "not on device".
  func isWalletOnDevice(_ namespace: PortalNamespace) async throws -> Bool

  /// Creates a wallet and returns its addresses.
  ///
  /// **Throws** on failure, which is what gives `resolveWallet` a failure to propagate.
  func createWallet() async throws -> WalletAddresses
}

/// Adds the one authenticated call that proves a session actually works.
protocol AdoptablePortal: WalletCapablePortal {
  /// The Portal Client this credential resolves to. The first authenticated call of a session.
  func getClient() async throws -> ClientResponse
}

/// Where the adoption flow narrates itself.
///
/// Adoption reports rather than throws, because most of its steps are non-fatal: a custodian
/// outage or a wallet problem is worth showing the tester without failing the login. The host
/// decides how to render both.
protocol ClientAuthReporter: AnyObject {
  /// One line of the step log. Never carries a token, JWT, email or `totpLink`.
  func log(_ line: String)

  /// A step that failed. The caller decides whether that failure is fatal; usually it is not.
  func reportFailure(step: String, error: Error)
}

// MARK: - Wallet resolution

/// True when any namespace carries a usable address.
///
/// A blank test, not a key-presence test: `ClientResponseMetadataNamespaces.eip155` is present
/// with an empty `address` for a client that has no wallet, so a key check would report every
/// brand-new Client Auth client as already having a wallet and `autoCreateWallet` would never
/// fire. A Solana-only wallet counts as existing.
func hasWallet(_ addresses: WalletAddresses?) -> Bool {
  guard let addresses else {
    return false
  }

  return addresses.values.contains { !isBlankAdoptionValue($0) }
}

/// Whether this device can actually sign for a wallet `addresses` says exists.
///
/// Answers per namespace and stops at the first `true`: a client with an address in two
/// namespaces is usable as soon as one of them has its shares here, and reporting it as
/// unusable because the other does not would be a false alarm on a wallet that signs fine.
///
/// - Returns: `true` when some namespace with an address has its signing shares on device,
///   `false` when every namespace answered and none does, and `nil` when no namespace could be
///   asked — an unanswerable question must not be reported as a missing wallet.
func hasSharesOnDevice(_ addresses: WalletAddresses?, _ portal: WalletCapablePortal) async -> Bool? {
  var answered = false

  for namespace in populatedNamespaces(of: addresses) {
    guard let onDevice = try? await portal.isWalletOnDevice(namespace) else {
      continue
    }

    answered = true
    if onDevice {
      return true
    }
  }

  return answered ? false : nil
}

/// Returns the wallet this session should use, creating one only when host policy allows it.
///
/// The ordering is the contract: an existing wallet short-circuits **before** `getMethods` is
/// called, so a resumed session costs no extra round trip and a `getMethods` outage cannot
/// block a user who already has a wallet.
///
/// - Returns: the addresses in play, or `nil` when there is no wallet and none was created.
/// - Throws: whatever `WalletCapablePortal.createWallet()` throws — a creation failure is the
///   caller's to handle.
func resolveWallet(
  _ portal: WalletCapablePortal,
  getMethods: () async throws -> AuthMethodsResult,
  reporter: ClientAuthReporter
) async throws -> WalletAddresses? {
  // A failed lookup means "unknown", not "no wallet" — fall through and let host policy decide.
  let existing = try? await portal.getAddresses()

  if hasWallet(existing) {
    let address = primaryAddress(of: existing) ?? ""

    // The addresses are returned either way, and deliberately: the wallet does exist, and the
    // backend refuses a second one, so creating is not the answer to missing shares —
    // recovering is. Only the report differs, because "reused" is untrue for a wallet this
    // device cannot sign with, and the failure it produces otherwise surfaces three taps later
    // as an unexplained wallet-not-on-device error.
    switch await hasSharesOnDevice(existing, portal) {
    case .some(true):
      reporter.log("• existing wallet reused — \(address)")
    case .some(false):
      reporter.log(
        "⚠ wallet \(address) exists for this client but its signing shares are not on this device — "
          + "signing and backup will fail until it is recovered from a backup. See the wallet states "
          + "panel for the available recovery methods."
      )
    case .none:
      reporter.log("• existing wallet reused — \(address) (device shares not verified)")
    }

    return existing
  }

  let methods: AuthMethodsResult
  do {
    methods = try await getMethods()
  } catch {
    reporter.reportFailure(step: "getMethods", error: error)
    reporter.log("• skipping wallet creation — host policy unknown")
    return nil
  }

  guard methods.autoCreateWallet else {
    reporter.log("• autoCreateWallet=false — not creating one (host policy)")
    return nil
  }

  reporter.log("… createWallet()")
  let created = try await portal.createWallet()
  reporter.log("✓ createWallet — \(describeAddresses(created))")
  return created
}

// MARK: - Adoption

/// What a completed adoption hands back to the host app.
struct AdoptedSession {
  /// The credential the app now runs on.
  let session: PortalSession
  /// The Portal Client the session resolved to, read from the first authenticated call.
  let clientId: String
  /// Whether that client is account-abstracted, as the backend reports it.
  let isAccountAbstracted: Bool
  /// The wallet in play, or `nil` when there is none and none was created.
  let addresses: WalletAddresses?
  /// The demo custodian's id for this end user, or `nil` when registration was skipped or failed.
  let exchangeUserId: String?
}

/// Names the one condition where the runtime environment flag and the build flag disagree.
///
/// The PortalEx instance and its `x-api-key` are chosen at **build** time by
/// `BACKUP_WITH_PORTAL`, while whether a backup share is Portal-managed is decided at
/// **runtime** by `client.environment?.backupWithPortalEnabled`. When those two disagree every
/// backup path is wrong in a way no error message downstream would explain, so adoption says so
/// once, loudly, with the two values and the fix.
let BACKUP_CONFIG_MISMATCH = "BACKUP_CONFIG_MISMATCH"

/// Reported through `ClientAuthReporter.reportFailure(step:error:)` when the custodian answered
/// but gave us nothing usable. Login still succeeds; only backup and funding are affected.
let MISSING_EXCHANGE_USER_ID = "Client registration returned no exchangeUserId"

/// The error `reportFailure(step: "registerClient", …)` carries when the custodian's response
/// held no usable `exchangeUserId`.
///
/// A named `LocalizedError` rather than an `NSError` so its `localizedDescription` is exactly
/// `MISSING_EXCHANGE_USER_ID` — the reporter renders `localizedDescription`, and a generic
/// error would print "The operation couldn't be completed" instead of the one sentence that
/// tells a tester why backup is about to refuse.
struct MissingExchangeUserIdError: LocalizedError, Equatable {
  var errorDescription: String? { MISSING_EXCHANGE_USER_ID }
}

/// The `BACKUP_CONFIG_MISMATCH` sentence, built from the two flags that disagree.
///
/// Shared with `resolveBackupShareStorage(exchangeUserId:isBackupWithPortalEnabled:isBuiltWithBackupWithPortal:)`
/// so the complaint a tester reads at login and the one they read at backup are the same words.
func backupConfigMismatchMessage(environmentFlag: Bool, isBuiltWithBackupWithPortal: Bool) -> String {
  "\(BACKUP_CONFIG_MISMATCH): Client Auth environment backupWithPortalEnabled=\(environmentFlag) "
    + "but the app was built with BACKUP_WITH_PORTAL=\(isBuiltWithBackupWithPortal); "
    + "rebuild with the matching flag."
}

/// Turns a resolved session into a session the app runs on.
///
/// Four ordered steps, and the order is the contract:
///
///  1. `AdoptablePortal.getClient()` — the first authenticated call, and the only step whose
///     failure aborts. A session that cannot make an authenticated call is not a session, so
///     `onAuthenticated` must not fire.
///  2. The backup-config check — the runtime environment flag against the build flag. A
///     mismatch means every backup destination downstream is wrong, so registration is skipped
///     (registering against the wrong PortalEx instance would mint an unusable exchange user)
///     and the disagreement is reported once with both values.
///  3. Custodian registration — **before** any wallet exists, because the wallet's self-managed
///     backup writes into a store that registration creates.
///  4. Wallet resolution — reuse, create, or neither. A failure here is reported and adopted
///     through: a wallet problem is not an auth problem.
///
/// The session's token is never read. Adoption proves the credential works by *using* it
/// through `portal`, which is the only proof that matters, and `getToken()` would put a live
/// client session token into a call stack that also writes a step log.
///
/// - Returns: `true` when the session was adopted.
func adoptSessionIntoApp(
  session: PortalSession,
  portal: AdoptablePortal,
  getMethods: @escaping () async throws -> AuthMethodsResult,
  reporter: ClientAuthReporter,
  registerClient: ((ClientRegistrationRequest) async throws -> ClientRegistrationResult)?,
  isBuiltWithBackupWithPortal: Bool,
  onAuthenticated: (AdoptedSession) -> Void
) async -> Bool {
  let client: ClientResponse
  do {
    client = try await portal.getClient()
  } catch {
    reporter.reportFailure(step: "getClient", error: error)
    return false
  }
  reporter.log("✓ authenticated call — clientId=\(client.id)")

  // An absent `environment` reads as "not Portal-managed", the same as an explicit `false`:
  // there is no environment to have enabled backup-with-Portal, so the custodian is the only
  // destination such a client could have.
  let environmentFlag = client.environment?.backupWithPortalEnabled ?? false
  let exchangeUserId: String?

  if environmentFlag != isBuiltWithBackupWithPortal {
    reporter.reportFailure(
      step: "backupConfig",
      error: PortalExampleAppError.backupConfigMismatch(
        backupConfigMismatchMessage(
          environmentFlag: environmentFlag,
          isBuiltWithBackupWithPortal: isBuiltWithBackupWithPortal
        )
      )
    )
    exchangeUserId = nil
  } else if !environmentFlag, let registerClient {
    exchangeUserId = await registerForSelfManagedBackup(
      client: client,
      endUserId: session.endUserId,
      registerClient: registerClient,
      reporter: reporter
    )
  } else {
    exchangeUserId = nil
  }

  let addresses: WalletAddresses?
  do {
    addresses = try await resolveWallet(portal, getMethods: getMethods, reporter: reporter)
  } catch {
    reporter.reportFailure(step: "wallet", error: error)
    addresses = nil
  }

  onAuthenticated(
    AdoptedSession(
      session: session,
      clientId: client.id,
      isAccountAbstracted: client.isAccountAbstracted,
      addresses: addresses,
      exchangeUserId: exchangeUserId
    )
  )
  reporter.log("✓ session adopted by the app")
  return true
}

/// Registers this client with the demo custodian so the example app's self-managed backup,
/// recover and funding buttons work identically on both auth paths.
///
/// Every failure is reported and swallowed: a demo-server outage must not block a login.
private func registerForSelfManagedBackup(
  client: ClientResponse,
  endUserId: String,
  registerClient: (ClientRegistrationRequest) async throws -> ClientRegistrationResult,
  reporter: ClientAuthReporter
) async -> String? {
  do {
    let result = try await registerClient(
      ClientRegistrationRequest(
        clientId: client.id,
        username: endUserId,
        isAccountAbstracted: client.isAccountAbstracted
      )
    )

    guard let exchangeUserId = normalizeExchangeUserId(result.exchangeUserId) else {
      reporter.reportFailure(step: "registerClient", error: MissingExchangeUserIdError())
      return nil
    }

    reporter.log("✓ registered with the custodian — exchangeUserId=\(exchangeUserId)")
    return exchangeUserId
  } catch {
    reporter.reportFailure(step: "registerClient", error: error)
    return nil
  }
}

// MARK: - Helpers

/// The namespaces that actually carry an address, in a fixed order.
///
/// Sorted rather than left in the dictionary's hash order so the step log and the
/// `isWalletOnDevice` call sequence are reproducible between runs — a log a tester compares
/// against a previous run is worth more than the microseconds a sort costs.
private func populatedNamespaces(of addresses: WalletAddresses?) -> [PortalNamespace] {
  guard let addresses else {
    return []
  }

  return addresses
    .filter { !isBlankAdoptionValue($0.value) }
    .keys
    .sorted { namespaceRank($0) < namespaceRank($1) }
}

/// The address to name in the step log: EVM first, then Solana, then whatever else exists.
private func primaryAddress(of addresses: WalletAddresses?) -> String? {
  guard let addresses else {
    return nil
  }

  for namespace in populatedNamespaces(of: addresses) {
    if let address = addresses[namespace] {
      return address
    }
  }

  return nil
}

/// A stable rendering of a whole address set for the log line.
private func describeAddresses(_ addresses: WalletAddresses) -> String {
  populatedNamespaces(of: addresses)
    .compactMap { namespace in
      addresses[namespace].map { "\(namespace.rawValue): \($0)" }
    }
    .joined(separator: ", ")
}

/// EVM before Solana before everything else, alphabetically within the tail.
private func namespaceRank(_ namespace: PortalNamespace) -> String {
  switch namespace {
  case .eip155:
    return "0"
  case .solana:
    return "1"
  default:
    return "2\(namespace.rawValue)"
  }
}

/// `true` for an empty or whitespace-only value, which is not an address.
private func isBlankAdoptionValue(_ value: String) -> Bool {
  value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

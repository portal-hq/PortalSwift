//
//  PortalCredentials.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Anything that can hand the SDK the bearer credential it attaches to Portal-owned
/// requests: a Client API Key wrapped in `StaticCredentials`, a `PortalSession`
/// restored by `PortalAuth`, or a host-written provider that fetches a token from the
/// host's own backend.
///
/// The SDK never caches the value it gets back. Every request resolves the token again
/// through `PortalCredentialSupport.resolveToken(_:)`, which is what lets a session rotate or be
/// invalidated underneath a long-lived `Portal` without any plumbing on the host's side.
/// That is also why `getToken()` must be synchronous, non-blocking and free of I/O: it
/// sits on the hot path of every API call, every RPC request and every MPC operation,
/// and a slow or blocking implementation would stall all of them at once.
///
/// The protocol is `Sendable` because a single instance is shared by reference across every
/// component and called from several execution contexts at once; a conformer with mutable
/// state declares `@unchecked Sendable` and guards that state with a lock, as
/// `KeychainPortalSession` does.
///
/// The protocol is class-bound on purpose. Invalidation bookkeeping (the per-credential
/// monitor behind `PortalCredentialSupport.invalidate(_:)`, the once-only "reported" guard behind
/// `PortalCredentialSupport.reportUnauthorized(_:)` and the host's `onSessionInvalidated` subscriptions) is
/// keyed by object identity, so two credentials that happen to hold equal tokens are
/// still two credentials and are invalidated and reported independently.
public protocol PortalCredentials: AnyObject, Sendable {
  /// Returns the credential to send as the bearer of the next request.
  ///
  /// Called once per request, on whichever thread issues it, so it must return promptly
  /// and must not perform I/O. **Implementations must be thread-safe**: `getToken()` and
  /// `invalidate()` run concurrently from the URLSession completion queue, the MPC signing
  /// path, the presignature refill and the main thread, with no serialisation by the SDK
  /// (guard mutable state with a lock, as `KeychainPortalSession` does). Throw
  /// `PortalCredentialError.sessionInvalidated` once the
  /// credential has been invalidated; any other error is normalised by the SDK to
  /// `PortalCredentialError.providerFailure(underlying:)`, and a blank return value is
  /// normalised to `PortalCredentialError.unavailable`, so callers always see one
  /// error family at the credential boundary.
  func getToken() throws -> String

  /// Drops the credential so no later `getToken()` can hand it out again.
  ///
  /// Idempotent: the SDK may call this more than once for the same rejection, and the
  /// host may call it through `Portal.clearSession()` after the SDK already did. Clear
  /// any in-memory copy first and any persisted copy second, and throw only when the
  /// persisted copy could not be deleted — the in-memory session is over either way,
  /// and the caller needs to know a stale copy may still be on disk.
  func invalidate() throws
}

/// A Client API Key presented through the `PortalCredentials` interface.
///
/// This is what `Portal(_ apiKey:)` wraps the key in, so the whole SDK can be written
/// against one credential abstraction instead of branching on "key or session" at each
/// call site. A Client API Key is custodian-owned and holds no local state, so
/// `invalidate()` is a deliberate no-op and the SDK never reports a 401 on it to the
/// host: there is no session for the rejection to have ended (see
/// `PortalCredentialSupport.reportUnauthorized(_:)`), and a listener registered for it can never fire.
public final class StaticCredentials: PortalCredentials {
  /// The raw key, exposed so `PortalCredentialSupport.staticApiKey(of:)` can bridge the subsystems that still
  /// surface a synchronous `apiKey` property. Prefer `getToken()` everywhere else.
  public let value: String

  /// Wraps `value` verbatim. Blank-key enforcement lives in
  /// `PortalCredentialSupport.resolve(apiKey:credentials:)` and `PortalCredentialSupport.resolveToken(_:)`, not
  /// here, so a `StaticCredentials("")` stays constructible (tests rely on it) and fails
  /// at the point of use with a precise error rather than at construction.
  public init(_ value: String) {
    self.value = value
  }

  /// Returns the wrapped key unchanged; a static key cannot become unavailable.
  public func getToken() throws -> String {
    self.value
  }

  /// No-op: a Client API Key holds no local state to drop, and stays usable afterwards.
  public func invalidate() throws {}
}

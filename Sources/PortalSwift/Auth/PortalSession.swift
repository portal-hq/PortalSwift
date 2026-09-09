//
//  PortalSession.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The `PortalSession` `PortalAuth` hands back: a client session token held in memory and
/// mirrored in the Keychain through an `AuthSessionStorage`.
///
/// `getToken()` is a lock-guarded read of the in-memory token and touches no storage, so it
/// is safe on the hot path of every request. `invalidate()` follows the invariant the
/// Android, React Native and Web SDKs share: clear the in-memory token *first*, then ask
/// storage to delete the persisted copy only if it still carries this session's token — a
/// newer login that re-keyed the slot is spared. Clearing first means a failed delete still
/// stops this instance handing out its token; the failure propagates as
/// `PortalAuthError.sessionStorageFailure` so the caller knows a stale copy may remain on disk,
/// and the delete is retried by the next `invalidate()` — the compare token is kept until the
/// delete succeeds, so "already invalidated" is a no-op only once nothing is left on disk.
/// `endUserId` stays readable after invalidation because hosts use it to key UI and per-user
/// state during sign-out.
///
/// `description`, `debugDescription` and `customMirror` all redact the token, so an
/// `AuthenticatedResult` printed with `String(describing:)`, `String(reflecting:)` or `dump`
/// never leaks the client session token into a log.
final class KeychainPortalSession: PortalSession, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable, @unchecked Sendable {
  private static let redactedToken = "<redacted>"

  /// The end user this session authenticates. Never secret; safe to log.
  let endUserId: String

  private let storage: AuthSessionStorage
  private let lock = NSLock()
  private var token: String?

  /// The token the persisted copy is compared against before it is deleted. Set at init and
  /// cleared only once `deleteIfCurrent` has succeeded — deliberately *not* when `token` is
  /// nilled — so a failed delete leaves the next `invalidate()` something to retry with, and a
  /// call after a successful delete is a no-op. Without this, one Keychain fault made every
  /// later `invalidate()` return success while the session survived to the next launch.
  /// Guarded by `lock`.
  private var tokenPendingDelete: String?

  /// `true` while one `invalidate()` is inside `deleteIfCurrent`, so an overlapping call returns
  /// instead of issuing a second delete. Guarded by `lock`.
  private var isDeleting = false

  /// Wraps an already-persisted session. Performs no I/O: `PortalAuth` writes the session to
  /// `storage` before constructing this object, so the two are never out of step on creation.
  init(clientSessionToken: String, endUserId: String, storage: AuthSessionStorage) {
    self.token = clientSessionToken
    self.tokenPendingDelete = clientSessionToken
    self.endUserId = endUserId
    self.storage = storage
  }

  // MARK: PortalCredentials

  /// The client session token, or `PortalCredentialError.sessionInvalidated` once
  /// `invalidate()` has run.
  func getToken() throws -> String {
    self.lock.lock()
    defer { self.lock.unlock() }

    guard let token = self.token else {
      throw PortalCredentialError.sessionInvalidated
    }
    return token
  }

  /// Ends the session: clears the in-memory token, then deletes the persisted copy if it is
  /// still this session's. Idempotent once the delete has succeeded — a later call returns
  /// without touching storage. A call whose delete *failed* is retryable: `getToken()` already
  /// throws `.sessionInvalidated`, and the next `invalidate()` runs the delete again.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the persisted copy could not be
  ///   deleted, or could not be read to check whether it is still this session's (a Keychain
  ///   that cannot be read is not deleted blind, or a newer login's session could be erased).
  ///   The in-memory token is cleared either way; the error means a stale copy may remain on
  ///   disk until a retry succeeds. A `PortalAuthError` from storage is rethrown as is; any other
  ///   error is wrapped with a message that names only its type.
  func invalidate() throws {
    self.lock.lock()
    // Cleared before the delete, and outside the storage call, so a slow or failing
    // Keychain can neither delay nor undo the sign-out of this instance.
    self.token = nil
    guard let pendingToken = self.tokenPendingDelete, !self.isDeleting else {
      // Nothing left on disk (or a concurrent call is deleting it right now).
      self.lock.unlock()
      return
    }
    self.isDeleting = true
    self.lock.unlock()

    do {
      try self.storage.deleteIfCurrent(pendingToken)
    } catch {
      self.lock.lock()
      self.isDeleting = false
      self.lock.unlock()
      if let error = error as? PortalAuthError {
        throw error
      }
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be deleted (\(type(of: error))).")
    }

    self.lock.lock()
    self.tokenPendingDelete = nil
    self.isDeleting = false
    self.lock.unlock()
  }

  // MARK: Redaction

  var description: String {
    "KeychainPortalSession(endUserId: \(self.endUserId), token: \(Self.redactedToken))"
  }

  var debugDescription: String {
    self.description
  }

  var customMirror: Mirror {
    Mirror(
      self,
      children: ["endUserId": self.endUserId, "token": Self.redactedToken],
      displayStyle: .class
    )
  }
}

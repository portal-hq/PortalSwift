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
/// Android, React Native and Web SDKs share: return early when already invalidated, clear the
/// in-memory token *first*, then ask storage to delete the persisted copy only if it still
/// carries this session's token — a newer login that re-keyed the slot is spared. Clearing
/// first means a failed delete still stops this instance handing out its token; the failure
/// propagates as `PortalAuthError.sessionStorageFailure` so the caller knows a stale copy may
/// remain on disk. `endUserId` stays readable after invalidation because hosts use it to key
/// UI and per-user state during sign-out.
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

  /// Wraps an already-persisted session. Performs no I/O: `PortalAuth` writes the session to
  /// `storage` before constructing this object, so the two are never out of step on creation.
  init(clientSessionToken: String, endUserId: String, storage: AuthSessionStorage) {
    self.token = clientSessionToken
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
  /// still this session's. Idempotent — a second call returns without touching storage.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the persisted copy could not be
  ///   deleted, or could not be read to check whether it is still this session's (a Keychain
  ///   that cannot be read is not deleted blind, or a newer login's session could be erased).
  ///   The in-memory token is cleared either way; the error means a stale copy may remain on
  ///   disk. A `PortalAuthError` from storage is rethrown as is; any other error is wrapped with
  ///   a message that names only its type.
  func invalidate() throws {
    self.lock.lock()
    guard let previousToken = self.token else {
      self.lock.unlock()
      return
    }
    // Cleared before the delete, and outside the storage call, so a slow or failing
    // Keychain can neither delay nor undo the sign-out of this instance.
    self.token = nil
    self.lock.unlock()

    do {
      try self.storage.deleteIfCurrent(previousToken)
    } catch let error as PortalAuthError {
      throw error
    } catch {
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be deleted (\(type(of: error))).")
    }
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

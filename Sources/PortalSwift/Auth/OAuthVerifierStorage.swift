//
//  OAuthVerifierStorage.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Security

// MARK: - PendingOAuthVerifier

/// The code verifier of the Google or Apple sign-in this device started last, and when it was
/// stored.
///
/// Only the verifier is kept: the challenge is derived from it, and nothing else about the
/// sign-in is needed to finish it. It is stored with the same keys and types as the Android and
/// React Native SDKs use: `verifier` (a string) and `createdAt` (milliseconds since 1970).
struct PendingOAuthVerifier: Equatable {
  /// The secret sent with `POST /oauth/tokens`. Never logged.
  let verifier: String
  /// When the verifier was stored, in milliseconds since 1970.
  let createdAt: Int64
}

/// Redacted rendering, mirroring `TotpRequiredResult`: the synthesized description of a struct
/// prints every stored property, so a `"\(pending)"` in a log line or an assertion message would
/// otherwise carry the verifier.
extension PendingOAuthVerifier: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  private static let redacted = "<redacted>"

  var description: String {
    "PendingOAuthVerifier(verifier: \(Self.redacted), createdAt: \(self.createdAt))"
  }

  var debugDescription: String {
    self.description
  }

  var customMirror: Mirror {
    Mirror(self, children: ["verifier": Self.redacted, "createdAt": self.createdAt], displayStyle: .struct)
  }
}

// MARK: - OAuthVerifierStorage

/// Where `PortalAuth` keeps the `PendingOAuthVerifier` of a Google or Apple sign-in in progress.
///
/// Persisted rather than held in memory because iOS can terminate the app while the browser is
/// in front, and a verifier lost that way is indistinguishable from a redirect this SDK never
/// asked for: the sign-in would be refused as unsolicited. One slot per auth environment, and
/// the newest sign-in wins.
///
/// **Separate from `AuthSessionStorage`.** Invalidating a session (a `401`), or the session storage
/// clearing an unreadable entry, must not cancel a sign-in in progress, which is often the one
/// replacing that session. Only `PortalAuth.clearPersistedSession()` cancels it, explicitly.
///
/// Synchronous for the same reason as `AuthSessionStorage`, and with the same two rules:
/// permanent faults self-heal and transient faults throw, and `deleteIfCurrent(_:)` is one
/// atomic compare-and-delete.
protocol OAuthVerifierStorage: AnyObject {
  /// The pending verifier, or `nil` when nothing usable is stored.
  ///
  /// An entry that cannot be decoded is cleared and reported as `nil`: no retry makes it
  /// readable, and for a redirect it means the same as no sign-in at all.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when storage could not be read *this
  ///   time* (the entry is kept, so the same redirect can be retried and succeed), or when an
  ///   undecodable entry could not be cleared (a retry can only clear it, so that redirect still
  ///   fails).
  func get() throws -> PendingOAuthVerifier?

  /// Replaces whatever is stored: the newest sign-in wins.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the write fails, or when
  ///   `value.verifier` is not a well-formed RFC 7636 verifier (nothing is written then).
  func set(_ value: PendingOAuthVerifier) throws

  /// Removes the pending verifier. Succeeds when there was nothing to remove.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the delete fails.
  func delete() throws

  /// Removes the pending verifier only if it is still `verifier`, so a sign-in started while
  /// an exchange was in flight keeps its own.
  ///
  /// An entry that cannot be decoded is cleared, as `get()` does. An entry that cannot be
  /// *read* is left alone and the failure thrown: a transient fault has not said whether a
  /// newer sign-in owns the slot, and deleting blind could erase that sign-in's verifier.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the entry could not be read or could
  ///   not be deleted.
  func deleteIfCurrent(_ verifier: String) throws
}

// MARK: - PendingOAuthVerifierCodec

/// The stored shape of a `PendingOAuthVerifier`: a JSON object. `encode(_:)` writes exactly
/// `verifier` (a string) and `createdAt` (an integer); `decode(_:)` ignores any other key.
///
/// `decode(_:)` is strict on purpose. A verifier the backend would reject (outside
/// `[A-Za-z0-9._~-]{43,128}`), or a `createdAt` that is missing, fractional or not a number,
/// describes a sign-in that can never complete, so it reads as unusable and the storage clears
/// it.
enum PendingOAuthVerifierCodec {
  private struct Payload: Codable {
    let verifier: String
    let createdAt: Int64
  }

  /// Serialises `value` with sorted keys, so the output is deterministic.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the verifier is not well formed or
  ///   encoding fails. The message never includes the verifier.
  static func encode(_ value: PendingOAuthVerifier) throws -> Data {
    guard PkceCodeVerifier.isWellFormed(value.verifier) else {
      throw PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be stored: its code verifier is malformed.")
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
      return try encoder.encode(Payload(verifier: value.verifier, createdAt: value.createdAt))
    } catch {
      throw PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be serialised for storage.")
    }
  }

  /// Parses a payload written by `encode(_:)`, or returns `nil` when it is unusable.
  static func decode(_ data: Data) -> PendingOAuthVerifier? {
    // `JSONDecoder` rejects a boolean, a string or a fractional number for `createdAt`, which a
    // `JSONSerialization` + `NSNumber` read would silently coerce.
    guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
          PkceCodeVerifier.isWellFormed(payload.verifier)
    else {
      return nil
    }
    return PendingOAuthVerifier(verifier: payload.verifier, createdAt: payload.createdAt)
  }
}

// MARK: - KeychainOAuthVerifierStorage

/// Keychain-backed `OAuthVerifierStorage`, one generic-password item per auth environment.
///
/// **Where it lives.** Service `PortalSwift.auth.oauthVerifier.<authEnvironmentId>`, account
/// `oauthVerifier`. The prefix is this SDK's own, for the same reason the session uses
/// `PortalSwift.auth.session.*` rather than the React Native SDK's `PortalAuth.session.*`: the
/// SDKs can never read or clear each other's entries. It is also outside the session's service,
/// so clearing a session never touches a sign-in in progress.
///
/// **Protection.** The session's protection class, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
/// never restored to another device and never synchronizable, so the verifier stays on this
/// device. No explicit `kSecAttrAccessGroup` is set. Writes carry the accessibility on the
/// update path too, as `KeychainAuthSessionStorage` does.
///
/// **Fault taxonomy.** `errSecItemNotFound` reads as `nil`. An entry that is not a usable
/// `PendingOAuthVerifier` is deleted and then reads as `nil`, with a warning logged once the
/// delete has succeeded. Every other status throws `PortalAuthError.sessionStorageFailure`
/// carrying the `OSStatus` and leaves the item alone. No message ever carries the verifier.
///
/// **Locking.** Every Keychain operation runs under one `NSLock`, shared by every instance
/// built for the same environment, which is what makes `deleteIfCurrent(_:)` a real
/// compare-and-delete. `NSLock` is not reentrant, so the public methods lock once and call the
/// un-locked `_`-prefixed bodies, never each other.
final class KeychainOAuthVerifierStorage: OAuthVerifierStorage, @unchecked Sendable {
  /// The service prefix; the full service is `"\(servicePrefix).\(authEnvironmentId)"`.
  static let servicePrefix = "PortalSwift.auth.oauthVerifier"

  /// The account every verifier item is stored under. There is one per environment.
  static let accountName = "oauthVerifier"

  /// The protection class every write carries.
  static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String

  private static let registryLock = NSLock()
  private static var locks: [String: NSLock] = [:]

  /// The lock every instance for `service` shares, created on first use and never released.
  private static func lock(forService service: String) -> NSLock {
    self.registryLock.lock()
    defer { self.registryLock.unlock() }

    if let existing = self.locks[service] {
      return existing
    }
    let lock = NSLock()
    self.locks[service] = lock
    return lock
  }

  /// The Keychain service this instance reads and writes.
  let service: String

  private let store: AuthKeychainItemStore
  private let lock: NSLock
  private let logger = PortalLogger.shared

  /// Creates storage for `authEnvironmentId`. Performs no Keychain I/O.
  init(authEnvironmentId: String, store: AuthKeychainItemStore = SecItemAuthKeychainItemStore()) {
    self.service = "\(Self.servicePrefix).\(authEnvironmentId)"
    self.store = store
    self.lock = Self.lock(forService: self.service)
  }

  // MARK: OAuthVerifierStorage

  func get() throws -> PendingOAuthVerifier? {
    self.lock.lock()
    defer { self.lock.unlock() }

    switch try self._read() {
    case let .verifier(pending):
      return pending
    case .absent, .cleared:
      return nil
    }
  }

  func set(_ value: PendingOAuthVerifier) throws {
    let data = try PendingOAuthVerifierCodec.encode(value)

    self.lock.lock()
    defer { self.lock.unlock() }
    try self._set(data)
  }

  func delete() throws {
    self.lock.lock()
    defer { self.lock.unlock() }
    try self._delete()
  }

  func deleteIfCurrent(_ verifier: String) throws {
    self.lock.lock()
    defer { self.lock.unlock() }

    // The read is not swallowed: a Keychain that cannot be read right now has not said whether a
    // newer sign-in owns the entry, and deleting blind could erase that sign-in's verifier.
    switch try self._read() {
    case let .verifier(current) where current.verifier != verifier:
      // Positively different: a newer sign-in already replaced it. Spare it.
      return
    case .absent, .cleared:
      // Nothing usable is stored, and `_read()` has already removed an unusable entry.
      return
    case .verifier:
      try self._delete()
    }
  }

  // MARK: Un-locked bodies (caller holds `lock`)

  /// What one Keychain read found.
  private enum ReadOutcome {
    /// Nothing is stored.
    case absent
    /// An unusable entry was found and has been deleted.
    case cleared
    /// A usable pending verifier.
    case verifier(PendingOAuthVerifier)
  }

  private func _read() throws -> ReadOutcome {
    let (status, result) = self.store.copyMatching(self.readQuery)

    switch status {
    case errSecItemNotFound:
      return .absent
    case errSecSuccess:
      break
    default:
      self.logger.error("KeychainOAuthVerifierStorage.read() - Keychain read failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be read (OSStatus \(status)).")
    }

    // A success without data, or a payload the codec rejects, is permanent: nothing about a retry
    // can make the entry usable, so clear it.
    guard let data = result as? Data, let pending = PendingOAuthVerifierCodec.decode(data) else {
      try self._delete()
      // Logged only once the delete has succeeded. No payload is ever logged.
      self.logger.warn("KeychainOAuthVerifierStorage.read() - An unusable sign-in in progress was cleared.")
      return .cleared
    }

    return .verifier(pending)
  }

  private func _set(_ data: Data) throws {
    var status = self.store.add(self.addAttributes(data))

    if status == errSecDuplicateItem {
      let updateStatus = self.store.update(self.baseQuery, self.updateAttributes(data))
      if updateStatus == errSecItemNotFound {
        // The item vanished between the add and the update. Retry the add exactly once.
        status = self.store.add(self.addAttributes(data))
      } else {
        status = updateStatus
      }
    }

    guard status == errSecSuccess else {
      self.logger.error("KeychainOAuthVerifierStorage.set() - Keychain write failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be stored (OSStatus \(status)).")
    }
  }

  private func _delete() throws {
    let status = self.store.delete(self.baseQuery)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      self.logger.error("KeychainOAuthVerifierStorage.delete() - Keychain delete failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be deleted (OSStatus \(status)).")
    }
  }

  // MARK: Queries

  /// Class, service and account: the identity of the one item this instance owns.
  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: Self.accountName
    ]
  }

  private var readQuery: [String: Any] {
    var query = self.baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne as String
    return query
  }

  private func addAttributes(_ data: Data) -> [String: Any] {
    var attributes = self.baseQuery
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = Self.accessibility
    return attributes
  }

  private func updateAttributes(_ data: Data) -> [String: Any] {
    [
      kSecValueData as String: data,
      kSecAttrAccessible as String: Self.accessibility
    ]
  }
}

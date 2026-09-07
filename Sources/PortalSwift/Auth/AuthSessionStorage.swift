//
//  AuthSessionStorage.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Security

// MARK: - AuthSessionStorage

/// Where `PortalAuth` keeps the signed-in session between launches.
///
/// The interface is deliberately synchronous and tiny — the same four operations the Android
/// and React Native SDKs expose — so `PortalAuth` and `KeychainPortalSession` can be written
/// once against it and tested against an in-memory double. Two rules every implementation
/// must keep, because the callers rely on them:
///
/// - **Permanent faults self-heal, transient faults throw.** An entry that cannot be decoded
///   is deleted and read as "signed out"; a backend that cannot be reached (a locked
///   Keychain, a missing entitlement) throws and leaves the entry alone. Signing a user out
///   because the device happened to be locked would be a bug, not a recovery.
/// - **`deleteIfCurrent(_:)` is one atomic compare-and-delete.** A stale session must never
///   delete a newer one that a later login has already persisted.
protocol AuthSessionStorage: AnyObject {
  /// The persisted session, or `nil` when nothing usable is stored.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` for a transient fault; the entry is
  ///   left in place so the next read can succeed.
  func getSession() throws -> PersistedSession?

  /// Persists `raw` verbatim, replacing whatever was stored. The value is the string
  /// `PersistedSessionCodec.encode(_:)` produced; the storage does not inspect it.
  func set(_ raw: String) throws

  /// Removes the persisted session. Succeeds when there was nothing to remove.
  func delete() throws

  /// Removes the persisted session only if it still carries `token`.
  ///
  /// A stored session with a positively different token belongs to a newer login and is
  /// spared. An entry that cannot be decoded is cleared (that is a permanent fault). An entry
  /// that cannot be *read* is left alone and the failure thrown: a transient fault has not said
  /// whether a newer login owns the slot, and deleting blind could erase that login's session.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the entry could not be read or
  ///   could not be deleted.
  func deleteIfCurrent(_ token: String) throws
}

// MARK: - PersistedSessionCodec

/// The on-disk shape of a `PersistedSession`: a JSON object with exactly the two keys
/// `clientSessionToken` and `endUserId`, matching the payload the Android and React Native
/// SDKs write so the format is documented once across the SDKs.
///
/// `decode(_:)` is strict on purpose. A token or end-user id that is missing, `null`, not a
/// string, empty or blank would produce a session that fails on first use, so it is rejected
/// here and the storage layer self-heals by clearing the entry. Unknown keys are ignored and
/// surrounding whitespace is tolerated, so a payload written by a newer SDK still decodes.
enum PersistedSessionCodec {
  private static let clientSessionTokenKey = "clientSessionToken"
  private static let endUserIdKey = "endUserId"

  /// Serialises `session` with sorted keys so the output is byte-for-byte deterministic.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` if serialisation fails; the message
  ///   never includes the session's values.
  static func encode(_ session: PersistedSession) throws -> String {
    let object: [String: String] = [
      self.clientSessionTokenKey: session.clientSessionToken,
      self.endUserIdKey: session.endUserId
    ]

    let data: Data
    do {
      data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    } catch {
      throw PortalAuthError.sessionStorageFailure(message: "The session could not be serialised for persistence.")
    }

    guard let raw = String(data: data, encoding: .utf8) else {
      throw PortalAuthError.sessionStorageFailure(message: "The serialised session was not valid UTF-8.")
    }
    return raw
  }

  /// Parses a payload written by `encode(_:)` (or by another Portal SDK).
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the payload is not a JSON object
  ///   or either field is missing, `null`, not a string, empty or blank. The message names the
  ///   offending field and never echoes the payload.
  static func decode(_ raw: String) throws -> PersistedSession {
    let object: Any
    do {
      object = try JSONSerialization.jsonObject(with: Data(raw.utf8), options: [])
    } catch {
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session is not valid JSON.")
    }

    guard let dictionary = object as? [String: Any] else {
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session is not a JSON object.")
    }

    let clientSessionToken = try self.requiredString(self.clientSessionTokenKey, in: dictionary)
    let endUserId = try self.requiredString(self.endUserIdKey, in: dictionary)
    return PersistedSession(clientSessionToken: clientSessionToken, endUserId: endUserId)
  }

  private static func requiredString(_ key: String, in dictionary: [String: Any]) throws -> String {
    guard let value = dictionary[key] as? String,
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session is missing a usable `\(key)`.")
    }
    return value
  }
}

// MARK: - AuthKeychainItemStore

/// The four `SecItem*` calls `KeychainAuthSessionStorage` makes, behind a protocol so the
/// storage logic (status taxonomy, self-heal, add-then-update, compare-and-delete, locking)
/// can be unit-tested against an in-memory store that scripts any `OSStatus`, without the
/// simulator Keychain and without an entitlement.
///
/// Implementations are pass-throughs: they must not interpret the status or mutate the
/// dictionaries, because the tests assert on the exact queries the storage builds.
protocol AuthKeychainItemStore: AnyObject {
  /// `SecItemCopyMatching`: the status and, on `errSecSuccess`, the matched item.
  func copyMatching(_ query: [String: Any]) -> (OSStatus, CFTypeRef?)

  /// `SecItemAdd`.
  func add(_ attributes: [String: Any]) -> OSStatus

  /// `SecItemUpdate`.
  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus

  /// `SecItemDelete`.
  func delete(_ query: [String: Any]) -> OSStatus
}

/// The production `AuthKeychainItemStore`: a direct pass-through to the Security framework.
final class SecItemAuthKeychainItemStore: AuthKeychainItemStore {
  init() {}

  func copyMatching(_ query: [String: Any]) -> (OSStatus, CFTypeRef?) {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    return (status, result)
  }

  func add(_ attributes: [String: Any]) -> OSStatus {
    SecItemAdd(attributes as CFDictionary, nil)
  }

  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
    SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
  }

  func delete(_ query: [String: Any]) -> OSStatus {
    SecItemDelete(query as CFDictionary)
  }
}

// MARK: - KeychainAuthSessionStorage

/// Keychain-backed `AuthSessionStorage`, one generic-password item per auth environment.
///
/// **Where it lives.** Service `PortalSwift.auth.session.<authEnvironmentId>`, account
/// `session`. The service is distinct from the MPC shares (`PortalMpc.*`) and from the React
/// Native SDK's slot (`PortalAuth.session.*`) so the three can never read or clear each
/// other's entries, and it is keyed by `authEnvironmentId` because that is the only identity
/// known before the user has signed in. The environment id is used verbatim: the Keychain
/// treats the service as an opaque string, so no encoding is needed and none is applied.
///
/// **Protection.** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: readable in the
/// background once the device has been unlocked after boot and on passcode-less devices,
/// excluded from backups and device migration so a restored device re-authenticates.
/// `kSecAttrSynchronizable` and `kSecAttrAccessGroup` are never set — the session does not
/// travel to iCloud, extensions or app-group siblings. `set(_:)` also carries the
/// accessibility attribute on the update path so an item written under a different
/// protection class by an older build is migrated rather than silently preserved.
///
/// **Fault taxonomy.** `errSecItemNotFound` and an undecodable entry are permanent: the
/// former reads as `nil`, the latter is deleted (self-heal) and then reads as `nil`, with a
/// warning logged only after the delete has succeeded. Every other status
/// (`errSecInteractionNotAllowed` on a locked device, `errSecMissingEntitlement`, `errSecIO`,
/// `errSecAuthFailed`, …) is transient: the call throws
/// `PortalAuthError.sessionStorageFailure` carrying the `OSStatus` and leaves the item alone.
/// Error messages carry the status and never the stored value.
///
/// **Locking.** Every public method takes one `NSLock` for the whole operation, and the lock
/// is process-global per service key, shared by every instance built for the same
/// environment. This is what makes `deleteIfCurrent(_:)` a real compare-and-delete even when
/// a login on another `PortalAuth` instance races it, and it is why the private bodies are
/// un-locked `_`-prefixed functions: `NSLock` is not reentrant, so a public method never
/// calls another public method. `PortalKeychainAccess` is deliberately not reused — it owns
/// the `PortalMpc` namespace and a different protection class.
final class KeychainAuthSessionStorage: AuthSessionStorage, @unchecked Sendable {
  /// The service prefix; the full service is `"\(servicePrefix).\(authEnvironmentId)"`.
  static let servicePrefix = "PortalSwift.auth.session"

  /// The account every session item is stored under. There is one session per environment.
  static let accountName = "session"

  /// The protection class every write carries (see the type documentation for why).
  static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String

  private static let registryLock = NSLock()
  private static var locks: [String: NSLock] = [:]

  /// The lock every instance for `service` shares, created on first use and never released:
  /// the set of auth environments a process talks to is tiny and fixed.
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

  /// Creates storage for `authEnvironmentId`. Performs no Keychain I/O; the first `SecItem`
  /// call happens on the first `getSession()` / `set(_:)` / `delete()`.
  init(authEnvironmentId: String, store: AuthKeychainItemStore = SecItemAuthKeychainItemStore()) {
    self.service = "\(Self.servicePrefix).\(authEnvironmentId)"
    self.store = store
    self.lock = Self.lock(forService: self.service)
  }

  // MARK: AuthSessionStorage

  func getSession() throws -> PersistedSession? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try self._getSession()
  }

  func set(_ raw: String) throws {
    self.lock.lock()
    defer { self.lock.unlock() }
    try self._set(raw)
  }

  func delete() throws {
    self.lock.lock()
    defer { self.lock.unlock() }
    try self._delete()
  }

  func deleteIfCurrent(_ token: String) throws {
    self.lock.lock()
    defer { self.lock.unlock() }

    // The read is not swallowed: this is a compare-and-delete, and a Keychain that cannot be
    // read right now has not said whether a newer login owns the entry. Deleting blind could
    // erase that login's session; failing instead leaves it intact and tells the caller
    // (through `KeychainPortalSession.invalidate()`) that a stale copy may remain on disk.
    switch try self._read() {
    case let .session(current) where current.clientSessionToken != token:
      // Positively different: a newer login already re-keyed the slot. Spare it.
      return
    case .cleared:
      // The entry was unusable and `_read()` has already deleted it under this same lock
      // hold; a second delete would only be a second chance to fail.
      return
    case .absent:
      // Nothing is stored, so there is nothing to delete.
      return
    case .session:
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
    /// A usable session.
    case session(PersistedSession)
  }

  private func _getSession() throws -> PersistedSession? {
    switch try self._read() {
    case let .session(session):
      return session
    case .absent, .cleared:
      return nil
    }
  }

  private func _read() throws -> ReadOutcome {
    let (status, result) = self.store.copyMatching(self.readQuery)

    switch status {
    case errSecItemNotFound:
      return .absent
    case errSecSuccess:
      break
    default:
      self.logger.error("KeychainAuthSessionStorage.getSession() - Keychain read failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be read (OSStatus \(status)).")
    }

    // A success without data, non-UTF-8 bytes, or a payload the codec rejects are all
    // permanent: nothing about a retry can make the entry usable, so clear it.
    guard let data = result as? Data,
          let raw = String(data: data, encoding: .utf8),
          let session = try? PersistedSessionCodec.decode(raw)
    else {
      try self._delete()
      // Logged only once the delete has succeeded: a failed delete throws above, and the
      // entry is still there, so "cleared" would be a lie. No payload is ever logged.
      self.logger.warn("KeychainAuthSessionStorage.getSession() - An unusable persisted session was cleared; reading as signed out.")
      return .cleared
    }

    return .session(session)
  }

  private func _set(_ raw: String) throws {
    let data = Data(raw.utf8)
    var status = self.store.add(self.addAttributes(data))

    if status == errSecDuplicateItem {
      let updateStatus = self.store.update(self.baseQuery, self.updateAttributes(data))
      if updateStatus == errSecItemNotFound {
        // The item vanished between the add and the update. Retry the add exactly once;
        // a second duplicate is reported as a failure rather than looping.
        status = self.store.add(self.addAttributes(data))
      } else {
        status = updateStatus
      }
    }

    guard status == errSecSuccess else {
      self.logger.error("KeychainAuthSessionStorage.set() - Keychain write failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The session could not be persisted (OSStatus \(status)).")
    }
  }

  private func _delete() throws {
    let status = self.store.delete(self.baseQuery)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      self.logger.error("KeychainAuthSessionStorage.delete() - Keychain delete failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be deleted (OSStatus \(status)).")
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

  /// `baseQuery` asking for the item's data. It does not filter on accessibility, so an
  /// item written under an older protection class is still found (and migrated on the next
  /// `set(_:)`).
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

  /// Carries the accessibility as well as the data so an update migrates the protection
  /// class instead of preserving whatever the existing item had.
  private func updateAttributes(_ data: Data) -> [String: Any] {
    [
      kSecValueData as String: data,
      kSecAttrAccessible as String: Self.accessibility
    ]
  }
}

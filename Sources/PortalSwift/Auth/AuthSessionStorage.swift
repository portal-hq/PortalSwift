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
  /// spared, and so is one tagged by another install of the app (the Keychain storage only).
  /// An entry that cannot be decoded is cleared (that is a permanent fault). An entry
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

/// The four `SecItem*` calls `KeychainAuthSessionStorage` and `KeychainOAuthVerifierStorage`
/// make, behind a protocol so the storage logic (status taxonomy, self-heal, add-then-update,
/// compare-and-delete, locking) can be unit-tested against an in-memory store that scripts any
/// `OSStatus`, without the simulator Keychain and without an entitlement.
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

// MARK: - AuthInstallIdStore

/// The identity of this install of the host app, which `KeychainAuthSessionStorage` tags every
/// session it writes with.
///
/// It exists because Keychain items outlive the app: deleting the app leaves the session item
/// behind, and a reinstall could otherwise read the previous install's session. The id lives in
/// storage the system deletes with the app, so a reinstall starts without one and the session
/// item it finds carries a tag that does not match.
///
/// "No id" and "the id cannot be read right now" must stay distinct: the first clears a tagged
/// session, so mistaking the second for it would sign a user out because the device was locked.
protocol AuthInstallIdStore: AnyObject {
  /// This install's id, or `nil` when this install has not created one yet. Never creates one.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when an id exists but cannot be read.
  func current() throws -> String?

  /// This install's id, created and saved on first use. Concurrent first calls return one id.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when an existing id cannot be read (it is
  ///   never replaced then) or a new one cannot be saved.
  func currentOrCreate() throws -> String
}

/// The production `AuthInstallIdStore`: a random UUID string in
/// `Library/Application Support/PortalSwift/auth-install-id`, which iOS deletes with the app.
///
/// A file rather than `UserDefaults` for two reasons. Its protection class is set explicitly to
/// `completeUntilFirstUserAuthentication`, matching the session item's
/// `AfterFirstUnlockThisDeviceOnly`, so whenever the item can be read the id can be too, even
/// in a host whose default data protection is stricter. And a missing file is told apart from
/// one that cannot be read: `UserDefaults` reports both as `nil`.
///
/// One id serves every auth environment. A host that deletes this file also drops the id, and
/// its next launch reads as signed out — the session is ignored, never handed to the wrong
/// install. A file that is empty or not UTF-8 is treated as no id for the same reason. A file
/// that exists but cannot be read is not: `current()` throws `sessionStorageFailure`, a
/// transient fault like a locked Keychain, and `currentOrCreate()` never replaces it, so a
/// locked device never looks like a fresh install. Any other contents are used as the id as
/// they are: only this install writes the file, so they can match only a tag this install wrote.
final class FileAuthInstallIdStore: AuthInstallIdStore, @unchecked Sendable {
  /// The directory under Application Support the id lives in.
  static let directoryName = "PortalSwift"

  /// The file the id is stored in.
  static let fileName = "auth-install-id"

  /// Process-global, so two storages creating the id at once agree on one.
  private static let lock = NSLock()

  /// The file this instance reads and writes.
  let fileURL: URL

  private let fileManager = FileManager.default

  /// - Parameter baseDirectory: The directory `PortalSwift/auth-install-id` is created under;
  ///   Application Support by default. Performs no I/O.
  init(baseDirectory: URL? = nil) {
    let base = baseDirectory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
    self.fileURL = base
      .appendingPathComponent(Self.directoryName, isDirectory: true)
      .appendingPathComponent(Self.fileName, isDirectory: false)
  }

  func current() throws -> String? {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    return try self._current()
  }

  func currentOrCreate() throws -> String {
    Self.lock.lock()
    defer { Self.lock.unlock() }

    if let existing = try self._current() {
      return existing
    }

    let created = UUID().uuidString
    let directory = self.fileURL.deletingLastPathComponent()
    do {
      // The parents (Application Support, which a fresh install may not have yet) are the host's:
      // created without attributes so they keep the host's default protection, which new files
      // in them can inherit. Only the SDK's own directory gets the explicit class.
      try self.fileManager.createDirectory(
        at: directory.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
      )
      try self.fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
      )
      try Data(created.utf8).write(to: self.fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      throw PortalAuthError.sessionStorageFailure(message: "This install's id could not be saved (\(Self.describe(error))).")
    }
    return created
  }

  // MARK: Un-locked body (caller holds `lock`)

  private func _current() throws -> String? {
    // Read directly rather than checking `fileExists` first: that returns `false` for any failure
    // to check, not only a missing file, and "no id" is the answer that ignores a tagged session.
    // Only "no such file" means no id; every other failure is transient.
    let data: Data
    do {
      data = try Data(contentsOf: self.fileURL)
    } catch {
      if Self.isNoSuchFile(error) {
        return nil
      }
      throw PortalAuthError.sessionStorageFailure(message: "This install's id could not be read (\(Self.describe(error))).")
    }

    guard let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty
    else {
      return nil
    }
    return value
  }

  /// `true` only for a file (or a parent directory) that does not exist.
  private static func isNoSuchFile(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
      return true
    }
    return nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOENT)
  }

  /// The error's domain and code, never its path-bearing description.
  private static func describe(_ error: Error) -> String {
    let nsError = error as NSError
    return "\(nsError.domain) \(nsError.code)"
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
/// `kSecAttrSynchronizable` and `kSecAttrAccessGroup` are never set, so the session never
/// travels to iCloud and lands in the host's default access group: the first
/// `keychain-access-groups` entry, else its app id. A host whose first entry is a group it
/// shares with an extension or a sibling app exposes the item to them, and there is still one
/// session per auth environment between them: the process that signed in last owns it, and the
/// other reads it as another install's (see **One install**), so as signed out, never deleting
/// it, until it signs in again and takes the slot back. `set(_:)` also carries the
/// accessibility attribute on the update path so an item written under a different
/// protection class by an older build is migrated rather than silently preserved.
///
/// **One install.** Keychain items are not deleted with the app, so every write tags the item
/// with this install's id (`kSecAttrGeneric`, from `AuthInstallIdStore`). A read that finds an
/// item tagged by another install — or any tagged item while this install has no id yet, which
/// is what a fresh install after a deletion looks like — reads as signed out and leaves the item
/// alone: `deleteIfCurrent(_:)` spares it too, the next `set(_:)` replaces it and re-tags it, and
/// `delete()` still removes it. It is not deleted on read because the reader cannot tell a
/// deleted install's leftover from the session of a process that shares the access group, and
/// deleting the latter would sign that process out. An id that exists but cannot be read is a
/// transient fault like a locked Keychain: the read throws. The tag is an item attribute, not
/// part of the payload, so the stored JSON stays the shape the other SDKs write. An item with
/// no tag was written by an SDK version that did not tag sessions: an update and a reinstall
/// look the same for it, so it is kept and tagged on the first `getSession()` (best effort; a
/// failed tag is retried on the next read), which keeps app updates from signing users out.
/// With a shared access group, whichever process reads an untagged item first tags it.
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
  private let installIds: AuthInstallIdStore
  private let lock: NSLock
  private let logger = PortalLogger.shared

  /// Creates storage for `authEnvironmentId`. Performs no Keychain or file I/O; the first call
  /// happens on the first `getSession()` / `set(_:)` / `delete()`.
  init(
    authEnvironmentId: String,
    store: AuthKeychainItemStore = SecItemAuthKeychainItemStore(),
    installIds: AuthInstallIdStore = FileAuthInstallIdStore()
  ) {
    self.service = "\(Self.servicePrefix).\(authEnvironmentId)"
    self.store = store
    self.installIds = installIds
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
    case let .session(current, _) where current.clientSessionToken != token:
      // Positively different: a newer login already re-keyed the slot. Spare it.
      return
    case .cleared:
      // The entry was unusable and `_read()` has already deleted it under this same lock
      // hold; a second delete would only be a second chance to fail.
      return
    case .foreign:
      // Another install's (or another process's) session, whatever token it carries. Spare it.
      return
    case .absent:
      // Nothing is stored, so there is nothing to delete.
      return
    case .session:
      // Deleted without being tagged first, even when it has no tag: tagging is for keeping.
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
    /// A session tagged by another install of the app, left in place.
    case foreign
    /// A usable session of this install. `isUntagged` when it was written by an SDK version
    /// that did not tag sessions with the install id.
    case session(PersistedSession, isUntagged: Bool)
  }

  private func _getSession() throws -> PersistedSession? {
    switch try self._read() {
    case let .session(session, isUntagged):
      if isUntagged {
        self._adopt()
      }
      return session
    case .absent, .cleared, .foreign:
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
      // Shared by `getSession()` and `deleteIfCurrent(_:)`, so the label names the operation
      // rather than one of its callers.
      self.logger.error("KeychainAuthSessionStorage.read() - Keychain read failed with OSStatus \(status).")
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be read (OSStatus \(status)).")
    }

    let item = result as? [String: Any]
    // An empty tag counts as no tag. The SDK never writes one, and reading it as another install's
    // would sign out every user whose session predates tagging if the Keychain ever reported a
    // missing attribute as empty data.
    let installTag = (item?[kSecAttrGeneric as String] as? Data).flatMap { $0.isEmpty ? nil : $0 }

    // Another install's session — or any tagged one while this install has no id, which is a
    // fresh install after a deletion. This install must never use it, but it is not deleted:
    // the same tag mismatch is what a process sharing the access group sees. Checked before the
    // payload is decoded, because whether it parses does not matter here. An id that cannot be
    // read throws, so a locked device never reads as a fresh install.
    if let installTag = installTag, try installTag != self.currentInstallTag() {
      self.logger.info("KeychainAuthSessionStorage.read() - The persisted session belongs to another install of this app; reading as signed out.")
      return .foreign
    }

    // A success without data, non-UTF-8 bytes, or a payload the codec rejects are all
    // permanent: nothing about a retry can make the entry usable, so clear it.
    guard let data = item?[kSecValueData as String] as? Data,
          let raw = String(data: data, encoding: .utf8),
          let session = try? PersistedSessionCodec.decode(raw)
    else {
      try self._delete()
      // Logged only once the delete has succeeded: a failed delete throws above, and the
      // entry is still there, so "cleared" would be a lie. No payload is ever logged.
      self.logger.warn("KeychainAuthSessionStorage.getSession() - An unusable persisted session was cleared; reading as signed out.")
      return .cleared
    }

    return .session(session, isUntagged: installTag == nil)
  }

  /// Tags an untagged session with this install's id, so a later reinstall recognises it as
  /// another install's. Best effort: the session is already read and returned either way, and a
  /// failed tag is logged and retried on the next read.
  private func _adopt() {
    let installTag: Data
    do {
      installTag = try Data(self.installIds.currentOrCreate().utf8)
    } catch {
      self.logger.warn("KeychainAuthSessionStorage.getSession() - This install's id could not be read or saved (\(type(of: error))); tagging the persisted session on the next read.")
      return
    }
    let status = self.store.update(self.baseQuery, [kSecAttrGeneric as String: installTag])
    guard status == errSecSuccess else {
      self.logger.warn("KeychainAuthSessionStorage.getSession() - The persisted session could not be tagged with this install (OSStatus \(status)); retrying on the next read.")
      return
    }
    self.logger.debug("KeychainAuthSessionStorage.getSession() - Tagged a session persisted by an earlier SDK version with this install.")
  }

  private func _set(_ raw: String) throws {
    let data = Data(raw.utf8)
    // Created before the write, so the item never lands untagged. If the write then fails the
    // id simply stays for the next one.
    let installTag: Data
    do {
      installTag = try Data(self.installIds.currentOrCreate().utf8)
    } catch {
      self.logger.error("KeychainAuthSessionStorage.set() - This install's id could not be read or saved (\(type(of: error))).")
      throw Self.installIdFailure(error, message: "The session could not be persisted")
    }
    var status = self.store.add(self.addAttributes(data, installTag: installTag))

    if status == errSecDuplicateItem {
      let updateStatus = self.store.update(self.baseQuery, self.updateAttributes(data, installTag: installTag))
      if updateStatus == errSecItemNotFound {
        // The item vanished between the add and the update. Retry the add exactly once;
        // a second duplicate is reported as a failure rather than looping.
        status = self.store.add(self.addAttributes(data, installTag: installTag))
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

  /// This install's id as the item stores it, or `nil` when there is none.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the id exists but cannot be read.
  private func currentInstallTag() throws -> Data? {
    do {
      return try self.installIds.current().map { Data($0.utf8) }
    } catch {
      self.logger.error("KeychainAuthSessionStorage.read() - This install's id could not be read (\(type(of: error))).")
      throw Self.installIdFailure(error, message: "The persisted session could not be read")
    }
  }

  /// A `PortalAuthError` from the install id store as is; anything else wrapped by type name.
  private static func installIdFailure(_ error: Error, message: String) -> PortalAuthError {
    if let authError = error as? PortalAuthError {
      return authError
    }
    return .sessionStorageFailure(message: "\(message): this install's id is unavailable (\(type(of: error))).")
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

  /// `baseQuery` asking for the item's data and attributes (for the install tag), which
  /// `SecItemCopyMatching` returns as one dictionary. It does not filter on accessibility, so
  /// an item written under an older protection class is still found (and migrated on the next
  /// `set(_:)`), nor on the install tag, so another install's item is found and cleared.
  private var readQuery: [String: Any] {
    var query = self.baseQuery
    query[kSecReturnData as String] = true
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne as String
    return query
  }

  private func addAttributes(_ data: Data, installTag: Data) -> [String: Any] {
    var attributes = self.baseQuery
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = Self.accessibility
    attributes[kSecAttrGeneric as String] = installTag
    return attributes
  }

  /// Carries the accessibility and the install tag as well as the data, so an update migrates
  /// the protection class and re-tags the item instead of preserving whatever it had.
  private func updateAttributes(_ data: Data, installTag: Data) -> [String: Any] {
    [
      kSecValueData as String: data,
      kSecAttrAccessible as String: Self.accessibility,
      kSecAttrGeneric as String: installTag
    ]
  }
}

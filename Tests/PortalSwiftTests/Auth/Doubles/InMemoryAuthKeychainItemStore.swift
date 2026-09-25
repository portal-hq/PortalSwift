//
//  InMemoryAuthKeychainItemStore.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Security

/// A map-backed `AuthKeychainItemStore` so `KeychainAuthSessionStorage` can be unit-tested
/// without the simulator Keychain or an entitlement.
///
/// Items are keyed by `(service, account)` and hold the data plus the accessibility attribute
/// they were written with, so a test can prove a `set` migrated an item written under an older
/// protection class. Every call computes the real `OSStatus` from the current state
/// (`errSecItemNotFound`, `errSecDuplicateItem`, `errSecParam`, `errSecSuccess`) unless a
/// status is **scripted**: `statusOverride` is consulted first, then the FIFO queues
/// `nextCopyStatuses` / `nextAddStatuses` / `nextUpdateStatuses` / `nextDeleteStatuses`. A
/// scripted status is returned verbatim; state changes only when it is `errSecSuccess`, in
/// which case the operation is applied unconditionally (an add upserts, a delete removes). A
/// scripted `copyMatching` always yields a `nil` item, so a test can model a `SecItemCopyMatching`
/// that reports success with no data.
///
/// Every query and attributes dictionary is recorded verbatim (`copyQueries`, `addQueries`,
/// `updateCalls`, `deleteQueries`, and all of them in `recordedDictionaries`) because the tests
/// assert on the exact dictionaries the storage builds — which is also why this store never
/// interprets or mutates them.
///
/// Concurrency probes: `inFlight`/`maxInFlight` count operations inside the store,
/// `overlaps` counts operations that started while another was in flight (must stay `0` behind
/// the storage's lock), `holdWindow` widens each operation with a `Thread.sleep` so a race has
/// a fair chance to happen, and `operationHook` runs at the start of every operation outside
/// the store's own lock so it may block on a semaphore or spawn a thread.
final class InMemoryAuthKeychainItemStore: AuthKeychainItemStore, @unchecked Sendable {
  /// The four `SecItem*` calls the storage makes.
  enum Operation: Hashable, CaseIterable {
    case copyMatching
    case add
    case update
    case delete
  }

  /// The identity of one item: `kSecAttrService` + `kSecAttrAccount`.
  struct ItemKey: Hashable {
    let service: String
    let account: String
  }

  /// One stored item and the attributes it was written with.
  struct StoredItem {
    let service: String
    let account: String
    var data: Data
    /// The `kSecAttrAccessible` value the item carries, or `nil` when it was written without one.
    var accessible: String?

    /// `data` as UTF-8 text, or `nil` when it is not valid UTF-8.
    var string: String? {
      String(data: self.data, encoding: .utf8)
    }
  }

  /// One recorded `update(_:_:)` call.
  struct UpdateCall {
    let query: [String: Any]
    let attributes: [String: Any]
  }

  /// The service `KeychainAuthSessionStorage` uses for `AuthTestFixtures.authEnvironmentId`.
  static let defaultService = "\(KeychainAuthSessionStorage.servicePrefix).\(AuthTestFixtures.authEnvironmentId)"
  /// The account every session item is stored under.
  static let defaultAccount = KeychainAuthSessionStorage.accountName
  /// The protection class the storage writes.
  static let defaultAccessibility = KeychainAuthSessionStorage.accessibility

  private static let zeroCounts: [Operation: Int] = Dictionary(uniqueKeysWithValues: Operation.allCases.map { ($0, 0) })

  private let lock = NSLock()
  private var items: [ItemKey: StoredItem] = [:]

  private var _copyQueries: [[String: Any]] = []
  private var _addQueries: [[String: Any]] = []
  private var _updateCalls: [UpdateCall] = []
  private var _deleteQueries: [[String: Any]] = []
  private var _recordedDictionaries: [[String: Any]] = []
  private var _opCounts: [Operation: Int] = InMemoryAuthKeychainItemStore.zeroCounts

  private var _nextCopyStatuses: [OSStatus] = []
  private var _nextAddStatuses: [OSStatus] = []
  private var _nextUpdateStatuses: [OSStatus] = []
  private var _nextDeleteStatuses: [OSStatus] = []
  private var _statusOverride: ((Operation, [String: Any]) -> OSStatus?)?
  private var _operationHook: ((Operation, [String: Any]) -> Void)?
  private var _holdWindow: TimeInterval = 0

  private var _inFlight = 0
  private var _maxInFlight = 0
  private var _overlaps = 0

  init() {}

  // MARK: Seeding and inspection

  /// Puts an item in the store directly, bypassing status computation and recording.
  func seed(
    service: String = InMemoryAuthKeychainItemStore.defaultService,
    account: String = InMemoryAuthKeychainItemStore.defaultAccount,
    data: Data,
    accessible: String? = InMemoryAuthKeychainItemStore.defaultAccessibility
  ) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.items[ItemKey(service: service, account: account)] = StoredItem(service: service, account: account, data: data, accessible: accessible)
  }

  /// `seed(service:account:data:accessible:)` with `data` as the UTF-8 bytes of `string`.
  func seed(
    service: String = InMemoryAuthKeychainItemStore.defaultService,
    account: String = InMemoryAuthKeychainItemStore.defaultAccount,
    data string: String,
    accessible: String? = InMemoryAuthKeychainItemStore.defaultAccessibility
  ) {
    self.seed(service: service, account: account, data: Data(string.utf8), accessible: accessible)
  }

  /// Every item currently stored, keyed by `(service, account)`.
  func snapshot() -> [ItemKey: StoredItem] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.items
  }

  /// The item under `(service, account)`, or `nil`.
  func item(
    service: String = InMemoryAuthKeychainItemStore.defaultService,
    account: String = InMemoryAuthKeychainItemStore.defaultAccount
  ) -> StoredItem? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.items[ItemKey(service: service, account: account)]
  }

  /// How many items are stored.
  var count: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.items.count
  }

  /// `true` when nothing is stored.
  var isEmpty: Bool {
    self.count == 0
  }

  /// Clears the items, every recording, every counter, the scripted statuses, the override and
  /// the hook — a fresh store for the next round of a repeated race.
  func reset() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.items = [:]
    self._copyQueries = []
    self._addQueries = []
    self._updateCalls = []
    self._deleteQueries = []
    self._recordedDictionaries = []
    self._opCounts = Self.zeroCounts
    self._nextCopyStatuses = []
    self._nextAddStatuses = []
    self._nextUpdateStatuses = []
    self._nextDeleteStatuses = []
    self._statusOverride = nil
    self._operationHook = nil
    self._holdWindow = 0
    self._inFlight = 0
    self._maxInFlight = 0
    self._overlaps = 0
  }

  // MARK: Recordings

  /// Every `copyMatching` query, in order.
  var copyQueries: [[String: Any]] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._copyQueries
  }

  /// Every `add` attributes dictionary, in order.
  var addQueries: [[String: Any]] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._addQueries
  }

  /// Every `update` call (query + attributes), in order.
  var updateCalls: [UpdateCall] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._updateCalls
  }

  /// Every `delete` query, in order.
  var deleteQueries: [[String: Any]] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deleteQueries
  }

  /// Every dictionary handed to the store by any operation (update contributes both of its
  /// dictionaries), in order — for "no dictionary ever carried `kSecAttrSynchronizable`" checks.
  var recordedDictionaries: [[String: Any]] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._recordedDictionaries
  }

  /// Calls per operation. Every `Operation` is present (starting at `0`), so
  /// `opCounts[.delete] == 0` reads as `Optional(0) == 0`.
  var opCounts: [Operation: Int] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._opCounts
  }

  // MARK: Scripting

  /// Statuses returned by the next `copyMatching` calls, FIFO, instead of the computed one.
  var nextCopyStatuses: [OSStatus] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._nextCopyStatuses
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._nextCopyStatuses = newValue
    }
  }

  /// Statuses returned by the next `add` calls, FIFO.
  var nextAddStatuses: [OSStatus] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._nextAddStatuses
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._nextAddStatuses = newValue
    }
  }

  /// Statuses returned by the next `update` calls, FIFO.
  var nextUpdateStatuses: [OSStatus] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._nextUpdateStatuses
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._nextUpdateStatuses = newValue
    }
  }

  /// Statuses returned by the next `delete` calls, FIFO.
  var nextDeleteStatuses: [OSStatus] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._nextDeleteStatuses
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._nextDeleteStatuses = newValue
    }
  }

  /// Consulted before the FIFO queues on every operation: return a status to force it, or `nil`
  /// to fall through. Runs outside the store's lock.
  var statusOverride: ((Operation, [String: Any]) -> OSStatus?)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._statusOverride
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._statusOverride = newValue
    }
  }

  /// Runs at the start of every operation (after it is recorded and counted), outside the
  /// store's lock — it may block, spawn a thread or call back into the storage under test.
  var operationHook: ((Operation, [String: Any]) -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._operationHook
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._operationHook = newValue
    }
  }

  /// Seconds each operation sleeps (on its calling thread) before executing, to widen races.
  var holdWindow: TimeInterval {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._holdWindow
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._holdWindow = newValue
    }
  }

  // MARK: Concurrency probes

  /// Operations inside the store right now.
  var inFlight: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._inFlight
  }

  /// The highest `inFlight` ever observed; `1` proves the caller serialised its Keychain calls.
  var maxInFlight: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._maxInFlight
  }

  /// How many operations started while another was still in flight.
  var overlaps: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._overlaps
  }

  // MARK: AuthKeychainItemStore

  func copyMatching(_ query: [String: Any]) -> (OSStatus, CFTypeRef?) {
    self.begin(.copyMatching, query)
    defer { self.end() }

    if let scripted = self.scriptedStatus(for: .copyMatching, query) {
      return (scripted, nil)
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    guard let key = Self.key(from: query) else {
      return (errSecParam, nil)
    }
    guard let item = self.items[key] else {
      return (errSecItemNotFound, nil)
    }
    let wantsData = (query[kSecReturnData as String] as? Bool) == true
    let value: CFTypeRef? = wantsData ? item.data as CFTypeRef : nil
    return (errSecSuccess, value)
  }

  func add(_ attributes: [String: Any]) -> OSStatus {
    self.begin(.add, attributes)
    defer { self.end() }

    let scripted = self.scriptedStatus(for: .add, attributes)
    if let scripted = scripted, scripted != errSecSuccess {
      return scripted
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    guard let key = Self.key(from: attributes), let data = attributes[kSecValueData as String] as? Data else {
      return scripted ?? errSecParam
    }
    if scripted == nil, self.items[key] != nil {
      return errSecDuplicateItem
    }
    self.items[key] = StoredItem(
      service: key.service,
      account: key.account,
      data: data,
      accessible: attributes[kSecAttrAccessible as String] as? String
    )
    return errSecSuccess
  }

  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
    self.begin(.update, query, attributes)
    defer { self.end() }

    let scripted = self.scriptedStatus(for: .update, query)
    if let scripted = scripted, scripted != errSecSuccess {
      return scripted
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    guard let key = Self.key(from: query) else {
      return scripted ?? errSecParam
    }
    guard var item = self.items[key] else {
      return scripted ?? errSecItemNotFound
    }
    if let data = attributes[kSecValueData as String] as? Data {
      item.data = data
    }
    if let accessible = attributes[kSecAttrAccessible as String] as? String {
      item.accessible = accessible
    }
    self.items[key] = item
    return errSecSuccess
  }

  func delete(_ query: [String: Any]) -> OSStatus {
    self.begin(.delete, query)
    defer { self.end() }

    let scripted = self.scriptedStatus(for: .delete, query)
    if let scripted = scripted, scripted != errSecSuccess {
      return scripted
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    guard let key = Self.key(from: query) else {
      return scripted ?? errSecParam
    }
    guard self.items.removeValue(forKey: key) != nil else {
      return scripted ?? errSecItemNotFound
    }
    return errSecSuccess
  }

  // MARK: Private

  private static func key(from dictionary: [String: Any]) -> ItemKey? {
    guard let service = dictionary[kSecAttrService as String] as? String,
          let account = dictionary[kSecAttrAccount as String] as? String
    else {
      return nil
    }
    return ItemKey(service: service, account: account)
  }

  /// Records, counts and probes the operation, then runs the hook and the hold window outside
  /// the store's lock.
  private func begin(_ operation: Operation, _ dictionary: [String: Any], _ secondDictionary: [String: Any]? = nil) {
    self.lock.lock()
    switch operation {
    case .copyMatching:
      self._copyQueries.append(dictionary)
    case .add:
      self._addQueries.append(dictionary)
    case .update:
      self._updateCalls.append(UpdateCall(query: dictionary, attributes: secondDictionary ?? [:]))
    case .delete:
      self._deleteQueries.append(dictionary)
    }
    self._recordedDictionaries.append(dictionary)
    if let secondDictionary = secondDictionary {
      self._recordedDictionaries.append(secondDictionary)
    }
    self._opCounts[operation, default: 0] += 1
    self._inFlight += 1
    if self._inFlight > 1 {
      self._overlaps += 1
    }
    self._maxInFlight = max(self._maxInFlight, self._inFlight)
    let hook = self._operationHook
    let hold = self._holdWindow
    self.lock.unlock()

    hook?(operation, dictionary)
    if hold > 0 {
      Thread.sleep(forTimeInterval: hold)
    }
  }

  private func end() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._inFlight -= 1
  }

  /// `statusOverride` first (run outside the lock), then the operation's FIFO queue.
  private func scriptedStatus(for operation: Operation, _ dictionary: [String: Any]) -> OSStatus? {
    self.lock.lock()
    let override = self._statusOverride
    self.lock.unlock()

    if let forced = override?(operation, dictionary) {
      return forced
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    switch operation {
    case .copyMatching:
      return self._nextCopyStatuses.isEmpty ? nil : self._nextCopyStatuses.removeFirst()
    case .add:
      return self._nextAddStatuses.isEmpty ? nil : self._nextAddStatuses.removeFirst()
    case .update:
      return self._nextUpdateStatuses.isEmpty ? nil : self._nextUpdateStatuses.removeFirst()
    case .delete:
      return self._nextDeleteStatuses.isEmpty ? nil : self._nextDeleteStatuses.removeFirst()
    }
  }
}

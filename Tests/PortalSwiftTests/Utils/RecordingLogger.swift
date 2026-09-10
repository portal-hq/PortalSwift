//
//  RecordingLogger.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Captures every message the SDK logs through `PortalLogger.shared`, so a test can assert
/// both that a path logged (with the right context) and, more importantly, that it never
/// logged a secret.
///
/// It installs itself into the logger's `sink` seam, which sees every level regardless of
/// the configured `logLevel`, so a "never logs the token" assertion cannot pass vacuously
/// because a test forgot to raise the level. The previously installed sink is remembered and
/// restored by `uninstall()`, which tests call from `tearDown`.
///
/// The sink is process-global, so exactly one recorder owns it at a time (`owner`). XCTest runs
/// the cases of a bundle one after another, which already keeps `setUp`/`tearDown` pairs from
/// overlapping; the ownership rule makes the remaining way to overlap — a test that forgot to
/// `uninstall()` — a loud failure in the next test's `install()` instead of a silently stacked
/// sink whose out-of-order restore could leave a live recorder disconnected. Only the owner ever
/// writes the global sink, so a stale recorder's late `uninstall()` cannot disturb the live one.
///
/// Instance state is lock-guarded because the SDK logs from whatever thread completed the work;
/// `ownerLock` is taken before an instance lock, never the other way round, and `record` takes
/// only the instance lock, so a sink that fires during `install()`/`uninstall()` cannot deadlock.
final class RecordingLogger {
  /// The recorder currently installed in `PortalLogger.shared.sink`, or `nil` between tests.
  /// Strong, not weak, so a recorder a test leaked stays identifiable to the next `install()`.
  /// Guarded by `ownerLock`.
  private static var owner: RecordingLogger?
  private static let ownerLock = NSLock()

  private let lock = NSLock()
  private var _entries: [(level: PortalLogLevel, message: String)] = []
  private var previousSink: ((PortalLogLevel, String) -> Void)?
  private var isInstalled = false

  init() {}

  /// Every logged `(level, message)` pair, in the order the SDK emitted them.
  var entries: [(level: PortalLogLevel, message: String)] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._entries
  }

  /// The logged messages at every level, in emission order.
  var messages: [String] {
    self.entries.map { $0.message }
  }

  /// The logged messages at exactly `level`, in emission order.
  func messages(at level: PortalLogLevel) -> [String] {
    self.entries.filter { $0.level == level }.map { $0.message }
  }

  /// `true` when any logged message contains `substring`.
  func contains(_ substring: String) -> Bool {
    self.messages.contains { $0.contains(substring) }
  }

  /// Fails the calling test if any logged message contains `secret`.
  ///
  /// An empty `secret` is itself a test bug (every string contains ""), so it fails loudly
  /// rather than silently passing. The failure message quotes the offending log line so the
  /// leak is easy to locate; it does not repeat the secret separately.
  func assertNoSecret(_ secret: String, file: StaticString = #filePath, line: UInt = #line) {
    guard !secret.isEmpty else {
      XCTFail("assertNoSecret was given an empty secret; the assertion would be vacuous.", file: file, line: line)
      return
    }
    for message in self.messages where message.contains(secret) {
      XCTFail("A secret was logged. Offending message: \(message)", file: file, line: line)
    }
  }

  /// Starts recording by installing this logger as the `PortalLogger.shared` sink,
  /// remembering whatever sink was there before, and takes ownership of the sink. Installing
  /// twice is a no-op.
  ///
  /// If another recorder still owns the sink, a previous test did not `uninstall()` in its
  /// `tearDown`. That is reported as a failure of the calling test — at the caller's `file`/`line`,
  /// so it points at the `setUp` that found the leak — and the stale recorder is evicted (its
  /// saved sink restored) before this one installs, so this test still records its own messages
  /// rather than passing or failing on a sink it does not own.
  func install(file: StaticString = #filePath, line: UInt = #line) {
    Self.ownerLock.lock()
    defer { Self.ownerLock.unlock() }

    if let stale = Self.owner, stale !== self {
      XCTFail(
        "RecordingLogger.install(): another recorder still owns PortalLogger.shared.sink, so a previous test did not call uninstall() in tearDown. Evicting it so this test records its own messages.",
        file: file,
        line: line
      )
      stale.evictLocked()
    }

    self.lock.lock()
    defer { self.lock.unlock() }
    guard !self.isInstalled else {
      return
    }
    self.isInstalled = true
    self.previousSink = PortalLogger.shared.sink
    PortalLogger.shared.sink = { [weak self] level, message in
      self?.record(level, message)
    }
    Self.owner = self
  }

  /// Stops recording and, when this recorder owns the sink, restores the one that was installed
  /// before `install()`. A recorder that was evicted is already unwound, so its late `uninstall()`
  /// leaves the live owner's sink alone.
  func uninstall() {
    Self.ownerLock.lock()
    defer { Self.ownerLock.unlock() }
    self.lock.lock()
    defer { self.lock.unlock() }
    guard self.isInstalled else {
      return
    }
    self.isInstalled = false
    let previous = self.previousSink
    self.previousSink = nil
    if Self.owner === self {
      PortalLogger.shared.sink = previous
      Self.owner = nil
    }
  }

  /// Unwinds a recorder a previous test left installed: restores the sink it had saved and
  /// releases ownership. Called by a newer recorder's `install()` with `ownerLock` held.
  private func evictLocked() {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard self.isInstalled else {
      return
    }
    self.isInstalled = false
    PortalLogger.shared.sink = self.previousSink
    self.previousSink = nil
    Self.owner = nil
  }

  /// Forgets everything recorded so far without changing the installation state.
  func reset() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._entries.removeAll()
  }

  private func record(_ level: PortalLogLevel, _ message: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._entries.append((level: level, message: message))
  }
}

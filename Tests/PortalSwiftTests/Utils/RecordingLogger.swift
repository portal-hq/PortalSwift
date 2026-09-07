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
/// restored by `uninstall()`, which tests call from `tearDown` so recorders never stack up
/// across test cases. All state is lock-guarded because the SDK logs from whatever thread
/// completed the work.
final class RecordingLogger {
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
  /// remembering whatever sink was there before. Installing twice is a no-op.
  func install() {
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
  }

  /// Stops recording and restores the sink that was installed before `install()`.
  func uninstall() {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard self.isInstalled else {
      return
    }
    self.isInstalled = false
    PortalLogger.shared.sink = self.previousSink
    self.previousSink = nil
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

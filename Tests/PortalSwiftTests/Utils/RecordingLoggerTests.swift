//
//  RecordingLoggerTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Pins the ownership rule of the test-side log recorder: one recorder owns
/// `PortalLogger.shared.sink` at a time, an overlap is a loud failure rather than a silently
/// stacked sink, and a stale recorder's late `uninstall()` cannot disconnect the live one.
///
/// Every case starts and ends with no sink installed, and `tearDown` asserts that, so a
/// regression here cannot leak a sink into the rest of the suite.
final class RecordingLoggerTests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    XCTAssertNil(PortalLogger.shared.sink, "Precondition: no recorder is installed when this case starts")
  }

  override func tearDownWithError() throws {
    XCTAssertNil(PortalLogger.shared.sink, "Every case must leave the sink as it found it")
    try super.tearDownWithError()
  }

  func test_install_willRecordEveryLevel_andUninstallWillRestoreThePreviousSink() {
    let recorder = RecordingLogger()

    recorder.install()
    PortalLogger.shared.debug("d")
    PortalLogger.shared.info("i")
    PortalLogger.shared.warn("w")
    PortalLogger.shared.error("e")

    XCTAssertEqual(recorder.messages, ["d", "i", "w", "e"], "The sink sees every level regardless of `logLevel`")
    XCTAssertEqual(recorder.messages(at: .warn), ["w"])

    recorder.uninstall()
    XCTAssertNil(PortalLogger.shared.sink, "Uninstalling the owner restores the sink that was there before")

    PortalLogger.shared.debug("after uninstall")
    XCTAssertEqual(recorder.messages, ["d", "i", "w", "e"], "Nothing is recorded once uninstalled")
  }

  func test_install_twice_isANoOp_andOneUninstallRestoresTheSink() {
    let recorder = RecordingLogger()

    recorder.install()
    recorder.install()
    PortalLogger.shared.debug("once")

    XCTAssertEqual(recorder.messages, ["once"], "A second install does not stack a second sink")

    recorder.uninstall()
    XCTAssertNil(PortalLogger.shared.sink, "One uninstall undoes the one effective install")
  }

  func test_uninstall_withoutInstall_isANoOp() {
    let recorder = RecordingLogger()

    recorder.uninstall()

    XCTAssertNil(PortalLogger.shared.sink)
  }

  func test_install_willFailTheCallingTest_andEvictAStaleRecorder_whenOneIsStillInstalled() {
    // The scenario the ownership rule exists for: a previous test installed a recorder and its
    // `tearDown` never ran `uninstall()`. Before the rule, the next recorder would silently stack
    // on top; the stale one's eventual `uninstall()` would then restore *its* saved sink over the
    // live recorder, disconnecting it mid-test and letting a "never logs the secret" assertion
    // pass on an empty recording.
    let stale = RecordingLogger()
    stale.install()

    let live = RecordingLogger()
    XCTExpectFailure("A recorder left installed by a previous test is reported, not silently shadowed") {
      live.install()
    }

    PortalLogger.shared.debug("owned by live")
    XCTAssertEqual(live.messages, ["owned by live"], "The new recorder owns the sink after the eviction")
    XCTAssertTrue(stale.messages.isEmpty, "The evicted recorder no longer sees the sink")

    // The stale test's `tearDown` finally runs. It must not touch a sink it no longer owns.
    stale.uninstall()
    PortalLogger.shared.debug("still owned by live")
    XCTAssertEqual(live.messages, ["owned by live", "still owned by live"], "A stale recorder's late uninstall leaves the live one connected")

    live.uninstall()
    XCTAssertNil(PortalLogger.shared.sink, "The owner's uninstall restores the sink the stale recorder had originally saved")
  }

  func test_install_willNotFail_whenTheSameRecorderOwnsTheSink() {
    // Re-installing the owner is the documented no-op, not an overlap.
    let recorder = RecordingLogger()
    recorder.install()

    recorder.install()

    recorder.uninstall()
    XCTAssertNil(PortalLogger.shared.sink)
  }

  func test_assertNoSecret_willFail_whenTheSecretWasLogged() {
    let recorder = RecordingLogger()
    recorder.install()
    defer { recorder.uninstall() }
    PortalLogger.shared.error("token=eyJ.secret.jwt rejected")

    XCTExpectFailure("A logged secret is a failure of the calling test") {
      recorder.assertNoSecret("eyJ.secret.jwt")
    }
  }

  func test_assertNoSecret_willFail_whenGivenAnEmptySecret() {
    let recorder = RecordingLogger()
    recorder.install()
    defer { recorder.uninstall() }

    XCTExpectFailure("An empty secret would make the assertion vacuous") {
      recorder.assertNoSecret("")
    }
  }

  func test_assertNoSecret_willPass_whenTheSecretWasNeverLogged() {
    let recorder = RecordingLogger()
    recorder.install()
    defer { recorder.uninstall() }
    PortalLogger.shared.error("token rejected (redacted)")

    recorder.assertNoSecret("eyJ.secret.jwt")
  }
}

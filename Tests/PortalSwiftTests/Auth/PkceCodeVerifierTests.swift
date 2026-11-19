//
//  PkceCodeVerifierTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Security
import XCTest

/// Covers the PKCE verifier and its `S256` challenge against RFC 7636 and against the exact
/// patterns connect-api enforces, so a verifier this SDK generates can never be one the backend
/// rejects with a 400.
final class PkceCodeVerifierTests: XCTestCase {
  /// RFC 7636 Appendix B: the 32 octets, the verifier they encode to, and its `S256` challenge.
  static let rfcOctets: [UInt8] = [
    116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186,
    22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121
  ]

  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// `true` when `value` matches the regular expression `pattern` in full.
  private func matches(_ value: String, _ pattern: String) -> Bool {
    // `\A…\z` rather than `^…$`, which would also match before a trailing newline.
    value.range(of: "\\A\(pattern)\\z", options: .regularExpression) != nil
  }

  /// connect-api's `enforceCodeChallenge`: 43 unpadded base64url characters whose last one is
  /// canonical (only 4 data bits).
  private let backendChallengePattern = "[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]"
  /// connect-api's `enforceCodeVerifier`: 43 to 128 RFC 7636 unreserved characters.
  private let backendVerifierPattern = "[A-Za-z0-9._~-]{43,128}"

  // MARK: - RFC 7636

  func test_challenge_willMatchRfc7636AppendixB() {
    XCTAssertEqual(
      PkceCodeVerifier.challenge(for: AuthTestFixtures.rfcCodeVerifier),
      AuthTestFixtures.rfcCodeChallenge
    )
  }

  func test_generate_willEncodeTheRfc7636OctetsToTheRfcVerifier() throws {
    let verifier = try PkceCodeVerifier.generate { count, buffer in
      XCTAssertEqual(count, Self.rfcOctets.count)
      buffer.copyMemory(from: Self.rfcOctets, byteCount: Self.rfcOctets.count)
      return errSecSuccess
    }

    XCTAssertEqual(verifier, AuthTestFixtures.rfcCodeVerifier)
  }

  func test_challengeMethod_willBeS256() {
    XCTAssertEqual(PkceCodeVerifier.challengeMethod, "S256")
  }

  // MARK: - Shape

  func test_generate_willRequest32Bytes() throws {
    var requested: [Int] = []
    _ = try PkceCodeVerifier.generate { count, _ in
      requested.append(count)
      return errSecSuccess
    }

    XCTAssertEqual(requested, [32])
  }

  func test_generate_willReturn43UnpaddedBase64UrlCharacters() throws {
    for _ in 0 ..< 50 {
      let verifier = try PkceCodeVerifier.generate()
      XCTAssertTrue(self.matches(verifier, "[A-Za-z0-9_-]{43}"), "Not 43 unpadded base64url characters.")
    }
  }

  func test_generate_willReturnAVerifierTheBackendAccepts() throws {
    for _ in 0 ..< 50 {
      let verifier = try PkceCodeVerifier.generate()
      XCTAssertTrue(self.matches(verifier, self.backendVerifierPattern))
      XCTAssertTrue(PkceCodeVerifier.isWellFormed(verifier))
    }
  }

  func test_challenge_willMatchTheBackendChallengePattern() throws {
    XCTAssertTrue(self.matches(AuthTestFixtures.rfcCodeChallenge, self.backendChallengePattern))
    for _ in 0 ..< 50 {
      let challenge = try PkceCodeVerifier.challenge(for: PkceCodeVerifier.generate())
      XCTAssertTrue(self.matches(challenge, self.backendChallengePattern), "The challenge would be rejected with a 400.")
    }
  }

  func test_generate_willReturnANewVerifierEveryTime() throws {
    var seen = Set<String>()
    for _ in 0 ..< 100 {
      try seen.insert(PkceCodeVerifier.generate())
    }

    XCTAssertEqual(seen.count, 100)
  }

  func test_challenge_willDifferFromTheVerifier() {
    XCTAssertNotEqual(PkceCodeVerifier.challenge(for: AuthTestFixtures.rfcCodeVerifier), AuthTestFixtures.rfcCodeVerifier)
  }

  func test_toBase64Url_willUseTheUrlSafeAlphabetWithoutPadding() {
    // Fixed vectors (RFC 4648 §10 plus the two URL-safe characters), so the expected values are
    // not computed the same way the helper computes them.
    let vectors: [([UInt8], String)] = [
      ([], ""),
      (Array("f".utf8), "Zg"),
      (Array("fo".utf8), "Zm8"),
      (Array("foo".utf8), "Zm9v"),
      (Array("foob".utf8), "Zm9vYg"),
      ([0xFB, 0xFF], "-_8"),
      ([0xFB, 0xFF, 0xBF], "-_-_")
    ]

    for (bytes, expected) in vectors {
      XCTAssertEqual(Data(bytes).toBase64Url(), expected, "\(bytes)")
    }
  }

  // MARK: - isWellFormed

  func test_isWellFormed_willAcceptEveryUnreservedCharacterAtBothLengthBounds() {
    let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    let shortest = String(repeating: "a", count: 42) + "~"
    let longest = String(repeating: "Z", count: 124) + "._~-"

    XCTAssertTrue(PkceCodeVerifier.isWellFormed(unreserved))
    XCTAssertTrue(PkceCodeVerifier.isWellFormed(shortest))
    XCTAssertTrue(PkceCodeVerifier.isWellFormed(longest))
    XCTAssertEqual(longest.count, 128)
  }

  func test_isWellFormed_willRejectWhatTheBackendRejects() {
    let base = String(repeating: "a", count: 42)
    // Lengths just outside the bounds, then the characters just outside each accepted range.
    var rejected = ["", base, String(repeating: "a", count: 129)]
    rejected += ["+", "/", "=", " ", "é", "@", "[", "`", "{", ":", "\n"].map { base + $0 }

    for value in rejected {
      XCTAssertFalse(PkceCodeVerifier.isWellFormed(value), value)
    }
  }

  // MARK: - Failure

  func test_generate_willThrowSessionStorageFailure_whenTheGeneratorFails() {
    XCTAssertThrowsError(try PkceCodeVerifier.generate { _, _ in errSecAllocate }) { error in
      XCTAssertEqual(
        error as? PortalAuthError,
        .sessionStorageFailure(message: "A code verifier could not be generated (OSStatus \(errSecAllocate)).")
      )
    }
  }

  func test_generate_willNotReturnOrLogTheBytes_whenTheGeneratorFails() {
    var result: String?
    XCTAssertThrowsError(
      result = try PkceCodeVerifier.generate { count, buffer in
        // Writes predictable bytes, then reports failure: none of them may be used.
        buffer.initializeMemory(as: UInt8.self, repeating: 0x41, count: count)
        return errSecIO
      }
    ) { error in
      guard case .sessionStorageFailure? = error as? PortalAuthError else {
        return XCTFail("Expected PortalAuthError.sessionStorageFailure, got \(type(of: error)).")
      }
    }

    XCTAssertNil(result)
    XCTAssertEqual(self.logger.messages(at: .error).count, 1)
    // 0x41 bytes encode as "QUFB…": none of them may reach a log line.
    self.logger.assertNoSecret("QUFB")
  }
}

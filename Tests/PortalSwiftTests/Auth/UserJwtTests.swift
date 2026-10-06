//
//  UserJwtTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// The outcome of one bounded `UserJwt.readEndUserId(from:)` call.
///
/// The timing cases race the read against a 2 s timeout, and `withTimeout` already returns an
/// optional for "did not finish" — carrying the throw as a value instead of letting it
/// propagate keeps that from becoming a double optional the assertions have to unwrap twice.
private enum ReadEndUserIdOutcome: Equatable {
  case returned(String)
  case threw(PortalAuthError)
}

/// Covers `UserJwt.readEndUserId(from:)`, the only place the SDK looks inside a `userJwt`.
///
/// `POST /auth/totps/validations` returns a session token but no end user, so the TOTP path
/// labels its `PortalSession` from this claim. Three things are pinned. The decoder is
/// hand-rolled, so both base64 alphabets, either padding state and every payload length have
/// to round-trip — Foundation's decoder rejects most of that outright. The claim is validated
/// rather than coerced: a number, a bool, an object, `null`, an empty or blank string are all
/// rejected, because `619692` silently becoming `"619692"` would persist a session under an id
/// no backend recognises. And every error detail is a fixed literal, so a malformed JWT never
/// reaches a log or an error message — the last case asserts exactly that, through the logger's
/// sink as well as through `errorDescription`.
///
/// Cases are ported from the Android and React Native suites so all SDKs read the claim the
/// same way; the module never verifies the signature and none of these cases imply it should.
final class UserJwtTests: XCTestCase {
  /// The length used by the adversarial-input cases: enough that a quadratic padding strip or
  /// a quadratic decoder would blow the 2 s bound.
  private let hostileLength = 200_000

  /// Records every SDK log line so the security case can prove this parser stays silent.
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Success

  func test_readEndUserId_willExtractClaim() throws {
    let endUserId = "cmqv6xewt000dt7rdmgex5vfz"

    XCTAssertEqual(
      try UserJwt.readEndUserId(from: AuthTestFixtures.jwt(for: endUserId)),
      endUserId,
      "A realistic backend-issued userJwt yields its endUserId claim."
    )
  }

  func test_readEndUserId_willReadClaimsSegmentNotHeaderOrSignature() throws {
    let header = AuthTestFixtures.base64Encode(Data("{\"endUserId\":\"from-header\"}".utf8))
    let claims = AuthTestFixtures.base64Encode(Data("{\"endUserId\":\"from-claims\"}".utf8))
    let signature = AuthTestFixtures.base64Encode(Data("{\"endUserId\":\"from-signature\"}".utf8))

    XCTAssertEqual(
      try UserJwt.readEndUserId(from: "\(header).\(claims).\(signature)"),
      "from-claims",
      "Only segment 1 is read; a claim planted in the header or the signature must be ignored."
    )
  }

  func test_readEndUserId_willIgnoreOtherClaims() throws {
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: AuthTestFixtures.userJwt()),
      AuthTestFixtures.endUserId,
      "environmentId/iat/exp/aud/iss are carried by every real userJwt and must not confuse the read."
    )
  }

  func test_readEndUserId_willDecodeBase64UrlAlphabet() throws {
    // A single-claim payload keeps the encoding deterministic: a dictionary would leave the
    // key order (and therefore which characters land on a `-`/`_`) up to JSONSerialization.
    let urlJwt = AuthTestFixtures.jwt(claims: "{\"endUserId\":\"?ab>cd\"}", alphabet: .base64url)
    let segment = try XCTUnwrap(urlJwt.split(separator: ".").dropFirst().first, "The fixture must build three segments.")

    XCTAssertTrue(segment.contains("-"), "The fixture payload must exercise the base64url `-`.")
    XCTAssertTrue(segment.contains("_"), "The fixture payload must exercise the base64url `_`.")
    XCTAssertEqual(try UserJwt.readEndUserId(from: urlJwt), "?ab>cd", "The base64url alphabet decodes.")
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: AuthTestFixtures.jwt(for: "?ab>cd")),
      "?ab>cd",
      "The same value survives inside a realistically shaped claims set."
    )
  }

  func test_readEndUserId_willDecodeStandardAlphabet() throws {
    let standardJwt = AuthTestFixtures.jwt(claims: "{\"endUserId\":\"?ab>cd\"}", alphabet: .standard)
    let segment = try XCTUnwrap(
      standardJwt.split(separator: ".").dropFirst().first,
      "The fixture must build three segments."
    )

    XCTAssertTrue(segment.contains("+"), "The fixture payload must exercise the standard `+`.")
    XCTAssertTrue(segment.contains("/"), "The fixture payload must exercise the standard `/`.")
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: standardJwt),
      "?ab>cd",
      "A JWT encoded with the standard alphabet decodes too, matching Android."
    )
  }

  func test_readEndUserId_willDecodeMixedAlphabets() throws {
    // `>aa>a` encodes to a payload with two `-` sextets, so substituting one for its standard
    // `+` twin leaves a segment that is genuinely mixed rather than simply re-encoded.
    let urlSegment = AuthTestFixtures.base64Encode(Data("{\"endUserId\":\">aa>a\"}".utf8))
    let firstDash = try XCTUnwrap(urlSegment.range(of: "-"), "The fixture payload must contain a `-` to substitute.")
    let mixedSegment = urlSegment.replacingCharacters(in: firstDash, with: "+")
    let header = AuthTestFixtures.base64Encode(Data(AuthTestFixtures.jwtHeaderJSON.utf8))

    XCTAssertTrue(mixedSegment.contains("-"), "The segment must keep a base64url character.")
    XCTAssertTrue(mixedSegment.contains("+"), "The segment must carry a standard character alongside it.")
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: "\(header).\(mixedSegment).signature"),
      ">aa>a",
      "Both alphabets map to the same sextets, so a mixed segment must still decode."
    )
  }

  func test_readEndUserId_willDecodePaddedSegment() throws {
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: AuthTestFixtures.jwt(claims: "{\"endUserId\":\"user-1\"}", padded: true)),
      "user-1",
      "Padding is optional in a JWT; a padded segment must decode all the same."
    )
  }

  func test_readEndUserId_willDecodeEveryPaddingLength() throws {
    var observedPaddingLengths: Set<Int> = []

    for nonce in ["a", "ab", "abc", "abcd"] {
      let claims = "{\"endUserId\":\"\(AuthTestFixtures.endUserId)\",\"nonce\":\"\(nonce)\"}"

      for padded in [false, true] {
        let jwt = AuthTestFixtures.jwt(claims: claims, padded: padded)
        let segment = try XCTUnwrap(jwt.split(separator: ".").dropFirst().first, "The fixture must build three segments.")

        if padded {
          observedPaddingLengths.insert(segment.filter { $0 == "=" }.count)
        } else {
          XCTAssertFalse(segment.contains("="), "The unpadded variant must carry no padding.")
        }

        XCTAssertEqual(
          try UserJwt.readEndUserId(from: jwt),
          AuthTestFixtures.endUserId,
          "nonce=\(nonce), padded=\(padded) must decode without the platform base64 decoder."
        )
      }
    }

    XCTAssertEqual(
      observedPaddingLengths,
      [0, 1, 2],
      "The four nonces must between them cover every padding length a base64 segment can need."
    )
  }

  func test_readEndUserId_willAcceptTwoSegmentJwt_andIgnoreExtraSegments() throws {
    let claims = AuthTestFixtures.base64Encode(Data("{\"endUserId\":\"user-1\"}".utf8))

    XCTAssertEqual(
      try UserJwt.readEndUserId(from: "header.\(claims)"),
      "user-1",
      "Two segments are enough: the signature is never verified here."
    )
    XCTAssertEqual(
      try UserJwt.readEndUserId(from: "a.\(claims).c.d"),
      "user-1",
      "Segments past the claims are ignored rather than treated as malformed."
    )
  }

  // MARK: - Failure

  func test_readEndUserId_willThrowMalformed_whenNoClaimsSegment() {
    self.assertThrowsInvalidUserJwt(
      "not-a-jwt",
      detail: UserJwt.malformedDetail,
      "A string with no `.` has no claims segment to read."
    )
    XCTAssertEqual(
      PortalAuthError.invalidUserJwt(detail: UserJwt.malformedDetail).errorDescription,
      "[PortalAuth] The provided userJwt is malformed.",
      "The message is the one agreed with the Android SDK."
    )
  }

  func test_readEndUserId_willThrow_whenEmptyOrBlank() {
    self.assertThrowsInvalidUserJwt("", detail: UserJwt.malformedDetail, "An empty userJwt is malformed.")
    self.assertThrowsInvalidUserJwt("   ", detail: UserJwt.malformedDetail, "A blank userJwt is malformed.")
  }

  func test_readEndUserId_willThrowNotBase64_whenClaimsInvalid() {
    self.assertThrowsInvalidUserJwt(
      "header.not!valid!base64.signature",
      detail: UserJwt.notBase64UrlDetail,
      "`!` is in neither base64 alphabet."
    )
    self.assertThrowsInvalidUserJwt(
      "header.not*valid*base64.sig",
      detail: UserJwt.notBase64UrlDetail,
      "`*` is in neither base64 alphabet."
    )
  }

  func test_readEndUserId_willThrow_whenClaimsContainWhitespace() {
    self.assertThrowsInvalidUserJwt(
      "header.ey Jh.signature",
      detail: UserJwt.notBase64UrlDetail,
      "Whitespace is not silently skipped; a segment with a space is rejected."
    )
  }

  func test_readEndUserId_willThrowUnableToRead_whenClaimsNotJson() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "this is not json {"),
      detail: UserJwt.unreadableClaimsDetail,
      "A segment that decodes to something other than JSON cannot be read."
    )
  }

  func test_readEndUserId_willThrow_whenClaimsSegmentEmpty() {
    self.assertThrowsInvalidUserJwt(
      "header..sig",
      detail: UserJwt.unreadableClaimsDetail,
      "An empty claims segment decodes to zero bytes, which is not a JSON object."
    )
    self.assertThrowsInvalidUserJwt(
      "header.A.sig",
      detail: UserJwt.unreadableClaimsDetail,
      "One base64 character carries six bits, which do not complete a byte."
    )
  }

  func test_readEndUserId_willThrow_whenClaimsJsonIsArray() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "[\"user-1\"]"),
      detail: UserJwt.unreadableClaimsDetail,
      "Valid JSON that is not an object carries no claims."
    )
  }

  func test_readEndUserId_willThrow_whenClaimsNotUtf8() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claimsBytes: Data([0xFF, 0xFE])),
      detail: UserJwt.unreadableClaimsDetail,
      "Bytes that are not UTF-8 must throw rather than crash a `String(bytes:encoding:)` force unwrap."
    )
  }

  func test_readEndUserId_willThrowNoEndUserId_whenClaimMissing() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"environmentId\":\"env-1\"}"),
      detail: UserJwt.missingEndUserIdDetail,
      "Readable claims without the one claim the SDK needs are still unusable."
    )
    XCTAssertEqual(
      PortalAuthError.invalidUserJwt(detail: UserJwt.missingEndUserIdDetail).errorDescription,
      "[PortalAuth] The userJwt does not carry an endUserId.",
      "The message is the one agreed with the Android SDK."
    )
  }

  func test_readEndUserId_willThrow_whenEndUserIdEmptyOrBlank() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":\"\"}"),
      detail: UserJwt.missingEndUserIdDetail,
      "An empty claim is treated as missing."
    )
    // PLAN 9.5: blank is rejected like empty, stricter than Android — a session labelled " "
    // would persist successfully and then be useless.
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":\"   \"}"),
      detail: UserJwt.missingEndUserIdDetail,
      "A blank claim is rejected like an empty one."
    )
  }

  func test_readEndUserId_willThrow_whenEndUserIdNull() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":null}"),
      detail: UserJwt.missingEndUserIdDetail,
      "A JSON null is not a string and must not become `\"<null>\"`."
    )
  }

  func test_readEndUserId_willThrow_whenEndUserIdNumber() throws {
    let jwt = AuthTestFixtures.jwt(claims: "{\"endUserId\":619692}")

    self.assertThrowsInvalidUserJwt(
      jwt,
      detail: UserJwt.missingEndUserIdDetail,
      "A numeric claim is rejected rather than stringified."
    )

    let thrown = try self.captureError(from: jwt)
    let description = (thrown as? PortalAuthError)?.errorDescription ?? ""
    XCTAssertFalse(description.contains("619692"), "The number must never be surfaced as an endUserId.")
    XCTAssertFalse(description.contains("619692.0"), "Nor its double-precision rendering.")
  }

  func test_readEndUserId_willThrow_whenEndUserIdObjectArrayOrBool() {
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":{\"id\":\"u\"}}"),
      detail: UserJwt.missingEndUserIdDetail,
      "An object claim is not a string."
    )
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":[\"u\"]}"),
      detail: UserJwt.missingEndUserIdDetail,
      "An array claim is not a string."
    )
    self.assertThrowsInvalidUserJwt(
      AuthTestFixtures.jwt(claims: "{\"endUserId\":true}"),
      detail: UserJwt.missingEndUserIdDetail,
      "A boolean claim is not a string; JSONSerialization hands it back as an NSNumber."
    )
  }

  // MARK: - Bounded input

  func test_readEndUserId_willCompleteWithin2s_onHostilePadding() async throws {
    let hostile = "header." + "AAAA" + String(repeating: "=", count: self.hostileLength) + ".signature"

    let outcome = try await self.boundedRead(hostile)

    XCTAssertEqual(
      outcome,
      .threw(.invalidUserJwt(detail: UserJwt.unreadableClaimsDetail)),
      "Padding is stripped in one pass from the end, then the three NUL bytes fail to parse as JSON."
    )
  }

  func test_readEndUserId_willCompleteWithin2s_onHugeValidClaims() async throws {
    let jwt = AuthTestFixtures.jwt(claims: [
      "filler": String(repeating: "x", count: self.hostileLength),
      "endUserId": AuthTestFixtures.endUserId
    ])

    let outcome = try await self.boundedRead(jwt)

    XCTAssertEqual(
      outcome,
      .returned(AuthTestFixtures.endUserId),
      "The decoder is linear in the segment length, so a 200k-character payload is not a stall."
    )
  }

  // MARK: - Security

  func test_readEndUserId_willNotIncludeJwtInErrorMessage() throws {
    let failing = [
      "not-a-jwt",
      "header.not!valid!base64.signature",
      AuthTestFixtures.jwt(claims: "this is not json {"),
      AuthTestFixtures.jwt(claims: "[\"user-1\"]"),
      AuthTestFixtures.jwt(claims: "{\"environmentId\":\"env-1\"}"),
      AuthTestFixtures.jwt(claims: "{\"endUserId\":\"\"}"),
      AuthTestFixtures.jwt(claims: "{\"endUserId\":619692}")
    ]

    for jwt in failing {
      let thrown = try self.captureError(from: jwt)
      let description = try XCTUnwrap(
        (thrown as? PortalAuthError)?.errorDescription,
        "Every failure must be a PortalAuthError with a description."
      )

      XCTAssertFalse(description.contains(jwt), "The error message must never echo the userJwt.")

      // Short segments are skipped: `[PortalAuth] …` incidentally contains one-character
      // substrings, which would make the assertion fail for the wrong reason.
      if let claims = jwt.split(separator: ".").dropFirst().first, claims.count >= 8 {
        XCTAssertFalse(
          description.contains(claims),
          "The error message must never echo the claims segment either."
        )
      }
    }

    XCTAssertTrue(
      self.logger.messages.isEmpty,
      "UserJwt must not log at all; it logged: \(self.logger.messages)"
    )
  }

  // MARK: - Helpers

  /// Asserts that `userJwt` is rejected as `PortalAuthError.invalidUserJwt`, optionally with an
  /// exact `detail`.
  ///
  /// The details are compared against `UserJwt`'s own constants rather than retyped literals,
  /// so a wording change is a one-line production edit and not a suite-wide rewrite — while
  /// still failing loudly if a *different* branch starts producing the error.
  private func assertThrowsInvalidUserJwt(
    _ userJwt: String,
    detail expectedDetail: String? = nil,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try UserJwt.readEndUserId(from: userJwt), message, file: file, line: line) { error in
      guard let authError = error as? PortalAuthError else {
        XCTFail("Expected a PortalAuthError but a \(type(of: error)) was thrown. \(message)", file: file, line: line)
        return
      }
      guard case let .invalidUserJwt(detail) = authError else {
        XCTFail("Expected .invalidUserJwt but got \(authError). \(message)", file: file, line: line)
        return
      }
      if let expectedDetail = expectedDetail {
        XCTAssertEqual(detail, expectedDetail, message, file: file, line: line)
      }
    }
  }

  /// Returns the error `readEndUserId(from:)` throws for `userJwt`, failing the test when it
  /// returns normally, so a case can assert on the message without an optional dance.
  private func captureError(
    from userJwt: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> Error {
    var captured: Error?
    XCTAssertThrowsError(
      try UserJwt.readEndUserId(from: userJwt),
      "Expected readEndUserId to reject this userJwt.",
      file: file,
      line: line
    ) { captured = $0 }

    return try XCTUnwrap(captured, "readEndUserId returned instead of throwing.", file: file, line: line)
  }

  /// Runs `readEndUserId(from:)` under a 2 s bound, carrying either result back as a value.
  ///
  /// A regression that makes the decoder quadratic then fails as an unwrap of `nil` instead of
  /// hanging the whole suite.
  private func boundedRead(
    _ userJwt: String,
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ReadEndUserIdOutcome {
    let outcome = try await AuthTestFixtures.withTimeout(timeout) { () -> ReadEndUserIdOutcome in
      do {
        let endUserId = try UserJwt.readEndUserId(from: userJwt)
        return .returned(endUserId)
      } catch let error as PortalAuthError {
        return .threw(error)
      }
    }

    return try XCTUnwrap(outcome, "readEndUserId did not finish within \(timeout) s.", file: file, line: line)
  }
}

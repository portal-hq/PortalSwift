//
//  PasskeyAuthEncodingTests.swift
//
//  Golden-vector tests for the base64url helpers used by PasskeyAuth
//  (SDK-166 / SDK-168 / BAC-162).
//
//  Background: the relying party server (trustless-backup-service) serializes
//  WebAuthn binary fields (user.id, challenge, credentialId, userHandle) as
//  base64url. Three separate client bugs of the same class (decoding the
//  base64url string with the wrong scheme, or not decoding it at all) shipped
//  across our passkey clients before these vectors existed. The vector bytes
//  below are deliberately NOT valid UTF-8, so a regression to the old
//  "UTF-8 bytes of the string" behavior fails these tests, and the second
//  vector contains '-' and '_' so a regression to standard-base64 decoding
//  fails as well.
//

@testable import PortalSwift
import XCTest

final class PasskeyAuthEncodingTests: XCTestCase {
  // base64url("AZFNK3uGcsipO5tuPfXN7w") <-> 01914d2b7b8672c8a93b9b6e3df5cdef
  let goldenVectorString = "AZFNK3uGcsipO5tuPfXN7w"
  let goldenVectorBytes = Data([
    0x01, 0x91, 0x4D, 0x2B, 0x7B, 0x86, 0x72, 0xC8,
    0xA9, 0x3B, 0x9B, 0x6E, 0x3D, 0xF5, 0xCD, 0xEF,
  ])

  func testGoldenVectorIsNotValidUTF8() throws {
    // Guards the vector itself: if these bytes were valid UTF-8, the test
    // could not distinguish correct decoding from the old mangled behavior.
    XCTAssertNil(String(data: goldenVectorBytes, encoding: .utf8))
  }

  func testDecodeBase64UrlProducesRawBytes() throws {
    let decoded = goldenVectorString.decodeBase64Url()
    XCTAssertEqual(decoded, goldenVectorBytes)
    XCTAssertEqual(decoded?.count, 16)
  }

  func testDecodeBase64UrlIsNotUTF8Encoding() throws {
    // The pre-SDK-166 registration path stored Data(user.id.utf8) — 22 ASCII
    // bytes of the string itself. Assert the helper output differs from that.
    let utf8Mangled = Data(goldenVectorString.utf8)
    XCTAssertNotEqual(goldenVectorString.decodeBase64Url(), utf8Mangled)
  }

  func testToBase64UrlRoundTrip() throws {
    XCTAssertEqual(goldenVectorBytes.toBase64Url(), goldenVectorString)
  }

  func testDecodeBase64UrlHandlesUrlSafeCharacters() throws {
    // 0xFB 0xEF 0xBE repeating encodes to "----" / "____" style output in the
    // two alphabets; this vector contains both '-' and '_' so a regression to
    // standard base64 decoding (which rejects or drops them) fails here.
    let bytes = Data([0xFB, 0xEF, 0xBE, 0xFF, 0xFF, 0xFE])
    let encoded = bytes.toBase64Url()
    XCTAssertTrue(encoded.contains("-") || encoded.contains("_"))
    XCTAssertEqual(encoded.decodeBase64Url(), bytes)
  }

  func testDecodeBase64UrlHandlesUnpaddedInput() throws {
    // 22-char base64url (16 bytes) has no '=' padding; the helper must pad
    // internally rather than reject.
    XCTAssertEqual(goldenVectorString.count % 4, 2)
    XCTAssertNotNil(goldenVectorString.decodeBase64Url())
  }
}

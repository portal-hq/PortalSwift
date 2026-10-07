//
//  PortalIdempotencyTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Pins the client half of the idempotency-key contract: the generator, the validator (which must
/// agree with Portal's `^[A-Za-z0-9._~-]+$`, 1–255 rule, applied after trimming), the error ids the
/// server uses, and the `PortalMpcError` helpers callers branch on.
final class PortalIdempotencyTests: XCTestCase {
  // MARK: - Header

  func test_header_isIdempotencyKey() {
    XCTAssertEqual(PORTAL_IDEMPOTENCY_KEY_HEADER, "Idempotency-Key")
  }

  // MARK: - generateIdempotencyKey()

  func test_generateIdempotencyKey_isLowercaseUuidV4() throws {
    let key = generateIdempotencyKey()

    XCTAssertEqual(key, key.lowercased())
    let uuid = try XCTUnwrap(UUID(uuidString: key), "The key must be a UUID.")
    XCTAssertEqual(uuid.uuidString.lowercased(), key)
    // xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx
    let characters = Array(key)
    XCTAssertEqual(characters.count, 36)
    XCTAssertEqual(characters[14], "4", "The version nibble must be 4.")
    XCTAssertTrue("89ab".contains(characters[19]), "The variant nibble must be RFC 4122.")
  }

  func test_generateIdempotencyKey_passesValidationUnchanged() throws {
    let key = generateIdempotencyKey()

    XCTAssertEqual(try validateIdempotencyKey(key), key)
  }

  func test_generateIdempotencyKey_isUniquePerCall() {
    let keys = Set((0 ..< 100).map { _ in generateIdempotencyKey() })

    XCTAssertEqual(keys.count, 100)
  }

  // MARK: - validateIdempotencyKey(_:)

  func test_validate_trimsSurroundingWhitespaceAndNewlines() throws {
    XCTAssertEqual(try validateIdempotencyKey("  key-1 "), "key-1")
    XCTAssertEqual(try validateIdempotencyKey("\n\tkey-1\r\n"), "key-1")
  }

  func test_validate_acceptsOneCharacter() throws {
    XCTAssertEqual(try validateIdempotencyKey("a"), "a")
  }

  func test_validate_accepts255Characters() throws {
    let key = String(repeating: "a", count: 255)

    XCTAssertEqual(try validateIdempotencyKey(key), key)
  }

  func test_validate_accepts255Characters_afterTrimming() throws {
    let key = String(repeating: "b", count: 255)

    XCTAssertEqual(try validateIdempotencyKey("  \(key)  "), key)
  }

  func test_validate_acceptsTheFullCharset() throws {
    let key = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-"

    XCTAssertEqual(try validateIdempotencyKey(key), key)
  }

  func test_validate_rejectsEmpty() {
    self.assertInvalid("", rule: Self.emptyRule)
  }

  func test_validate_rejectsWhitespaceOnly() {
    self.assertInvalid("   \n\t ", rule: Self.emptyRule)
  }

  func test_validate_rejects256Characters() {
    self.assertInvalid(String(repeating: "a", count: 256), rule: Self.lengthRule)
  }

  func test_validate_rejectsDisallowedCharacters() {
    // An inner space, a slash, a colon, a plus, a percent-escape, a non-ASCII letter and digit
    // (which `.alphanumerics` would admit), an emoji, a NUL byte, and inner CR/LF, tab and
    // vertical tab (only surrounding whitespace is trimmed).
    let keys = [
      "order 42", "order/42", "order:42", "order+42", "order%2042", "ordér-42", "order-٤٢", "order-🔑", "order\u{0}42",
      "order\r\n42", "order\t42", "order\u{000B}42"
    ]

    for key in keys {
      self.assertInvalid(key, rule: Self.charsetRule)
    }
  }

  func test_validate_trimsUnicodeSpaceSeparators() throws {
    // No-break space and ideographic space are whitespace to Portal's trim as well.
    XCTAssertEqual(try validateIdempotencyKey("\u{00A0}key-1\u{3000}"), "key-1")
  }

  func test_validate_trimsALeadingByteOrderMark() throws {
    // JavaScript's trim() removes U+FEFF, although Foundation's `.whitespacesAndNewlines` does not.
    XCTAssertEqual(try validateIdempotencyKey("\u{FEFF}key-1"), "key-1")
  }

  // MARK: - Shared trim vector (identical on Android)

  /// Every code point JavaScript's `String.prototype.trim()` removes. Portal trims a key with it,
  /// so these, and only these, are stripped from either end.
  private static let javaScriptTrimmedCodePoints: [String] = [
    "\u{0009}", "\u{000A}", "\u{000B}", "\u{000C}", "\u{000D}", "\u{0020}", "\u{00A0}", "\u{1680}",
    "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}", "\u{2007}",
    "\u{2008}", "\u{2009}", "\u{200A}", "\u{2028}", "\u{2029}", "\u{202F}", "\u{205F}", "\u{3000}",
    "\u{FEFF}"
  ]

  /// Code points JavaScript's `trim()` keeps, some of which Foundation would trim (U+0085, U+200B).
  private static let untrimmedCodePoints: [String] = ["\u{0085}", "\u{001C}", "\u{001F}", "\u{200B}"]

  func test_trimVector_hasTheTwentyFiveJavaScriptWhitespaceCodePoints() {
    XCTAssertEqual(Self.javaScriptTrimmedCodePoints.count, 25)
    XCTAssertTrue(Self.javaScriptTrimmedCodePoints.allSatisfy { $0.unicodeScalars.count == 1 })
    // Compared by scalar value: `String` equality is canonical, and U+2000 and U+2001 are
    // canonically equivalent to U+2002 and U+2003.
    let scalarValues = Self.javaScriptTrimmedCodePoints.flatMap { $0.unicodeScalars.map { $0.value } }
    XCTAssertEqual(Set(scalarValues).count, 25)
  }

  func test_trimVector_eachJavaScriptWhitespaceCodePoint_isTrimmedFromBothEnds() throws {
    for codePoint in Self.javaScriptTrimmedCodePoints {
      let label = Self.label(codePoint)

      XCTAssertEqual(try validateIdempotencyKey("\(codePoint)k-1\(codePoint)"), "k-1", label)
    }
  }

  func test_trimVector_noOtherScalarIsTrimmed() {
    // Every Basic Multilingual Plane scalar outside the 25, wrapped around "k-1", stays in the key:
    // an allowed character is accepted untrimmed and anything else fails the character check. This
    // pins the implemented set to exactly JavaScript's, so adding a code point to it fails here.
    // Every character Unicode or Foundation treats as whitespace is in the BMP, so the sweep stops
    // at U+FFFF, as on Android.
    let trimmed = Set(Self.javaScriptTrimmedCodePoints.flatMap { $0.unicodeScalars.map { $0.value } })
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-".unicodeScalars.map { $0.value })
    var mismatches: [String] = []

    for value in UInt32(0) ... 0xFFFF where !trimmed.contains(value) {
      guard let scalar = Unicode.Scalar(value) else {
        continue // A surrogate code point, which no String can hold.
      }
      let wrapper = String(Character(scalar))
      let wrapped = "\(wrapper)k-1\(wrapper)"
      do {
        let key = try validateIdempotencyKey(wrapped)
        if !allowed.contains(value) || key != wrapped {
          mismatches.append(String(format: "U+%04X", value))
        }
      } catch {
        if allowed.contains(value) || error as? PortalIdempotencyError != .invalidKey(Self.charsetRule) {
          mismatches.append(String(format: "U+%04X", value))
        }
      }
    }

    XCTAssertEqual(mismatches, [], "Trimmed or rejected differently from JavaScript's trim().")
  }

  func test_trimVector_codePointsOutsideJavaScriptTrim_areKept_andRejected() {
    for codePoint in Self.untrimmedCodePoints {
      self.assertInvalid("\(codePoint)k-1\(codePoint)", rule: Self.charsetRule)
    }
  }

  func test_trimVector_innerWhitespaceAndNul_areRejected() {
    for inner in ["\u{0020}", "\u{000D}", "\u{000A}", "\u{0009}", "\u{0000}"] {
      self.assertInvalid("k\(inner)1", rule: Self.charsetRule)
    }
  }

  func test_trimVector_255AsciiCharacters_areAccepted_and256Rejected() throws {
    let accepted = String(repeating: "a", count: 255)

    XCTAssertEqual(try validateIdempotencyKey(accepted), accepted)
    self.assertInvalid(String(repeating: "a", count: 256), rule: Self.lengthRule)
  }

  func test_trimVector_whitespaceOnly_isRejectedAsEmpty() {
    self.assertInvalid(Self.javaScriptTrimmedCodePoints.joined(), rule: Self.emptyRule)
    for codePoint in Self.javaScriptTrimmedCodePoints {
      self.assertInvalid(codePoint, rule: Self.emptyRule)
    }
  }

  private static func label(_ codePoint: String) -> String {
    codePoint.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined()
  }

  func test_validate_errorDescription_neverContainsTheKey() {
    let keys = ["secret key with spaces", String(repeating: "s", count: 300), "secret/slash"]

    for key in keys {
      do {
        _ = try validateIdempotencyKey(key)
        XCTFail("Expected \(key.count)-character input to be rejected.")
      } catch {
        XCTAssertFalse(error.localizedDescription.contains(key))
        XCTAssertFalse("\(error)".contains(key))
        if case let .invalidKey(rule) = error as? PortalIdempotencyError {
          XCTAssertFalse(rule.contains(key))
        } else {
          XCTFail("Expected PortalIdempotencyError.invalidKey, got \(error)")
        }
      }
    }
  }

  // MARK: - PortalIdempotencyError

  func test_error_descriptionsNameTheCase() {
    XCTAssertEqual(
      PortalIdempotencyError.invalidKey("rule").errorDescription,
      "PortalIdempotencyError.invalidKey - rule"
    )
    XCTAssertEqual(
      PortalIdempotencyError.unsupportedTarget("reason").errorDescription,
      "PortalIdempotencyError.unsupportedTarget - reason"
    )
  }

  func test_unsupportedRawBroadcast_namesTheMethod_andWhy() {
    XCTAssertEqual(
      PortalIdempotencyError.unsupportedRawBroadcast(.eth_sendRawTransaction),
      .unsupportedTarget("idempotencyKey is not supported for eth_sendRawTransaction; the signed transaction is broadcast by a plain RPC call that Portal cannot deduplicate")
    )
    // Named by the SDK case, not the wire name "sendTransaction".
    XCTAssertEqual(
      PortalIdempotencyError.unsupportedRawBroadcast(.sol_sendTransaction),
      .unsupportedTarget("idempotencyKey is not supported for sol_sendTransaction; the signed transaction is broadcast by a plain RPC call that Portal cannot deduplicate")
    )
  }

  func test_unsupportedBitcoinSendAsset_message() {
    XCTAssertEqual(
      PortalIdempotencyError.unsupportedBitcoinSendAsset.errorDescription,
      "PortalIdempotencyError.unsupportedTarget - idempotencyKey is not supported for Bitcoin sendAsset; the transaction is raw-signed and broadcast by the SDK"
    )
  }

  func test_error_isEquatable() {
    XCTAssertEqual(PortalIdempotencyError.invalidKey("a"), .invalidKey("a"))
    XCTAssertNotEqual(PortalIdempotencyError.invalidKey("a"), .invalidKey("b"))
    XCTAssertNotEqual(PortalIdempotencyError.invalidKey("a"), .unsupportedTarget("a"))
  }

  // MARK: - PortalIdempotencyErrorId

  func test_errorIds_matchTheServerIds() {
    XCTAssertEqual(PortalIdempotencyErrorId.requestInProgress, "IDEMPOTENT_REQUEST_IN_PROGRESS")
    XCTAssertEqual(PortalIdempotencyErrorId.requestAlreadyCompleted, "IDEMPOTENT_REQUEST_ALREADY_COMPLETED")
    XCTAssertEqual(PortalIdempotencyErrorId.requestPreviouslyFailed, "IDEMPOTENT_REQUEST_PREVIOUSLY_FAILED")
    XCTAssertEqual(PortalIdempotencyErrorId.requestUnexpectedState, "IDEMPOTENT_REQUEST_UNEXPECTED_STATE")
    XCTAssertEqual(PortalIdempotencyErrorId.keyReused, "IDEMPOTENCY_KEY_REUSED")
    XCTAssertEqual(PortalIdempotencyErrorId.txMissing, "IDEMPOTENT_TX_MISSING")
  }

  func test_errorIds_allHasSixIds() {
    XCTAssertEqual(PortalIdempotencyErrorId.all.count, 6)
    XCTAssertEqual(
      PortalIdempotencyErrorId.all,
      [
        "IDEMPOTENT_REQUEST_IN_PROGRESS",
        "IDEMPOTENT_REQUEST_ALREADY_COMPLETED",
        "IDEMPOTENT_REQUEST_PREVIOUSLY_FAILED",
        "IDEMPOTENT_REQUEST_UNEXPECTED_STATE",
        "IDEMPOTENCY_KEY_REUSED",
        "IDEMPOTENT_TX_MISSING"
      ]
    )
  }

  // MARK: - PortalMpcError helpers

  func test_isIdempotencyRejection_isTrueForEveryId() {
    for id in PortalIdempotencyErrorId.all {
      XCTAssertTrue(PortalMpcError(PortalError(id: id, message: "m")).isIdempotencyRejection, id)
    }
  }

  func test_isIdempotencyRejection_isFalseForOtherIds_nilAndLowercase() {
    let ids: [String?] = ["AUTH_FAILED", "SIGN_FAIL", nil, "idempotent_request_in_progress", "IDEMPOTENCY_KEY_REUSED ", ""]

    for id in ids {
      XCTAssertFalse(PortalMpcError(PortalError(id: id, message: nil)).isIdempotencyRejection, "id \(id ?? "nil")")
    }
  }

  func test_isIdempotencyKeyReused_isTrueOnlyForKeyReused() {
    XCTAssertTrue(PortalMpcError(PortalError(id: "IDEMPOTENCY_KEY_REUSED", message: nil)).isIdempotencyKeyReused)

    for id in PortalIdempotencyErrorId.all.subtracting(["IDEMPOTENCY_KEY_REUSED"]) {
      XCTAssertFalse(PortalMpcError(PortalError(id: id, message: nil)).isIdempotencyKeyReused, id)
    }
    XCTAssertFalse(PortalMpcError(PortalError(id: nil, message: nil)).isIdempotencyKeyReused)
    XCTAssertFalse(PortalMpcError(PortalError(id: "AUTH_FAILED", message: nil)).isIdempotencyKeyReused)
  }

  func test_authFailure_isNotAnIdempotencyRejection() {
    let error = PortalMpcError(PortalError(id: "AUTH_FAILED", message: nil))

    XCTAssertTrue(error.isAuthFailure)
    XCTAssertFalse(error.isIdempotencyRejection)
  }

  // MARK: - PortalRequestMethod.supportsIdempotencyKey

  func test_supportsIdempotencyKey_isTrueForTheThreeBroadcastMethods() {
    XCTAssertTrue(PortalRequestMethod.eth_sendTransaction.supportsIdempotencyKey)
    XCTAssertTrue(PortalRequestMethod.sol_signAndSendTransaction.supportsIdempotencyKey)
    XCTAssertTrue(PortalRequestMethod.sol_signAndConfirmTransaction.supportsIdempotencyKey)
  }

  func test_supportsIdempotencyKey_isFalseForOtherMethods() {
    let methods: [PortalRequestMethod] = [
      .eth_sendRawTransaction, .eth_signTransaction, .eth_sign, .personal_sign,
      .eth_signTypedData_v3, .eth_signTypedData_v4, .eth_signUserOperation,
      .sol_signMessage, .sol_signTransaction, .sol_sendTransaction, .rawSign,
      .eth_call, .eth_blockNumber, .wallet_getCapabilities
    ]

    for method in methods {
      XCTAssertFalse(method.supportsIdempotencyKey, method.rawValue)
    }
  }

  // MARK: - PortalRequestMethod.isRawBroadcast

  func test_isRawBroadcast_isTrueForTheTwoRawBroadcastMethods() {
    XCTAssertTrue(PortalRequestMethod.eth_sendRawTransaction.isRawBroadcast)
    XCTAssertTrue(PortalRequestMethod.sol_sendTransaction.isRawBroadcast)
    XCTAssertEqual(PortalRequestMethod.sol_sendTransaction.rawValue, "sendTransaction")
  }

  func test_isRawBroadcast_isFalseForOtherMethods() {
    let methods: [PortalRequestMethod] = [
      .eth_sendTransaction, .sol_signAndSendTransaction, .sol_signAndConfirmTransaction,
      .eth_signTransaction, .sol_signTransaction, .eth_signUserOperation, .rawSign,
      .sol_simulateTransaction, .sol_requestAirdrop, .eth_call, .eth_getTransactionReceipt, .wallet_getCapabilities
    ]

    for method in methods {
      XCTAssertFalse(method.isRawBroadcast, method.rawValue)
    }
  }

  func test_rawBroadcasts_areNeverSignedByPortal() throws {
    // A raw broadcast is relayed to RPC, never signed, which is why Portal cannot deduplicate it.
    for chainId in ["eip155:1", "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", "bip122:000000000019d6689c085ae165831e93-p2wpkh"] {
      let blockchain = try PortalBlockchain(fromChainId: chainId)

      XCTAssertFalse(blockchain.shouldMethodBeSigned(.eth_sendRawTransaction), chainId)
      XCTAssertFalse(blockchain.shouldMethodBeSigned(.sol_sendTransaction), chainId)
    }
  }

  // MARK: - RequestOptions

  func test_requestOptions_idempotencyKeyDefaultsToNil() {
    XCTAssertNil(RequestOptions().idempotencyKey)
    XCTAssertNil(RequestOptions(signatureApprovalMemo: "m", sponsorGas: true, traceId: "t").idempotencyKey)
  }

  func test_requestOptions_storesIdempotencyKey() {
    let options = RequestOptions(signatureApprovalMemo: "m", sponsorGas: false, traceId: "t", idempotencyKey: "order-42")

    XCTAssertEqual(options.signatureApprovalMemo, "m")
    XCTAssertEqual(options.sponsorGas, false)
    XCTAssertEqual(options.traceId, "t")
    XCTAssertEqual(options.idempotencyKey, "order-42")
  }

  func test_requestOptions_decodesWithoutIdempotencyKey() throws {
    let json = Data(#"{"signatureApprovalMemo":"m","traceId":"t"}"#.utf8)

    let options = try JSONDecoder().decode(RequestOptions.self, from: json)

    XCTAssertEqual(options.signatureApprovalMemo, "m")
    XCTAssertNil(options.idempotencyKey)
  }

  // MARK: - Helpers

  /// The rule texts `invalidKey` carries, identical on Android.
  private static let emptyRule = "idempotencyKey must not be empty or whitespace-only"
  private static let lengthRule = "idempotencyKey must be at most 255 characters"
  private static let charsetRule = "idempotencyKey may only contain the characters A-Z, a-z, 0-9, '.', '_', '~' and '-'"

  private func assertInvalid(
    _ key: String,
    rule expectedRule: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try validateIdempotencyKey(key), file: file, line: line) { error in
      guard case let .invalidKey(rule) = error as? PortalIdempotencyError else {
        XCTFail("Expected PortalIdempotencyError.invalidKey, got \(error)", file: file, line: line)
        return
      }
      XCTAssertEqual(rule, expectedRule, file: file, line: line)
    }
  }
}

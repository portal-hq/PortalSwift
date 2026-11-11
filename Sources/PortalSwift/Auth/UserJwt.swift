//
//  UserJwt.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Reads the `endUserId` claim out of a `userJwt`.
///
/// `POST /auth/totps/validations` returns only a `clientSessionToken`, but a `PortalSession`
/// is identified by its end user — and `PortalAuth.verifyTotp(_:userJwt:)` takes nothing else
/// that carries one. The claim is read, never trusted: it labels the session locally, and
/// every authenticated call is still authorised server-side against the session token. No
/// signature verification happens here and none is wanted — the SDK does not hold the
/// per-environment secret, and a forged label buys an attacker nothing the session token does
/// not already gate.
///
/// The error details are fixed literals so `errorDescription` never echoes the JWT.
enum UserJwt {
  /// The JWT has fewer than two `.`-separated segments.
  static let malformedDetail = "The provided userJwt is malformed."
  /// The claims segment contains a character outside the base64 / base64url alphabets.
  static let notBase64UrlDetail = "The userJwt is not valid base64url."
  /// The claims segment decoded, but not to a UTF-8 JSON object.
  static let unreadableClaimsDetail = "Unable to read the claims of the userJwt."
  /// The claims object has no `endUserId`, or it is not a non-blank string.
  static let missingEndUserIdDetail = "The userJwt does not carry an endUserId."

  /// Returns the `endUserId` claim of `userJwt`.
  ///
  /// Accepts both the base64url and the standard base64 alphabet, padded or not, and reads
  /// `segments[1]` only — the header and signature are ignored. A blank claim is rejected
  /// like a missing one (stricter than Android) because a session labelled `" "` would be
  /// persisted successfully and then be useless. A numeric claim is rejected rather than
  /// stringified: `619692` must never become `"619692"` or `"619692.0"`.
  ///
  /// - Throws: `PortalAuthError.invalidUserJwt(detail:)` with one of the four detail constants.
  static func readEndUserId(from userJwt: String) throws -> String {
    let segments = userJwt.split(separator: ".", omittingEmptySubsequences: false)
    guard segments.count >= 2 else {
      throw PortalAuthError.invalidUserJwt(detail: self.malformedDetail)
    }

    let claimsBytes = try self.decodeBase64Url(segments[1])

    guard let claimsText = String(bytes: claimsBytes, encoding: .utf8),
          let claimsData = claimsText.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: claimsData),
          let claims = json as? [String: Any]
    else {
      throw PortalAuthError.invalidUserJwt(detail: self.unreadableClaimsDetail)
    }

    // `as? String` is `nil` for an `NSNumber` (a JSON number or boolean), so a non-string
    // claim falls through to the same rejection as a missing one.
    guard let endUserId = claims["endUserId"] as? String,
          !endUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw PortalAuthError.invalidUserJwt(detail: self.missingEndUserIdDetail)
    }

    return endUserId
  }

  // MARK: - Base64url

  /// Decodes a base64 / base64url segment.
  ///
  /// Hand-rolled rather than `Data(base64Encoded:)`: Foundation's decoder rejects the
  /// base64url alphabet and unpadded input outright, and its behaviour on mixed alphabets is
  /// undocumented. Padding is optional and stripped with a linear walk from the end, so a
  /// hostile run of 200,000 `=` costs one pass. Bits that do not complete a byte are dropped,
  /// matching every other Portal SDK.
  private static func decodeBase64Url(_ segment: Substring) throws -> [UInt8] {
    var end = segment.endIndex
    while end > segment.startIndex {
      let previous = segment.index(before: end)
      guard segment[previous] == "=" else {
        break
      }
      end = previous
    }
    let body = segment[..<end]

    var bytes: [UInt8] = []
    bytes.reserveCapacity(body.utf8.count * 3 / 4 + 1)
    var buffer: UInt32 = 0
    var bits = 0

    for byte in body.utf8 {
      guard let sextet = self.sextet(for: byte) else {
        throw PortalAuthError.invalidUserJwt(detail: self.notBase64UrlDetail)
      }

      buffer = (buffer << 6 | UInt32(sextet)) & 0xFFFF
      bits += 6

      if bits >= 8 {
        bits -= 8
        bytes.append(UInt8(truncatingIfNeeded: buffer >> UInt32(bits)))
      }
    }

    return bytes
  }

  /// The 6-bit value of one base64 character, accepting both alphabets (`+`/`-` and `/`/`_`).
  private static func sextet(for byte: UInt8) -> UInt8? {
    switch byte {
    case UInt8(ascii: "A") ... UInt8(ascii: "Z"):
      return byte - UInt8(ascii: "A")
    case UInt8(ascii: "a") ... UInt8(ascii: "z"):
      return byte - UInt8(ascii: "a") + 26
    case UInt8(ascii: "0") ... UInt8(ascii: "9"):
      return byte - UInt8(ascii: "0") + 52
    case UInt8(ascii: "+"), UInt8(ascii: "-"):
      return 62
    case UInt8(ascii: "/"), UInt8(ascii: "_"):
      return 63
    default:
      return nil
    }
  }
}

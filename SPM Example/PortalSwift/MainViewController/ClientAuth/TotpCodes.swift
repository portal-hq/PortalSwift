//
//  TotpCodes.swift
//  PortalSwift
//
//  RFC 6238 TOTP, for the example app only.
//

// ─────────────────────────────────────────────────────────────────────────────────────────
//  ⚠️  TEST AFFORDANCE ONLY — DO NOT COPY THIS FILE INTO A PRODUCTION APP  ⚠️
//
//  Deriving a TOTP code from the enrolment secret is exactly what a real app must never do:
//  it defeats the second factor by holding both factors on one device. This exists so the
//  Client Auth flow can be demoed and manually tested without provisioning an authenticator
//  app per test account, mirroring the Android example's `TotpCodes.kt` and the React Native
//  example's `src/lib/totp.ts`. A production integration collects the code from the user and
//  never stores, transports or derives from the secret.
//
//  The same warning applies to anything that puts the secret on the pasteboard.
// ─────────────────────────────────────────────────────────────────────────────────────────

import CryptoKit
import Foundation

/// RFC 6238 defaults, and what the Portal backend's enrolment URIs use.
private let totpStepSeconds: Int64 = 30
private let totpDigits = 6

/// The `secret=` query parameter, matched case-insensitively (Android's regex carries
/// `IGNORE_CASE`) without a regular expression, so a 200k-character paste stays linear.
private let totpSecretParameterName = "secret="

/// The current code and how long it stays valid.
///
/// `secondsRemaining` is surfaced so a tester knows whether to submit or regenerate.
struct TotpCode: Equatable {
  let code: String
  let secondsRemaining: Int
}

/// Why a value could not be turned into a code.
///
/// The messages never echo the input: they are shown through the screen's result label, and
/// the pasted material is an enrolment link or a live shared secret.
enum TotpCodeError: LocalizedError, Equatable {
  /// Nothing in the value parsed as a base32 secret.
  case noSecret
  /// A character outside the base32 alphabet reached the decoder.
  case invalidBase32Character(Character)

  var errorDescription: String? {
    switch self {
    case .noSecret:
      return "No base32 TOTP secret found in the provided value."
    case let .invalidBase32Character(character):
      return "Invalid base32 character: \(character)"
    }
  }
}

/// Derives the code for `nowMs`.
///
/// `nowMs` is a parameter rather than a `Date()` call inside so the RFC 6238 reference
/// vectors are assertable. `Int64` throughout: vector T = 20000000000 overflows `Int32`
/// milliseconds, and a 32-bit intermediate would make the shift arithmetic quietly wrong.
///
/// The `digits` and `period` parameters of an `otpauth://` URI are deliberately ignored — six
/// digits and a 30-second step, matching the Android and React Native examples.
///
/// - Throws: `TotpCodeError.noSecret` when the value carries no usable base32 secret, or
///   `TotpCodeError.invalidBase32Character` when the secret does not decode.
func generateTotpCode(
  _ secretOrLink: String,
  nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
) throws -> TotpCode {
  guard let secret = extractTotpSecret(secretOrLink) else {
    throw TotpCodeError.noSecret
  }

  let key = try base32Decode(secret)
  let seconds = nowMs / 1000
  let digest = hmacSha1(key: key, message: counterBytes(seconds / totpStepSeconds))
  let binary = dynamicTruncation(digest)

  return TotpCode(
    code: zeroPadded(binary % 1_000_000, to: totpDigits),
    secondsRemaining: Int(totpStepSeconds - (seconds % totpStepSeconds))
  )
}

/// Pulls the base32 secret out of either an `otpauth://` enrolment URI or a bare secret.
///
/// Both are accepted because the two TOTP states hand the app different things: first-time
/// enrolment returns a full `totpLink`, while an already-enrolled user gets `nil` and the
/// tester pastes whatever secret they saved. Returns `nil` rather than throwing — this reads
/// a text field that is empty or half-typed most of the time.
///
/// The returned secret is trimmed and upper-cased, and always matches `^[A-Z2-7]+=*$`.
func extractTotpSecret(_ value: String) -> String? {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    return nil
  }

  // A percent-encoded URI is tried as well as the raw one: the secret parameter itself is
  // base32 and never needs encoding, but the URI carrying it may arrive encoded whole.
  var candidates = [trimmed]
  if let decoded = percentDecodedOrNull(trimmed) {
    candidates.append(decoded)
  }

  for candidate in candidates {
    let secret = (firstSecretParameterValue(in: candidate).map(String.init) ?? candidate).uppercased()
    if isBase32SecretShaped(secret) {
      return secret
    }
  }

  return nil
}

/// Decodes base32 (RFC 4648) into bytes, ignoring whitespace and case and stripping trailing
/// padding. Partial trailing bits are discarded, as the specification requires.
///
/// - Throws: `TotpCodeError.invalidBase32Character` on a character outside the alphabet. Only
///   trailing `=` is padding: a `=` in the middle is a rejected character.
func base32Decode(_ value: String) throws -> [UInt8] {
  var cleaned = ""
  cleaned.reserveCapacity(value.count)
  for character in value where !character.isWhitespace {
    cleaned.append(character)
  }
  while cleaned.last == "=" {
    cleaned.removeLast()
  }
  let normalized = cleaned.uppercased()

  var bytes = [UInt8]()
  bytes.reserveCapacity(normalized.count * 5 / 8)
  var buffer = 0
  var bits = 0

  for character in normalized {
    guard let index = base32AlphabetIndex(of: character) else {
      throw TotpCodeError.invalidBase32Character(character)
    }

    // Masked to 12 bits: `bits` is at most 7 before a character is folded in, so nothing
    // meaningful is ever above bit 11 and the accumulator cannot drift on a long input.
    buffer = ((buffer << 5) | index) & 0xFFF
    bits += 5

    if bits >= 8 {
      bits -= 8
      bytes.append(UInt8((buffer >> bits) & 0xFF))
    }
  }

  return bytes
}

/// The percent-decoded form of `value`, or `nil` when it is not percent-encoded, does not
/// decode, or decodes to itself — a value identical to the input is not worth offering as a
/// second candidate.
func percentDecodedOrNull(_ value: String) -> String? {
  guard value.contains(where: { $0 == "%" }) else {
    return nil
  }
  guard let decoded = value.removingPercentEncoding, decoded != value else {
    return nil
  }
  return decoded
}

// MARK: - Private

/// The first non-empty `?secret=` / `&secret=` parameter value, matched case-insensitively on
/// the parameter name. Mirrors Kotlin's `Regex("[?&]secret=([^&]+)", IGNORE_CASE)`, including
/// its skip over an empty value: `[^&]+` cannot match nothing, so the engine moves on.
///
/// Hand-rolled rather than `NSRegularExpression` so the scan is a single linear pass — the
/// screen feeds this field's contents in on every keystroke.
private func firstSecretParameterValue(in value: String) -> Substring? {
  var index = value.startIndex

  while index < value.endIndex {
    let character = value[index]
    if character == "?" || character == "&",
       let valueStart = indexAfterSecretParameterName(in: value, from: value.index(after: index))
    {
      var end = valueStart
      while end < value.endIndex, value[end] != "&" {
        end = value.index(after: end)
      }
      if end > valueStart {
        return value[valueStart ..< end]
      }
    }
    index = value.index(after: index)
  }

  return nil
}

/// The index just past a case-insensitive `secret=` starting at `start`, or `nil`.
private func indexAfterSecretParameterName(in value: String, from start: String.Index) -> String.Index? {
  var index = start

  for expected in totpSecretParameterName {
    guard index < value.endIndex, asciiLowercased(value[index]) == expected else {
      return nil
    }
    index = value.index(after: index)
  }

  return index
}

/// `^[A-Z2-7]+=*$` without a regular expression: at least one alphabet character, then
/// padding only at the end.
private func isBase32SecretShaped(_ value: String) -> Bool {
  var sawSymbol = false
  var sawPadding = false

  for scalar in value.unicodeScalars {
    switch scalar {
    case "A" ... "Z", "2" ... "7":
      if sawPadding {
        return false
      }
      sawSymbol = true
    case "=":
      sawPadding = true
    default:
      return false
    }
  }

  return sawSymbol
}

/// The RFC 4648 alphabet position of `character`, or `nil` when it is outside it. `0`, `1` and
/// `8` are look-alikes the alphabet deliberately omits, so they read as invalid.
private func base32AlphabetIndex(of character: Character) -> Int? {
  guard let ascii = character.asciiValue else {
    return nil
  }

  switch ascii {
  case UInt8(ascii: "A") ... UInt8(ascii: "Z"):
    return Int(ascii - UInt8(ascii: "A"))
  case UInt8(ascii: "2") ... UInt8(ascii: "7"):
    return Int(ascii - UInt8(ascii: "2")) + 26
  default:
    return nil
  }
}

/// ASCII-only lowering: the parameter name is ASCII, and Unicode case folding on a 200k-character
/// paste would be both slower and wrong (a Turkish dotless I must not match `i`).
private func asciiLowercased(_ character: Character) -> Character {
  guard let ascii = character.asciiValue,
        ascii >= UInt8(ascii: "A"), ascii <= UInt8(ascii: "Z")
  else {
    return character
  }
  return Character(UnicodeScalar(ascii + 32))
}

/// The moving factor as 8 big-endian bytes.
private func counterBytes(_ counter: Int64) -> [UInt8] {
  (0 ..< 8).map { index in
    UInt8(truncatingIfNeeded: counter >> Int64((7 - index) * 8))
  }
}

/// HMAC-SHA1 via CryptoKit. `Insecure.SHA1` is the correct primitive here despite the name:
/// RFC 6238's default is HMAC-SHA1, and it is what the Portal backend's enrolment URIs specify.
private func hmacSha1(key: [UInt8], message: [UInt8]) -> [UInt8] {
  let code = HMAC<Insecure.SHA1>.authenticationCode(for: Data(message), using: SymmetricKey(data: Data(key)))
  return Array(code)
}

/// Dynamic truncation (RFC 4226 §5.4): the low nibble of the last byte picks the 4-byte window,
/// and the top bit is masked off so the result is positive regardless of platform signedness.
private func dynamicTruncation(_ digest: [UInt8]) -> Int {
  guard let lastByte = digest.last, digest.count >= 4 else {
    return 0
  }

  // HMAC-SHA1 is always 20 bytes, so `min` never binds; it is here so the window can never be
  // read out of bounds if the primitive is ever swapped.
  let offset = min(Int(lastByte & 0x0F), digest.count - 4)

  return (Int(digest[offset] & 0x7F) << 24)
    | (Int(digest[offset + 1]) << 16)
    | (Int(digest[offset + 2]) << 8)
    | Int(digest[offset + 3])
}

/// Left-pads with zeros: a code below 100000 is still six digits.
private func zeroPadded(_ value: Int, to width: Int) -> String {
  let text = String(value)
  guard text.count < width else {
    return text
  }
  return String(repeating: "0", count: width - text.count) + text
}

//
//  TotpQr.swift
//  PortalSwift
//
//  The scannable-payload gate and display grouping for the TOTP enrolment link.
//

import Foundation

/// The scheme every enrolment URI the backend returns carries.
private let otpauthScheme = "otpauth://"

/// Base32 groups of four, the grouping an authenticator's manual-entry field displays.
private let totpSecretGroupSize = 4

/// The exact URI to encode as a QR, or `nil` when the value holds nothing an authenticator
/// can scan.
///
/// One function answers both "is the control live" and "what goes into the symbol", so the
/// button's enabled state and the encoded payload cannot drift apart — they are the same
/// decision.
///
/// Two conditions, both load-bearing. A full `otpauth://` URI is required because that is what
/// carries the issuer and account label a scan needs; a bare secret, which is what an
/// already-enrolled account makes the tester paste, encodes into a QR no authenticator
/// accepts. And the secret still has to parse, so a link with a missing or non-base32
/// `secret=` leaves the control dead rather than rendering a code that fails later, inside the
/// authenticator, where the cause is invisible.
///
/// The image itself is the SDK's job (`TotpRequiredResult.qrCodeImage(scale:)` /
/// `portalTotpQrCodeImage(otpAuthUrl:scale:)`); the example never renders its own.
func scannableTotpPayload(_ value: String) -> String? {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    return nil
  }

  // A link can arrive percent-encoded whole — copied out of a redirect parameter or a URL bar.
  // The decoded form is what an authenticator has to receive, so it is the form that gets
  // encoded, not the one that was pasted.
  let link: String
  if hasOtpauthScheme(trimmed) {
    link = trimmed
  } else if let decoded = percentDecodedOrNull(trimmed), hasOtpauthScheme(decoded) {
    link = decoded
  } else {
    return nil
  }

  guard extractTotpSecret(link) != nil else {
    return nil
  }

  return link
}

/// Whether the value can be rendered as a QR. See `scannableTotpPayload(_:)`.
func isScannableTotpLink(_ value: String) -> Bool {
  scannableTotpPayload(value) != nil
}

/// Groups a base32 secret in fours for display.
///
/// Display only, and never what the pasteboard gets: a setup field accepts the unspaced form.
/// Case is preserved for the same reason — this formats whatever it is handed rather than
/// normalising it.
func formatTotpSecret(_ secret: String) -> String {
  var grouped = ""
  grouped.reserveCapacity(secret.count + secret.count / totpSecretGroupSize)
  var count = 0

  for character in secret {
    if count > 0, count % totpSecretGroupSize == 0 {
      grouped.append(" ")
    }
    grouped.append(character)
    count += 1
  }

  return grouped
}

// MARK: - Private

/// A case-insensitive `otpauth://` prefix check, without a regular expression and without
/// lower-casing a 200k-character paste.
private func hasOtpauthScheme(_ value: String) -> Bool {
  value.prefix(otpauthScheme.count).lowercased() == otpauthScheme
}

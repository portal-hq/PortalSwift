//
//  TotpUiState.swift
//  PortalSwift
//
//  Which TOTP controls on the Client Auth screen are live.
//

import Foundation

/// The shortest code any RFC 6238 authenticator emits. Portal's enrolment URIs specify six.
private let minimumTotpCodeLength = 6

/// Which TOTP controls are live.
///
/// - `isSectionEnabled`: a login is waiting on a code. False until `resolveTotpUiState` is
///   given a pending `userJwt`, which is the only thing that can put the flow in this state —
///   a TOTP requirement is not observable from `getMethods()`.
/// - `canDeriveCode`: a usable base32 secret is present, so a code can be derived in-app.
/// - `canCopySecret`: shares `canDeriveCode`'s condition — both need a secret this app can
///   parse — but they are separate properties because they gate separate controls.
/// - `canCopyLink`: there is something in the link field to put on the pasteboard.
/// - `canShowQr`: the field holds a full `otpauth://` link, so it can be rendered as a QR. A
///   narrower condition than `canCopyLink`, which any non-blank value satisfies: a pasted bare
///   secret is copyable but not scannable.
/// - `canSubmitCode`: the code field holds something worth spending a round trip on.
struct TotpUiState: Equatable {
  let isSectionEnabled: Bool
  let canDeriveCode: Bool
  let canCopySecret: Bool
  let canCopyLink: Bool
  let canShowQr: Bool
  let canSubmitCode: Bool
}

/// Resolves the TOTP controls from the three values the screen holds.
///
/// Kept a pure function so enablement is testable as a value, where the same logic scattered
/// across `isEnabled` assignments in a view controller is not.
///
/// Every control is gated on `pendingUserJwt` as well as its own condition, so nothing in the
/// section can be operated before a login has actually asked for a code — which is what makes
/// the section safe to render inert from the start rather than hiding it.
func resolveTotpUiState(pendingUserJwt: String?, secretOrLink: String, code: String) -> TotpUiState {
  // Blank, not merely empty: the SDK never issues a blank JWT, so whitespace in that slot is a
  // bug rather than a pending login, and it must not open the section.
  let isSectionEnabled = !(pendingUserJwt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

  // Absent on an already-enrolled account, where the backend sends no `totpLink` — the tester
  // pastes a saved secret instead, and until they do there is nothing to derive from or copy.
  let hasSecret = isSectionEnabled && extractTotpSecret(secretOrLink) != nil
  let hasLink = isSectionEnabled && !secretOrLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

  return TotpUiState(
    isSectionEnabled: isSectionEnabled,
    canDeriveCode: hasSecret,
    canCopySecret: hasSecret,
    canCopyLink: hasLink,
    canShowQr: isSectionEnabled && isScannableTotpLink(secretOrLink),
    canSubmitCode: isSectionEnabled && isSubmittableTotpCode(code)
  )
}

/// A code worth sending: ASCII digits only, and at least as long as the shortest one an
/// authenticator produces.
///
/// Deliberately not "exactly six": the length is an enrolment property an environment can set
/// to eight, and a client-side gate that disagrees with the backend would block a code the user
/// read correctly. Rejecting empty and non-numeric input is the part that saves a pointless
/// round trip.
///
/// ASCII specifically: `Character.isNumber` accepts Arabic-Indic digits and other Unicode
/// numerals the backend will reject, so accepting them would turn a client-side gate into a
/// confusing server error.
func isSubmittableTotpCode(_ code: String) -> Bool {
  let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
  var count = 0

  for scalar in trimmed.unicodeScalars {
    guard scalar >= "0", scalar <= "9" else {
      return false
    }
    count += 1
  }

  return count >= minimumTotpCodeLength
}

//
//  PortalCredentialSource.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// Which credential a `Portal` should be built from.
///
/// `Equatable` by session **identity**, not by token: two sessions are the same session only
/// when they are the same object, and comparing them any other way would mean reading
/// `getToken()` — which this type deliberately never does.
enum PortalCredentialSource: Equatable {
  /// A Client Auth session; `Portal(credentials:)`.
  case session(PortalSession)
  /// A custodian-issued Client API Key; `Portal(_:)`.
  case apiKey(String)

  static func == (lhs: PortalCredentialSource, rhs: PortalCredentialSource) -> Bool {
    switch (lhs, rhs) {
    case let (.session(left), .session(right)):
      return left === right
    case let (.apiKey(left), .apiKey(right)):
      return left == right
    case (.session, .apiKey), (.apiKey, .session):
      return false
    }
  }
}

/// A Client Auth session wins when both are present.
///
/// That precedence is only safe because the main screen clears its session on a custodian
/// sign-in — see `clearClientAuthSession()`. Without that, a session restored at launch would
/// silently outrank every subsequent sign-in.
///
/// A blank `clientApiKey` reads as *absent*, not as an empty credential. Client Auth adoption
/// synthesizes a `UserResult` with `clientApiKey = ""` — the session is the credential there —
/// so without this check, signing out of Client Auth leaves that user behind and the next
/// `registerPortal()` reaches `Portal("")`, which throws
/// `PortalCredentialError.invalidApiKey`. Returning `nil` instead makes `registerPortal()`
/// take its existing early return.
///
/// A non-blank key is passed through verbatim, whitespace and all: the server decides what a
/// valid key looks like, and trimming one here would only hide a mistyped secret behind a
/// confusing 401.
func resolveCredentialSource(clientAuthSession: PortalSession?, user: UserResult?) -> PortalCredentialSource? {
  if let clientAuthSession {
    return .session(clientAuthSession)
  }

  if let user, !isBlankCredentialSourceValue(user.clientApiKey) {
    return .apiKey(user.clientApiKey)
  }

  return nil
}

/// Whether this credential source can eject a wallet.
///
/// Eject needs material only a custodian holds — the org share via `org-share/fetch`, and
/// `prepare-eject` — both addressed by an `exchangeUserId` the demo custodian issued against
/// its own API key. A Client Auth session has no way to obtain either, so eject is the one
/// operation here that is genuinely custodian-only.
///
/// Deliberately independent of wallet state: eject is refused for what the *session* cannot
/// reach, not for what this device happens to hold. `nil` — signed out — can do nothing.
func canEjectWallet(_ source: PortalCredentialSource?) -> Bool {
  if case .apiKey = source {
    return true
  }

  return false
}

/// Which auth controls are live, given the credentials currently held.
struct AuthUiState: Equatable {
  /// The custodian email/password sign-in can be started.
  let canSignInWithCustodian: Bool
  /// The Client Auth screen can be opened to sign in.
  let canSignInWithClientAuth: Bool
  /// The custodian sign-out is meaningful.
  let canSignOutCustodian: Bool
  /// The Client Auth sign-out is meaningful.
  let canSignOutClientAuth: Bool
}

/// Resolves the auth controls from the same two inputs `resolveCredentialSource(clientAuthSession:user:)`
/// reads, so what the screen offers and what `Portal` was built from can never disagree.
///
/// The two login methods are mutually exclusive: whichever one is in use, the other is offered
/// only after signing out of it. That includes a session restored at launch.
///
/// Custodian sign-in is judged by a non-blank `clientApiKey`, not by `user != nil`, for the
/// reason in `resolveCredentialSource(clientAuthSession:user:)`: Client Auth adoption
/// synthesizes a blank-key `UserResult`, and treating that as a custodian login would offer a
/// "Custodian Sign Out" for a login that never happened — and leave one behind after a Client
/// Auth sign-out, since that user object outlives the session.
func resolveAuthUiState(clientAuthSession: PortalSession?, user: UserResult?) -> AuthUiState {
  let clientAuthSignedIn = clientAuthSession != nil
  let custodianSignedIn = !clientAuthSignedIn && !isBlankCredentialSourceValue(user?.clientApiKey ?? "")
  let signedOut = !clientAuthSignedIn && !custodianSignedIn

  return AuthUiState(
    canSignInWithCustodian: signedOut,
    canSignInWithClientAuth: signedOut,
    canSignOutCustodian: custodianSignedIn,
    canSignOutClientAuth: clientAuthSignedIn
  )
}

/// `true` for an empty or whitespace-only value, which is unusable as a bearer either way.
private func isBlankCredentialSourceValue(_ value: String) -> Bool {
  value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

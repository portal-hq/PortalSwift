//
//  SessionStateGoogleAuth.swift
//
//
//  Created by Ahmed Ragab Issa on 8/26/26.
//

import Foundation
import GoogleSignIn
@testable import PortalSwift

/// Models GIDSignIn's session state at the GoogleAuth seam — `GIDGoogleUser` is
/// not constructible in tests — so tests can drive the real `getAccessToken()`
/// and `recoverFromRejectedAccessToken()` logic across sign-out and fresh
/// sign-in transitions:
/// - `hasPreviousSignIn()` reflects `hasSession`; `signOut()` really clears it.
/// - While a session exists, the silent path returns `silentToken` or throws
///   `silentError`; without one it fails like GIDSignIn (`hasNoAuthInKeychain`).
/// - A fresh sign-in yields `interactiveToken` and re-establishes the session
///   (later silent restores return that token), or throws `signInError`.
/// - `events` records the order of `restore` / `signOut` / `signIn` steps.
final class SessionStateGoogleAuth: GoogleAuth {
  var hasSession: Bool
  var silentToken: String
  var silentError: Error?
  var interactiveToken: String?
  var signInError: Error = NSError(domain: GIDSignInError.errorDomain, code: GIDSignInError.Code.canceled.rawValue)
  private(set) var events: [String] = []

  var restoreCallsCount: Int { events.filter { $0 == "restore" }.count }
  var signOutCallsCount: Int { events.filter { $0 == "signOut" }.count }
  var signInCallsCount: Int { events.filter { $0 == "signIn" }.count }

  init(
    hasSession: Bool = true,
    silentToken: String = "",
    silentError: Error? = nil,
    interactiveToken: String? = nil
  ) {
    self.hasSession = hasSession
    self.silentToken = silentToken
    self.silentError = silentError
    self.interactiveToken = interactiveToken
    super.init(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }

  override func hasPreviousSignIn() -> Bool {
    return hasSession
  }

  override func signOut() {
    events.append("signOut")
    hasSession = false
  }

  override func restoreAccessToken() async throws -> String {
    events.append("restore")
    guard hasSession else {
      throw NSError(domain: GIDSignInError.errorDomain, code: GIDSignInError.Code.hasNoAuthInKeychain.rawValue)
    }
    if let silentError {
      throw silentError
    }
    return silentToken
  }

  override func signInForAccessToken() async throws -> String {
    events.append("signIn")
    guard let interactiveToken else {
      throw signInError
    }
    hasSession = true
    silentToken = interactiveToken
    silentError = nil
    return interactiveToken
  }
}

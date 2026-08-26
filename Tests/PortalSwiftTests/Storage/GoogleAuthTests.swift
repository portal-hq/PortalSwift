//
//  GoogleAuthTests.swift
//
//
//  Created by Ahmed Ragab Issa on 8/22/26.
//

import GoogleSignIn
@testable import PortalSwift
import XCTest

final class GoogleAuthTests: XCTestCase {}

// MARK: - missingScopes tests

extension GoogleAuthTests {
  func test_missingScopes_returnsAllRequired_whenNothingGranted() {
    XCTAssertEqual(
      GoogleAuth.missingScopes(required: ["a", "b"], granted: nil),
      ["a", "b"]
    )
    XCTAssertEqual(
      GoogleAuth.missingScopes(required: ["a", "b"], granted: []),
      ["a", "b"]
    )
  }

  func test_missingScopes_returnsEmpty_whenGrantMatchesExactly() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a", "b"], granted: ["a", "b"]), [])
  }

  func test_missingScopes_returnsEmpty_whenGrantIsSuperset() {
    // A user who consented under a wider backup option must not be re-prompted.
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a"], granted: ["a", "b", "c"]), [])
  }

  func test_missingScopes_returnsOnlyTheGap_whenGrantIsPartial() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a", "b", "c"], granted: ["b"]), ["a", "c"])
  }

  func test_missingScopes_returnsEmpty_whenNothingRequired() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: [], granted: nil), [])
  }
}

// MARK: - scopesProvider tests

extension GoogleAuthTests {
  func test_defaultScopesProvider_requestsBothDriveScopes() {
    let auth = GoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))

    XCTAssertEqual(
      auth.requiredScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }

  func test_scopesProvider_isResolvedAtCallTime() {
    var currentOption: GDriveBackupOption = .appDataFolder
    let auth = GoogleAuth(
      config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId),
      scopesProvider: { currentOption.requiredDriveScopes }
    )

    XCTAssertEqual(auth.requiredScopes, [GDriveBackupOption.DriveScope.appData])

    currentOption = .gdriveFolder(folderName: "test-folder")

    XCTAssertEqual(auth.requiredScopes, [GDriveBackupOption.DriveScope.file])
  }
}

// MARK: - isDeadGrantError tests

extension GoogleAuthTests {
  private static let appAuthTokenDomain = "org.openid.appauth.oauth_token"
  private static let appAuthGeneralDomain = "org.openid.appauth.general"

  func test_isDeadGrantError_returnsTrue_forAppAuthInvalidGrant() {
    let invalidGrant = NSError(domain: Self.appAuthTokenDomain, code: -10)

    XCTAssertTrue(GoogleAuth.isDeadGrantError(invalidGrant))
  }

  func test_isDeadGrantError_returnsTrue_forAnyAppAuthTokenEndpointError() {
    let otherTokenError = NSError(domain: Self.appAuthTokenDomain, code: -8)

    XCTAssertTrue(GoogleAuth.isDeadGrantError(otherTokenError))
  }

  func test_isDeadGrantError_returnsTrue_forHasNoAuthInKeychain() {
    let noAuth = NSError(domain: GIDSignInError.errorDomain, code: GIDSignInError.Code.hasNoAuthInKeychain.rawValue)

    XCTAssertTrue(GoogleAuth.isDeadGrantError(noAuth))
  }

  func test_isDeadGrantError_returnsTrue_whenDeadGrantIsWrappedAsUnderlyingError() {
    let invalidGrant = NSError(domain: Self.appAuthTokenDomain, code: -10)
    let wrapped = NSError(domain: "com.example.wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: invalidGrant])

    XCTAssertTrue(GoogleAuth.isDeadGrantError(wrapped))
  }

  func test_isDeadGrantError_returnsFalse_forTransientAppAuthErrors() {
    // network (-5), server (-6) and JSON (-7): signing out on these would
    // destroy a valid session while the device is merely offline
    for code in [-5, -6, -7] {
      let transient = NSError(domain: Self.appAuthGeneralDomain, code: code)
      XCTAssertFalse(GoogleAuth.isDeadGrantError(transient), "code \(code) must not be treated as a dead grant")
    }
  }

  func test_isDeadGrantError_returnsFalse_forOtherGIDSignInErrors() {
    // unknown (-1), keychain (-2), canceled (-5), EMM (-6)
    for code in [-1, -2, -5, -6] {
      let error = NSError(domain: GIDSignInError.errorDomain, code: code)
      XCTAssertFalse(GoogleAuth.isDeadGrantError(error), "GIDSignInError code \(code) must not be treated as a dead grant")
    }
  }

  func test_isDeadGrantError_returnsFalse_forUnrelatedErrors() {
    XCTAssertFalse(GoogleAuth.isDeadGrantError(URLError(.notConnectedToInternet)))
    XCTAssertFalse(GoogleAuth.isDeadGrantError(GoogleAuthError.noUserFound))
  }
}

// MARK: - getAccessToken dead-grant recovery tests

/// GIDGoogleUser cannot be constructed in tests, so this double drives the
/// restore path through configurable failures and records what getAccessToken
/// does in response; every path therefore ends in the empty-string contract.
private class RestoreOutcomeGoogleAuth: GoogleAuth {
  var restoreError: Error
  var signInError: Error = GoogleAuthError.noViewFound
  var signInCallsCount = 0
  var signOutCallsCount = 0

  init(restoreError: Error) {
    self.restoreError = restoreError
    super.init(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }

  override func hasPreviousSignIn() -> Bool {
    return true
  }

  override func restorePreviousSignIn() async throws -> GIDGoogleUser {
    throw restoreError
  }

  override func signIn() async throws -> GIDGoogleUser {
    signInCallsCount += 1
    throw signInError
  }

  override func signOut() {
    signOutCallsCount += 1
  }
}

extension GoogleAuthTests {
  func test_getAccessToken_willSignOutAndRetryInteractively_whenStoredGrantIsRevoked() async {
    // given
    let auth = RestoreOutcomeGoogleAuth(restoreError: NSError(domain: Self.appAuthTokenDomain, code: -10))

    // and given
    let token = await auth.getAccessToken()

    // then the dead session is cleared even though sign-in cannot present (no view)
    XCTAssertEqual(auth.signOutCallsCount, 1)
    XCTAssertEqual(auth.signInCallsCount, 1)
    XCTAssertEqual(token, "")
  }

  func test_getAccessToken_willSignOutAndRetryInteractively_whenKeychainHasNoAuth() async {
    // given
    let auth = RestoreOutcomeGoogleAuth(
      restoreError: NSError(domain: GIDSignInError.errorDomain, code: GIDSignInError.Code.hasNoAuthInKeychain.rawValue)
    )

    // and given
    let token = await auth.getAccessToken()

    // then
    XCTAssertEqual(auth.signOutCallsCount, 1)
    XCTAssertEqual(auth.signInCallsCount, 1)
    XCTAssertEqual(token, "")
  }

  func test_getAccessToken_willNotSignOut_whenRestoreFailsTransiently() async {
    // given
    let auth = RestoreOutcomeGoogleAuth(restoreError: NSError(domain: Self.appAuthGeneralDomain, code: -5))

    // and given
    let token = await auth.getAccessToken()

    // then the still-valid session is preserved
    XCTAssertEqual(auth.signOutCallsCount, 0)
    XCTAssertEqual(auth.signInCallsCount, 0)
    XCTAssertEqual(token, "")
  }

  func test_getAccessToken_willStayUnwedged_whenFallbackSignInIsCanceled() async {
    // given
    let auth = RestoreOutcomeGoogleAuth(restoreError: NSError(domain: Self.appAuthTokenDomain, code: -10))
    auth.signInError = NSError(domain: GIDSignInError.errorDomain, code: GIDSignInError.Code.canceled.rawValue)

    // and given
    let token = await auth.getAccessToken()

    // then the dead session was already cleared, so the next attempt prompts again
    XCTAssertEqual(auth.signOutCallsCount, 1)
    XCTAssertEqual(auth.signInCallsCount, 1)
    XCTAssertEqual(token, "")
  }
}

// MARK: - recoverFromRejectedAccessToken tests

/// Returns the scripted tokens in order (the last one repeats).
private class ScriptedTokenGoogleAuth: GoogleAuth {
  var tokens: [String]
  var signOutCallsCount = 0
  var getAccessTokenCallsCount = 0

  init(tokens: [String]) {
    self.tokens = tokens
    super.init(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }

  override func getAccessToken() async -> String {
    getAccessTokenCallsCount += 1
    return tokens.count > 1 ? tokens.removeFirst() : tokens[0]
  }

  override func signOut() {
    signOutCallsCount += 1
  }
}

extension GoogleAuthTests {
  func test_recoverFromRejectedAccessToken_returnsRenewedToken_withoutSignOut_whenSessionWasAlreadyRenewed() async {
    // given
    let auth = ScriptedTokenGoogleAuth(tokens: ["fresh-token"])

    // and given
    let token = await auth.recoverFromRejectedAccessToken("revoked-token")

    // then
    XCTAssertEqual(token, "fresh-token")
    XCTAssertEqual(auth.signOutCallsCount, 0)
  }

  func test_recoverFromRejectedAccessToken_signsOutAndReturnsFreshToken_whenTheRejectedTokenComesBack() async {
    // given the silent restore still hands back the revoked token
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "fresh-token"])

    // and given
    let token = await auth.recoverFromRejectedAccessToken("revoked-token")

    // then
    XCTAssertEqual(token, "fresh-token")
    XCTAssertEqual(auth.signOutCallsCount, 1)
  }

  func test_recoverFromRejectedAccessToken_returnsEmptyWithoutSecondRecovery_whenGetAccessTokenAlreadyFailed() async {
    // given getAccessToken() already ran its own recovery (e.g. the cached token
    // expired meanwhile and the user cancelled the resulting sign-in)
    let auth = ScriptedTokenGoogleAuth(tokens: [""])

    // and given
    let token = await auth.recoverFromRejectedAccessToken("revoked-token")

    // then no second sign-out or sign-in is attempted for the same request
    XCTAssertEqual(token, "")
    XCTAssertEqual(auth.signOutCallsCount, 0)
    XCTAssertEqual(auth.getAccessTokenCallsCount, 1)
  }
}

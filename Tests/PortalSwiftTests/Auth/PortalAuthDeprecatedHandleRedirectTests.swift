//
//  PortalAuthDeprecatedHandleRedirectTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers what the deprecation adds to `handleRedirect(_:)`: it still completes every redirect
/// in one step, warns each time it completes a magic link that way, and shares its memory with
/// the methods that replace it.
///
/// The warning text is spelled out here rather than read from the SDK: it is word for word the
/// Android SDK's (React Native and Web differ only in naming the last call
/// `completeOAuthLogin(token)`), so one migration note covers every platform, and a test that
/// compared the constant with itself could not catch a drift.
final class PortalAuthDeprecatedHandleRedirectTests: XCTestCase {
  private static let deprecationWarning =
    "[PortalAuth] handleRedirect() is deprecated and will be removed in the next major version. Read the redirect with parseRedirect(url), then complete a magic link with getMagicLinkDetails(token) and, once the user confirms the email, confirmMagicLink(token), or a Google or Apple login with completeOAuthLogin(redirect)."

  private var requests = RecordingPortalRequests()
  private var storage = MockAuthSessionStorage()
  private var logger = RecordingLogger()
  private var auth = AuthTestFixtures.makeAuth(requests: RecordingPortalRequests())

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.logger = RecordingLogger()
    self.auth = AuthTestFixtures.makeAuth(requests: self.requests, storage: self.storage, logger: self.logger)
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  /// The deprecation warnings logged so far. Filtered on the text, not on the level alone: the
  /// logger sink is process-wide, and other warnings are not this test's business.
  private var deprecationWarnings: [String] {
    self.logger.messages(at: .warn).filter { $0.contains("handleRedirect() is deprecated") }
  }

  // MARK: - The warning

  func test_handleRedirect_willExchangeMagicLink_andWarnOnce_withTheSharedText() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try expectAuthenticatedResult(await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(self.requests.recorded.map { $0.path }, [PortalAuthApi.magicLinkValidationsPath], "Still a one-step exchange")
    XCTAssertEqual(self.deprecationWarnings, [Self.deprecationWarning])
  }

  func test_handleRedirectURL_willWarnOnce() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try expectAuthenticatedResult(await self.auth.legacy.handleRedirect(AuthTestFixtures.url(AuthTestFixtures.magicLinkRedirect())))

    XCTAssertEqual(self.deprecationWarnings, [Self.deprecationWarning])
  }

  func test_handleRedirect_willWarnOnEveryMagicLinkCall_includingAReplay() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect())
    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    XCTAssertEqual(self.requests.callCount, 1, "The second call replayed")
    XCTAssertEqual(self.deprecationWarnings.count, 2, "Every one-step magic link is reported, replayed or not")
  }

  func test_handleRedirect_willNotWarn_forAGoogleOrAppleRedirect() async throws {
    // The `@available` attribute already tells those callers at compile time; the runtime warning
    // is for the one case that skips a security step.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("google-grant", loginType: "GOOGLE"))
    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("apple-grant", loginType: "APPLE"))

    XCTAssertTrue(self.deprecationWarnings.isEmpty)
  }

  func test_handleRedirect_willNotWarn_whenNotASignInOrFailed() async throws {
    _ = try await self.auth.legacy.handleRedirect("otherapp://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK")
    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.redirectUrl + "?token=g&authMethod=EMAIL_MAGIC_LINK&login_type=GOOGLE")
    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.redirectUrl + "?error=oauth_failed"))

    XCTAssertTrue(self.deprecationWarnings.isEmpty)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willNotPutTheTokenInTheWarningOrAnyLog() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: "secret-session-token")

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect("secret-grant"))
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect("another-secret-grant")))

    self.logger.assertNoSecret("secret-grant")
    self.logger.assertNoSecret("secret-session-token")
    self.logger.assertNoSecret(AuthTestFixtures.redirectUrl)
  }

  // MARK: - Errors are unchanged

  func test_handleRedirect_willKeepReportingARejectedMagicLink_asUnauthorized() async {
    // The deprecated path keeps the error it has always thrown; only the two-step methods map a
    // rejected link to `grantRejected`.
    self.requests.failWith = PortalRequestsError.unauthorized

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalRequestsError.unauthorized
    )
  }

  // MARK: - Memory shared with the replacements

  func test_handleRedirect_willReplayAMagicLinkConfirmMagicLinkExchanged() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let confirmed = try expectAuthenticatedResult(await self.auth.confirmMagicLink(AuthTestFixtures.grantToken))
    let redelivered = try expectAuthenticatedResult(await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertTrue(confirmed.session === redelivered.session)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirect_willReplayAGoogleLoginCompleteOAuthLoginExchanged() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = try expectOAuthRedirect(self.auth.parseRedirect(AuthTestFixtures.oauthRedirect()))

    let completed = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(redirect))
    let redelivered = try expectAuthenticatedResult(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertTrue(completed.session === redelivered.session)
    XCTAssertEqual(self.requests.callCount, 1)
  }
}

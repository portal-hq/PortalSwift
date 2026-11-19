//
//  PortalAuthParseRedirectTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers `PortalAuth.parseRedirect(_:)`: which URLs it reads as a magic link, a Google or Apple
/// sign-in, or a failed sign-in, which it ignores, and that reading one has no side effects.
///
/// The last case pins the property the two-step magic link rests on: the deprecated one-step
/// `handleRedirect(_:)` exchanges a URL as a magic link only when `parseRedirect(_:)` reads it as
/// one. An app that sends every `.magicLink` to its confirmation screen therefore leaves no URL
/// that the one-step path would complete without that screen.
final class PortalAuthParseRedirectTests: XCTestCase {
  private static let redirectUrl = AuthTestFixtures.redirectUrl

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

  // MARK: - Helpers

  private func magicLink(_ token: String) -> AuthRedirect {
    .magicLink(AuthRedirect.MagicLink(token: token))
  }

  private func oauth(_ provider: AuthMethod, _ token: String) -> AuthRedirect {
    .oauth(AuthRedirect.OAuth(provider: provider, token: token))
  }

  /// `<redirectUrl>?<query>`.
  private func url(_ query: String) -> String {
    "\(Self.redirectUrl)?\(query)"
  }

  // MARK: - Reading each kind

  func test_parseRedirect_willReturnMagicLink_whenAuthMethodIsEmailMagicLink() {
    XCTAssertEqual(self.auth.parseRedirect(AuthTestFixtures.magicLinkRedirect("grant-1")), self.magicLink("grant-1"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("authMethod=EMAIL_MAGIC_LINK&token=grant-1")), self.magicLink("grant-1"))
  }

  func test_parseRedirect_willReturnOAuth_whenLoginTypeIsGoogle() {
    XCTAssertEqual(self.auth.parseRedirect(AuthTestFixtures.oauthRedirect("grant-1", loginType: "GOOGLE")), self.oauth(.google, "grant-1"))
  }

  func test_parseRedirect_willReturnOAuth_whenLoginTypeIsApple() {
    XCTAssertEqual(self.auth.parseRedirect(AuthTestFixtures.oauthRedirect("grant-1", loginType: "APPLE")), self.oauth(.apple, "grant-1"))
  }

  func test_parseRedirect_willReturnFailed_whenErrorParam() {
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=oauth_failed")), .failed(error: "oauth_failed"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=")), .failed(error: ""), "An empty error is still a failed sign-in")
  }

  func test_parseRedirect_willPreferErrorOverToken() {
    // The order is contractual: a redirect that reports an error is a failed sign-in even when it
    // also carries a token, so the token is never handed to the app to complete.
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=g&login_type=GOOGLE&error=oauth_failed")), .failed(error: "oauth_failed"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=oauth_failed&token=g&authMethod=EMAIL_MAGIC_LINK")), .failed(error: "oauth_failed"))
  }

  func test_parseRedirect_willBoundErrorTo100Characters() {
    let long = String(repeating: "x", count: 250)
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=\(long)")), .failed(error: String(repeating: "x", count: 100)))

    let exact = String(repeating: "y", count: 100)
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=\(exact)")), .failed(error: exact))

    // Bounded in characters, not bytes: 150 two-byte characters keep 100 of them.
    let encoded = String(repeating: "%C3%A9", count: 150)
    XCTAssertEqual(self.auth.parseRedirect(self.url("error=\(encoded)")), .failed(error: String(repeating: "é", count: 100)))
  }

  // MARK: - Both markers

  func test_parseRedirect_willReturnNil_whenBothMarkersPresent() {
    // Portal never puts both on one URL, so which sign-in such a URL completes cannot be told
    // apart. It is ignored — even with an `error` — rather than guessed at.
    let urls = [
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK&login_type=GOOGLE"),
      self.url("token=g&login_type=APPLE&authMethod=EMAIL_MAGIC_LINK"),
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK&login_type="),
      self.url("token=g&authMethod=&login_type=GOOGLE"),
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK&login_type"),
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK&login_type=GOOGLE&error=oauth_failed")
    ]

    for url in urls {
      XCTAssertNil(self.auth.parseRedirect(url), url)
    }
  }

  // MARK: - Not a sign-in result

  func test_parseRedirect_willReturnNil_whenEmptyOrWhitespaceOnly() {
    for url in ["", " ", "\n\t"] {
      XCTAssertNil(self.auth.parseRedirect(url))
    }
  }

  func test_parseRedirect_willParse_whenExactly8192Utf16Units() {
    let prefix = self.url("authMethod=EMAIL_MAGIC_LINK&token=")
    let token = String(repeating: "a", count: 8192 - prefix.utf16.count)
    let url = prefix + token
    XCTAssertEqual(url.utf16.count, 8192)

    XCTAssertEqual(self.auth.parseRedirect(url), self.magicLink(token))
  }

  func test_parseRedirect_willReturnNil_whenExactly8193Utf16Units() {
    let prefix = self.url("authMethod=EMAIL_MAGIC_LINK&token=")
    let url = prefix + String(repeating: "a", count: 8193 - prefix.utf16.count)
    XCTAssertEqual(url.utf16.count, 8193)

    XCTAssertNil(self.auth.parseRedirect(url))
  }

  func test_parseRedirect_willMeasureUtf16Units_notCharacters() {
    // "😀" is one Character but two UTF-16 units: under the bound in Characters, over it in units.
    let prefix = self.url("authMethod=EMAIL_MAGIC_LINK&token=t&pad=")
    let url = prefix + String(repeating: "😀", count: 8192 - prefix.count)
    XCTAssertEqual(url.count, 8192)
    XCTAssertGreaterThan(url.utf16.count, 8192)

    XCTAssertNil(self.auth.parseRedirect(url))
  }

  func test_parseRedirect_willReturnNil_whenTargetsAnotherRedirect() {
    let urls = [
      "otherapp://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      "portalexample://auth/other?token=g&authMethod=EMAIL_MAGIC_LINK",
      "portalexample://attacker/callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      "portalexample://auth/Callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      "https://example.com/auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      // An error on another target is not this instance's failed sign-in either.
      "otherapp://auth/callback?error=oauth_failed"
    ]

    for url in urls {
      XCTAssertNil(self.auth.parseRedirect(url), url)
    }
  }

  func test_parseRedirect_willReturnNil_whenTokenMissingEmptyOrBlank() {
    let urls = [
      self.url("authMethod=EMAIL_MAGIC_LINK"),
      self.url("token=&authMethod=EMAIL_MAGIC_LINK"),
      self.url("token&authMethod=EMAIL_MAGIC_LINK"),
      self.url("token=%20%20&authMethod=EMAIL_MAGIC_LINK"),
      self.url("token=+&login_type=GOOGLE"),
      Self.redirectUrl
    ]

    for url in urls {
      XCTAssertNil(self.auth.parseRedirect(url), url)
    }
  }

  func test_parseRedirect_willReturnNil_whenMarkerMissingUnknownOrWrongCase() {
    let urls = [
      self.url("token=g"),
      self.url("token=g&authMethod=GOOGLE"),
      self.url("token=g&authMethod=email_magic_link"),
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK+"),
      self.url("token=g&login_type=google"),
      self.url("token=g&login_type=FACEBOOK"),
      self.url("token=g&login_type=EMAIL_MAGIC_LINK"),
      self.url("token=g&AUTHMETHOD=EMAIL_MAGIC_LINK"),
      self.url("token=g&Login_Type=GOOGLE")
    ]

    for url in urls {
      XCTAssertNil(self.auth.parseRedirect(url), url)
    }
  }

  // MARK: - Decoding and crafted URLs

  func test_parseRedirect_willDecodePercentEncodedKeysAndValues() {
    // Keys are decoded like values, so an encoded marker is still a magic link — and goes to the
    // confirmation step like any other.
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=g&auth%4Dethod=EMAIL_MAGIC_LINK")), self.magicLink("g"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=g&authMethod=%45MAIL_MAGIC_LINK")), self.magicLink("g"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=a%2Bb%3D&authMethod=EMAIL_MAGIC_LINK")), self.magicLink("a+b="))
  }

  func test_parseRedirect_willUseTheLastOfRepeatedParameters() {
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=first&token=second&authMethod=EMAIL_MAGIC_LINK")), self.magicLink("second"))
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=g&authMethod=GOOGLE&authMethod=EMAIL_MAGIC_LINK")), self.magicLink("g"))
    XCTAssertNil(self.auth.parseRedirect(self.url("token=g&authMethod=EMAIL_MAGIC_LINK&authMethod=GOOGLE")))
  }

  func test_parseRedirect_willIgnoreTheFragment() {
    XCTAssertEqual(self.auth.parseRedirect(self.url("token=g&authMethod=EMAIL_MAGIC_LINK#token=other")), self.magicLink("g"))
    XCTAssertNil(self.auth.parseRedirect("\(Self.redirectUrl)#?token=g&authMethod=EMAIL_MAGIC_LINK"))
  }

  func test_parseRedirect_willMatch_whenSchemeCaseTrailingSlashOrWhitespaceDiffer() {
    let urls = [
      "PortalExample://AUTH/callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      "portalexample://auth/callback/?token=g&authMethod=EMAIL_MAGIC_LINK",
      "  portalexample://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK\n"
    ]

    for url in urls {
      XCTAssertEqual(self.auth.parseRedirect(url), self.magicLink("g"), url)
    }
  }

  // MARK: - Overloads

  func test_parseRedirectURL_willMatchStringOverload() throws {
    let magicLink = AuthTestFixtures.magicLinkRedirect("a%2Bb")
    let oauth = AuthTestFixtures.oauthRedirect("c%2Fd", loginType: "APPLE")

    XCTAssertEqual(try self.auth.parseRedirect(AuthTestFixtures.url(magicLink)), self.auth.parseRedirect(magicLink))
    XCTAssertEqual(try self.auth.parseRedirect(AuthTestFixtures.url(magicLink)), self.magicLink("a+b"), "The grant is decoded exactly once")
    XCTAssertEqual(try self.auth.parseRedirect(AuthTestFixtures.url(oauth)), self.oauth(.apple, "c/d"))
  }

  // MARK: - No side effects

  func test_parseRedirect_willMakeNoRequest_touchNoStorage_andLogNothing() {
    let urls = [
      AuthTestFixtures.magicLinkRedirect(),
      AuthTestFixtures.oauthRedirect(),
      self.url("error=oauth_failed"),
      self.url("token=g&authMethod=EMAIL_MAGIC_LINK&login_type=GOOGLE"),
      "otherapp://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK"
    ]

    for url in urls {
      _ = self.auth.parseRedirect(url)
    }

    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.storage.getCalls, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.storage.deleteCalls, 0)
    XCTAssertTrue(self.logger.messages.isEmpty, "parseRedirect must not log; it logged: \(self.logger.messages.count) line(s)")
  }

  func test_parseRedirect_willRememberNothing() async throws {
    // Reading a redirect is not completing it: the grant still reaches Portal once confirmed.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    _ = self.auth.parseRedirect(AuthTestFixtures.magicLinkRedirect())
    _ = self.auth.parseRedirect(AuthTestFixtures.magicLinkRedirect())

    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(AuthTestFixtures.grantToken))

    XCTAssertEqual(self.requests.recorded.map { $0.path }, [PortalAuthApi.magicLinkValidationsPath])
  }

  // MARK: - The one-step path cannot skip the confirmation

  func test_handleRedirect_willExchangeOnlyWhatParseRedirectReads() async throws {
    let r = Self.redirectUrl
    let urls = [
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?authMethod=EMAIL_MAGIC_LINK&token=g",
      "\(r)/?token=g&authMethod=EMAIL_MAGIC_LINK",
      "PORTALEXAMPLE://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&auth%4Dethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&authMethod=%45MAIL_MAGIC_LINK",
      "\(r)?token=g&AUTHMETHOD=EMAIL_MAGIC_LINK",
      "\(r)?token=g&authMethod=email_magic_link",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK+",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK%00",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK&authMethod=GOOGLE",
      "\(r)?token=g&authMethod=GOOGLE&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK&login_type=",
      "\(r)?token=g&login_type=&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&login_type=EMAIL_MAGIC_LINK&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&login_type=UNKNOWN&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&login_type=GOOGLE&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK#x",
      "\(r)#?token=g&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=%20&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&authMethod=EMAIL_MAGIC_LINK&error=",
      "\(r)?error=oauth_failed&token=g&authMethod=EMAIL_MAGIC_LINK",
      "\(r)?token=g&login_type=GOOGLE",
      "\(r)?token=g&login_type=APPLE",
      "\(r)?token=g&login_type=google",
      "\(r)?token=g&login_type=EMAIL_MAGIC_LINK",
      "otherapp://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK"
    ]

    for url in urls {
      // A fresh instance per URL, so no replay memory can hide an exchange.
      let requests = RecordingPortalRequests()
      requests.defaultResponse = AuthTestFixtures.grantResponse()
      let auth = AuthTestFixtures.makeAuth(requests: requests)

      let parsed = auth.parseRedirect(url)
      _ = try? await auth.legacy.handleRedirect(url)

      let paths = requests.recorded.map { $0.path }
      switch parsed {
      case .magicLink?:
        XCTAssertEqual(paths, [PortalAuthApi.magicLinkValidationsPath], url)
      case .oauth?:
        XCTAssertEqual(paths, [PortalAuthApi.oauthTokensPath], url)
      case .failed?, .none:
        XCTAssertEqual(paths, [], "handleRedirect exchanged a URL parseRedirect does not read as a sign-in: \(url)")
      }
    }
  }
}

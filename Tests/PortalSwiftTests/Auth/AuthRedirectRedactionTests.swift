//
//  AuthRedirectRedactionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers how an `AuthRedirect` renders. A redirect carries a single-use grant and is exactly the
/// kind of value an app interpolates into a log line, so every common rendering path must replace
/// the token with `<redacted>`, while `Equatable` keeps comparing the real value.
final class AuthRedirectRedactionTests: XCTestCase {
  /// Distinctive, so a leak cannot match by accident.
  private static let token = "grant-token-that-must-not-leak"
  private static let redacted = "<redacted>"

  private let magicLink = AuthRedirect.magicLink(AuthRedirect.MagicLink(token: AuthRedirectRedactionTests.token))
  private let oauth = AuthRedirect.oauth(AuthRedirect.OAuth(provider: .google, token: AuthRedirectRedactionTests.token))

  // MARK: - Helpers

  /// Every way a value commonly reaches a log or a crash breadcrumb.
  private func renderings(of value: Any) -> [String] {
    var dumped = ""
    dump(value, to: &dumped)
    var printed = ""
    print(value, to: &printed)
    var debugPrinted = ""
    debugPrint(value, to: &debugPrinted)
    return [
      String(describing: value),
      String(reflecting: value),
      "\(value)",
      dumped,
      printed,
      debugPrinted,
      self.mirrorLeaves(of: value).joined(separator: "|")
    ]
  }

  /// The rendered value of every node reachable through `Mirror`, depth-limited.
  private func mirrorLeaves(of value: Any, depth: Int = 0) -> [String] {
    guard depth < 6 else {
      return []
    }
    var leaves = ["\(value)"]
    for child in Mirror(reflecting: value).children {
      leaves.append(contentsOf: self.mirrorLeaves(of: child.value, depth: depth + 1))
    }
    return leaves
  }

  private func assertRedacted(_ value: Any, file: StaticString = #filePath, line: UInt = #line) {
    for rendering in self.renderings(of: value) {
      XCTAssertFalse(rendering.contains(Self.token), "A rendering leaked the grant: \(rendering)", file: file, line: line)
    }
  }

  // MARK: - Redaction

  func test_everyRendering_willRedactMagicLinkToken() {
    self.assertRedacted(self.magicLink)
    self.assertRedacted(AuthRedirect.MagicLink(token: Self.token))
    XCTAssertTrue(String(describing: self.magicLink).contains(Self.redacted))
  }

  func test_everyRendering_willRedactOAuthToken_andShowProvider() {
    self.assertRedacted(self.oauth)
    self.assertRedacted(AuthRedirect.OAuth(provider: .apple, token: Self.token))
    XCTAssertTrue(String(describing: self.oauth).contains("GOOGLE"))
    XCTAssertTrue(String(describing: self.oauth).contains(Self.redacted))
  }

  func test_everyRendering_willRedact_whenWrappedInOptionalOrCollection() {
    let optional: AuthRedirect? = self.magicLink
    self.assertRedacted(optional as Any)
    self.assertRedacted([self.magicLink, self.oauth])
    self.assertRedacted(["redirect": self.oauth])
  }

  func test_everyRendering_willShowFailedError() {
    let failed = AuthRedirect.failed(error: "oauth_failed")

    for rendering in self.renderings(of: failed) {
      XCTAssertTrue(rendering.contains("oauth_failed"), "The error of a failed redirect is not secret and must stay readable: \(rendering)")
    }
  }

  func test_description_willNameTheCase() {
    XCTAssertEqual(String(describing: self.magicLink), "AuthRedirect.magicLink(MagicLink(token: <redacted>))")
    XCTAssertEqual(String(describing: self.oauth), "AuthRedirect.oauth(OAuth(provider: GOOGLE, token: <redacted>))")
    XCTAssertEqual(String(describing: AuthRedirect.failed(error: "oauth_failed")), "AuthRedirect.failed(error: oauth_failed)")
    XCTAssertEqual(String(reflecting: self.magicLink), String(describing: self.magicLink))
  }

  func test_customMirror_willExposeOnlyRedactedTokens() throws {
    let link = try XCTUnwrap(Mirror(reflecting: self.magicLink).children.first?.value as? AuthRedirect.MagicLink)
    let linkChildren = Mirror(reflecting: link).children.map { ($0.label, "\($0.value)") }
    XCTAssertEqual(linkChildren.map { $0.0 }, ["token"])
    XCTAssertEqual(linkChildren.map { $0.1 }, [Self.redacted])

    let oauthChildren = Mirror(reflecting: AuthRedirect.OAuth(provider: .apple, token: Self.token)).children.map { ($0.label, "\($0.value)") }
    XCTAssertEqual(oauthChildren.map { $0.0 }, ["provider", "token"])
    XCTAssertEqual(oauthChildren.map { $0.1 }, ["APPLE", Self.redacted])
  }

  // MARK: - Equality

  func test_equatable_willStillCompareTheRealValues() {
    XCTAssertEqual(AuthRedirect.MagicLink(token: "a"), AuthRedirect.MagicLink(token: "a"))
    XCTAssertNotEqual(AuthRedirect.MagicLink(token: "a"), AuthRedirect.MagicLink(token: "b"))
    XCTAssertNotEqual(AuthRedirect.OAuth(provider: .google, token: "a"), AuthRedirect.OAuth(provider: .google, token: "b"))
    XCTAssertNotEqual(AuthRedirect.OAuth(provider: .google, token: "a"), AuthRedirect.OAuth(provider: .apple, token: "a"))
    XCTAssertNotEqual(
      AuthRedirect.magicLink(AuthRedirect.MagicLink(token: "a")),
      AuthRedirect.oauth(AuthRedirect.OAuth(provider: .google, token: "a"))
    )
    XCTAssertEqual(AuthRedirect.failed(error: "oauth_failed"), AuthRedirect.failed(error: "oauth_failed"))
  }

  func test_magicLinkToken_willBeReadableByTheApp() {
    // The magic-link token is public: the app passes it to `getMagicLinkDetails(_:)` and
    // `confirmMagicLink(_:)`. The OAuth token stays internal to the SDK.
    guard case let .magicLink(link) = self.magicLink else {
      return XCTFail("Expected a magic link.")
    }
    XCTAssertEqual(link.token, Self.token)
  }
}

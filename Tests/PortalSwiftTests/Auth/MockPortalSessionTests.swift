//
//  MockPortalSessionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers the public `MockPortalSession`, which hosts use in place of the session
/// `PortalAuth` produces.
///
/// The mock is public API, so its behaviour is pinned as carefully as production code: it
/// must count every call (including the ones that throw), honour an injected `getTokenError`
/// ahead of the invalidated state, clear the token *before* an injected `invalidateError` is
/// thrown (parity with the real session, whose in-memory token is gone even when the
/// persisted delete fails), and behave like any other `PortalCredentials` when driven through
/// the SDK's credential helpers. The invalidation registry is reset around each case because
/// `PortalCredentialSupport.invalidate(_:)` records a monitor for the subject.
final class MockPortalSessionTests: XCTestCase {
  private var subject = MockPortalSession(tokenValue: "mock-cst", endUserId: "user-1")

  /// Stands in for the auth module's storage failure (`PortalAuthError.sessionStorageFailure`
  /// in the plan): the mock accepts any `Error`, and the case under test is the ordering of
  /// clear-then-throw, not the error's type.
  private struct SessionStorageFailure: Error, Equatable {
    let detail: String
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.subject = MockPortalSession(tokenValue: "mock-cst", endUserId: "user-1")
  }

  override func tearDownWithError() throws {
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - getToken

  func test_getToken_willReturnTokenValue_andCount() throws {
    let first = try self.subject.getToken()
    let second = try self.subject.getToken()

    XCTAssertEqual(first, "mock-cst")
    XCTAssertEqual(second, "mock-cst")
    XCTAssertEqual(self.subject.getTokenCalls, 2)
    XCTAssertEqual(self.subject.invalidateCalls, 0)
    XCTAssertFalse(self.subject.isInvalidated)
    XCTAssertEqual(self.subject.endUserId, "user-1")
  }

  func test_getToken_willThrowConfiguredError() {
    self.subject.getTokenError = PortalCredentialError.unavailable

    XCTAssertThrowsError(try self.subject.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    }
    XCTAssertEqual(self.subject.getTokenCalls, 1, "A call that throws is still counted")
    XCTAssertEqual(self.subject.tokenValue, "mock-cst", "An injected getToken failure does not touch the stored token")
    XCTAssertFalse(self.subject.isInvalidated)
  }

  // MARK: - invalidate

  func test_invalidate_willCount_andMakeGetTokenThrowSessionInvalidated() throws {
    try self.subject.invalidate()

    XCTAssertEqual(self.subject.invalidateCalls, 1)
    XCTAssertTrue(self.subject.isInvalidated)
    XCTAssertNil(self.subject.tokenValue)
    XCTAssertThrowsError(try self.subject.getToken()) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .sessionInvalidated)
      XCTAssertEqual(credentialError?.requiresReauthentication, true)
      XCTAssertEqual(credentialError?.reason, .sessionInvalidated)
    }
    XCTAssertEqual(self.subject.getTokenCalls, 1)
  }

  func test_invalidate_willThrowConfiguredError_andStillMarkInvalidated() {
    self.subject.invalidateError = SessionStorageFailure(detail: "x")

    XCTAssertThrowsError(try self.subject.invalidate()) { error in
      XCTAssertEqual(error as? SessionStorageFailure, SessionStorageFailure(detail: "x"))
    }

    XCTAssertTrue(self.subject.isInvalidated, "The token is cleared before the storage failure is thrown")
    XCTAssertNil(self.subject.tokenValue)
    XCTAssertEqual(self.subject.invalidateCalls, 1)
    XCTAssertThrowsError(try self.subject.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
  }

  // MARK: - Credential helpers

  func test_mockPortalSession_willWorkThroughCredentialHelpers() throws {
    let token = try PortalCredentialSupport.resolveToken(self.subject)
    XCTAssertEqual(token, "mock-cst")
    XCTAssertEqual(self.subject.getTokenCalls, 1)

    try PortalCredentialSupport.invalidate(self.subject)
    XCTAssertEqual(self.subject.invalidateCalls, 1)
    XCTAssertTrue(self.subject.isInvalidated)

    XCTAssertEqual(PortalCredentialSupport.staticApiKey(of: self.subject), "", "A session is never a static Client API Key")
    XCTAssertThrowsError(try PortalCredentialSupport.resolveToken(self.subject)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "The precise reason passes through the boundary untouched")
    }
  }
}

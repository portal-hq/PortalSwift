//
//  AuthResultTestSupport.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Raised by the result helpers so a case that got the wrong `AuthResult` stops at the assertion
/// instead of continuing against a value it cannot use.
enum AuthResultTestError: LocalizedError {
  case unexpectedResult(String)
  case unexpectedRedirect(String)

  var errorDescription: String? {
    switch self {
    case let .unexpectedResult(actual):
      return "Unexpected auth result \(actual)."
    case let .unexpectedRedirect(actual):
      return "Unexpected redirect \(actual)."
    }
  }
}

/// Unwraps an `.authenticated` result, failing the case (and stopping it) on anything else.
/// `AuthResult` is not `Equatable` — its session is a class-backed existential compared with
/// `===` — so cases unwrap rather than asserting on the enum itself.
func expectAuthenticatedResult(
  _ result: AuthResult?,
  file: StaticString = #filePath,
  line: UInt = #line
) throws -> AuthenticatedResult {
  guard case let .authenticated(authenticated)? = result else {
    XCTFail("Expected an .authenticated result but got \(describeAuthResult(result)).", file: file, line: line)
    throw AuthResultTestError.unexpectedResult(describeAuthResult(result))
  }
  return authenticated
}

/// Unwraps a `.totpRequired` result. `TotpRequiredResult` *is* `Equatable`, so cases compare the
/// whole value.
func expectTotpRequiredResult(
  _ result: AuthResult?,
  file: StaticString = #filePath,
  line: UInt = #line
) throws -> TotpRequiredResult {
  guard case let .totpRequired(step)? = result else {
    XCTFail("Expected a .totpRequired result but got \(describeAuthResult(result)).", file: file, line: line)
    throw AuthResultTestError.unexpectedResult(describeAuthResult(result))
  }
  return step
}

/// Unwraps the `.oauth` payload `parseRedirect(_:)` returned for `url`.
func expectOAuthRedirect(
  _ redirect: AuthRedirect?,
  file: StaticString = #filePath,
  line: UInt = #line
) throws -> AuthRedirect.OAuth {
  guard case let .oauth(oauth)? = redirect else {
    XCTFail("Expected an .oauth redirect but got \(String(describing: redirect)).", file: file, line: line)
    throw AuthResultTestError.unexpectedRedirect(String(describing: redirect))
  }
  return oauth
}

/// Names a result for a failure message without printing anything it carries — a session token,
/// a `userJwt` or a `totpLink` must never reach the test log either.
func describeAuthResult(_ result: AuthResult?) -> String {
  switch result {
  case .none:
    return "nil"
  case .authenticated:
    return ".authenticated"
  case .totpRequired:
    return ".totpRequired"
  }
}

/// An `NSLock`-guarded slot for an `AuthResult` produced inside a `Task`, so a concurrency case
/// can read what each caller got after awaiting it.
final class AuthResultBox: @unchecked Sendable {
  private let lock = NSLock()
  private var _result: AuthResult?

  var result: AuthResult? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._result
  }

  func store(_ result: AuthResult?) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._result = result
  }
}

/// A guarded call tally, for storage hooks that must fail only on their first invocation.
final class AuthCallCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0

  var count: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._count
  }

  /// Increments and returns the new count, so a hook can branch on "first call".
  func next() -> Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._count += 1
    return self._count
  }
}

/// A Keychain fault for the persist-failure cases. `PortalAuth` wraps any non-`PortalAuthError`
/// storage error into `sessionStorageFailure`, so the concrete type only has to be distinct.
struct AuthTestKeychainFault: Error {}

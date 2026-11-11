//
//  PortalCredentialErrorTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Pins the shape of `PortalCredentialError` and `PortalCredentialErrorReason`: the frozen
/// cross-SDK wire values, the agreed message text, the `reason` / `requiresReauthentication`
/// mapping hosts branch on, and the hand-written `Equatable` that compares by case only.
final class PortalCredentialErrorTests: XCTestCase {
  private let providerCause = NSError(domain: "keystore", code: 7, userInfo: [NSLocalizedDescriptionKey: "could not open secret.p12"])

  private var allCases: [PortalCredentialError] {
    [
      .unavailable,
      .providerFailure(underlying: self.providerCause),
      .sessionInvalidated,
      .invalidApiKey
    ]
  }

  /// Wraps a reason so the Codable round-trip does not depend on top-level fragment support.
  private struct ReasonEnvelope: Codable, Equatable {
    let reason: PortalCredentialErrorReason
  }

  // MARK: - requiresReauthentication

  func test_requiresReauthentication_willBeTrueOnly_forSessionInvalidated() {
    XCTAssertTrue(PortalCredentialError.sessionInvalidated.requiresReauthentication)
    XCTAssertFalse(PortalCredentialError.unavailable.requiresReauthentication)
    XCTAssertFalse(PortalCredentialError.providerFailure(underlying: self.providerCause).requiresReauthentication)
    XCTAssertFalse(PortalCredentialError.invalidApiKey.requiresReauthentication)

    let requiring = self.allCases.filter(\.requiresReauthentication)
    XCTAssertEqual(requiring, [.sessionInvalidated])
  }

  // MARK: - reason

  func test_reason_willMapEveryCase() {
    XCTAssertEqual(PortalCredentialError.unavailable.reason, .unavailable)
    XCTAssertEqual(PortalCredentialError.providerFailure(underlying: self.providerCause).reason, .providerFailure)
    XCTAssertEqual(PortalCredentialError.sessionInvalidated.reason, .sessionInvalidated)
    XCTAssertNil(PortalCredentialError.invalidApiKey.reason)
  }

  // MARK: - PortalCredentialErrorReason

  func test_PortalCredentialErrorReason_willExposeCrossSdkWireValues() {
    XCTAssertEqual(PortalCredentialErrorReason.unavailable.rawValue, "CREDENTIAL_UNAVAILABLE")
    XCTAssertEqual(PortalCredentialErrorReason.providerFailure.rawValue, "CREDENTIAL_PROVIDER_FAILURE")
    XCTAssertEqual(PortalCredentialErrorReason.sessionInvalidated.rawValue, "SESSION_INVALIDATED")

    XCTAssertEqual(PortalCredentialErrorReason(rawValue: "CREDENTIAL_UNAVAILABLE"), .unavailable)
    XCTAssertEqual(PortalCredentialErrorReason(rawValue: "CREDENTIAL_PROVIDER_FAILURE"), .providerFailure)
    XCTAssertEqual(PortalCredentialErrorReason(rawValue: "SESSION_INVALIDATED"), .sessionInvalidated)
  }

  func test_PortalCredentialErrorReason_willRoundTripThroughCodable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let expectedWire: [PortalCredentialErrorReason: String] = [
      .unavailable: "CREDENTIAL_UNAVAILABLE",
      .providerFailure: "CREDENTIAL_PROVIDER_FAILURE",
      .sessionInvalidated: "SESSION_INVALIDATED"
    ]

    for (reason, wire) in expectedWire {
      let encoded = try encoder.encode(ReasonEnvelope(reason: reason))
      let json = String(decoding: encoded, as: UTF8.self)
      XCTAssertTrue(json.contains("\"reason\":\"\(wire)\""), "Expected \(wire) in \(json)")

      let decoded = try decoder.decode(ReasonEnvelope.self, from: encoded)
      XCTAssertEqual(decoded.reason, reason)
    }

    let unknown = Data("{\"reason\":\"NOT_A_REAL_REASON\"}".utf8)
    XCTAssertThrowsError(try decoder.decode(ReasonEnvelope.self, from: unknown)) { error in
      XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(type(of: error))")
    }
  }

  // MARK: - errorDescription

  func test_errorDescription_willKeepCauseOffMessage_forProviderFailure() {
    let error = PortalCredentialError.providerFailure(underlying: self.providerCause)

    XCTAssertEqual(error.errorDescription, "[Portal] The credential provider failed to supply a credential.")
    XCTAssertFalse(error.errorDescription?.contains("secret.p12") ?? true)
    XCTAssertFalse(error.errorDescription?.contains("keystore") ?? true)
    XCTAssertFalse(error.localizedDescription.contains("secret.p12"))

    guard case let .providerFailure(underlying) = error else {
      return XCTFail("Expected .providerFailure to keep its cause available for pattern matching")
    }
    let nsError = underlying as NSError
    XCTAssertEqual(nsError.domain, "keystore")
    XCTAssertEqual(nsError.code, 7)
    XCTAssertEqual(nsError.localizedDescription, "could not open secret.p12")
  }

  func test_errorDescription_willMatchAgreedText_forEveryCase() {
    XCTAssertEqual(
      PortalCredentialError.unavailable.errorDescription,
      "[Portal] No credential was available. Provide an apiKey or credentials when constructing Portal."
    )
    XCTAssertEqual(
      PortalCredentialError.providerFailure(underlying: self.providerCause).errorDescription,
      "[Portal] The credential provider failed to supply a credential."
    )
    XCTAssertEqual(
      PortalCredentialError.sessionInvalidated.errorDescription,
      "[Portal] The session is no longer valid. Authenticate again to obtain a new one."
    )
    XCTAssertEqual(
      PortalCredentialError.invalidApiKey.errorDescription,
      "[Portal] No API key provided. Provide `apiKey` or `credentials` when constructing Portal."
    )

    for error in self.allCases {
      XCTAssertTrue(error.errorDescription?.hasPrefix("[Portal] ") ?? false, "Missing [Portal] prefix for \(error)")
    }
  }

  // MARK: - localizedDescription

  func test_localizedDescription_willEqualErrorDescription() {
    for error in self.allCases {
      let bridged: Error = error
      XCTAssertEqual(bridged.localizedDescription, error.errorDescription, "localizedDescription drifted for \(error)")
    }
  }

  // MARK: - Equatable

  func test_equatable_willCompareByCaseOnly_forProviderFailure() {
    let errorA = NSError(domain: "a", code: 1)
    let errorB = NSError(domain: "b", code: 2)

    XCTAssertEqual(
      PortalCredentialError.providerFailure(underlying: errorA),
      PortalCredentialError.providerFailure(underlying: errorB)
    )
    XCTAssertNotEqual(PortalCredentialError.providerFailure(underlying: errorA), .unavailable)
    XCTAssertNotEqual(PortalCredentialError.providerFailure(underlying: errorA), .sessionInvalidated)
    XCTAssertNotEqual(PortalCredentialError.providerFailure(underlying: errorA), .invalidApiKey)
  }

  func test_equatable_willDistinguishAllOtherCases() {
    let cases: [PortalCredentialError] = [.unavailable, .sessionInvalidated, .invalidApiKey]

    for (leftIndex, left) in cases.enumerated() {
      for (rightIndex, right) in cases.enumerated() {
        if leftIndex == rightIndex {
          XCTAssertEqual(left, right, "\(left) must equal itself")
        } else {
          XCTAssertNotEqual(left, right, "\(left) must not equal \(right)")
        }
      }
    }
  }

  // MARK: - Catchability

  func test_isCatchableAsPortalCredentialError_whenThrownAsError() {
    func failSession() throws {
      throw PortalCredentialError.sessionInvalidated
    }

    do {
      try failSession()
      XCTFail("Expected failSession() to throw")
    } catch let error as PortalCredentialError {
      XCTAssertEqual(error, .sessionInvalidated)
      XCTAssertEqual(error.reason, .sessionInvalidated)
      XCTAssertTrue(error.requiresReauthentication)
    } catch {
      XCTFail("Expected PortalCredentialError, got \(type(of: error))")
    }
  }

  func test_invalidApiKey_isCatchableAndHasNoReason() {
    func failConstruction() throws {
      throw PortalCredentialError.invalidApiKey
    }

    do {
      try failConstruction()
      XCTFail("Expected failConstruction() to throw")
    } catch let error as PortalCredentialError {
      XCTAssertEqual(error, .invalidApiKey)
      XCTAssertNil(error.reason)
      XCTAssertFalse(error.requiresReauthentication)
    } catch {
      XCTFail("Expected PortalCredentialError, got \(type(of: error))")
    }
  }
}

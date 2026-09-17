//
//  PortalCredentialErrorRedactionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// `PortalCredentialError.providerFailure` retains whatever a host `getToken()` threw, and a
/// host's own error may echo the token it failed to refresh. `errorDescription` was always
/// token-free, but it only feeds `localizedDescription`: the synthesized enum rendering behind
/// string interpolation, `String(reflecting:)`, the `NSError` bridge and the `Mirror` that `dump`
/// walks all print the associated value in full. These cases pin that every rendering path shows
/// only the cause's type name, for the three shapes a host error can take, that the payload-less
/// cases still read as their case name, and that the cause remains reachable by pattern matching.
final class PortalCredentialErrorRedactionTests: XCTestCase {
  private static let token = "cst_live_SECRET_TOKEN_0123456789"

  /// A plain struct: the synthesized rendering prints every stored property.
  private struct StructCause: Error {
    let token: String
  }

  /// A host error with its own `description` that interpolates the token.
  private struct DescribedCause: Error, CustomStringConvertible {
    let token: String
    var description: String { "keystore rejected \(self.token)" }
  }

  /// The three shapes a provider error can take, each carrying the token in the place its
  /// rendering would print.
  private var causes: [(name: String, cause: Error)] {
    [
      ("StructCause", StructCause(token: Self.token)),
      ("DescribedCause", DescribedCause(token: Self.token)),
      ("NSError", NSError(
        domain: "TestProvider",
        code: 7,
        userInfo: [NSLocalizedDescriptionKey: "refresh failed for \(Self.token)", "token": Self.token]
      ))
    ]
  }

  /// Every string a caller can obtain from the error without pattern matching, labelled so a
  /// failure names the path that leaked.
  private func renderings(of error: PortalCredentialError) -> [(path: String, text: String)] {
    let existential: Error = error
    let bridged = error as NSError
    var dumped = ""
    dump(error, to: &dumped)
    var dumpedExistential = ""
    dump(existential, to: &dumpedExistential)

    return [
      ("description", error.description),
      ("debugDescription", error.debugDescription),
      ("String(describing:)", String(describing: error)),
      ("String(reflecting:)", String(reflecting: error)),
      ("interpolation", "\(error)"),
      ("interpolation of `any Error`", "\(existential)"),
      ("String(reflecting:) of `any Error`", String(reflecting: existential)),
      ("localizedDescription", error.localizedDescription),
      ("NSError.description", bridged.description),
      ("NSError.debugDescription", bridged.debugDescription),
      ("NSError.userInfo", "\(bridged.userInfo)"),
      ("dump", dumped),
      ("dump of `any Error`", dumpedExistential),
      ("array interpolation", "\([error])"),
      ("optional interpolation", "\(Optional(error) as Any)")
    ]
  }

  // MARK: - providerFailure

  func test_everyRendering_willRedactTheCause_forEveryShapeOfProviderError() {
    for (name, cause) in self.causes {
      let error = PortalCredentialError.providerFailure(underlying: cause)

      for (path, text) in self.renderings(of: error) {
        XCTAssertFalse(text.contains(Self.token), "\(name) leaked its token through \(path): \(text)")
        XCTAssertFalse(text.contains("keystore"), "\(name) leaked its message through \(path): \(text)")
        XCTAssertFalse(text.contains("refresh failed"), "\(name) leaked its message through \(path): \(text)")
        XCTAssertFalse(text.contains("TestProvider"), "\(name) leaked its domain through \(path): \(text)")
      }
    }
  }

  func test_textualRenderings_willNameTheCauseType_andNothingElse() {
    for (name, cause) in self.causes {
      let error = PortalCredentialError.providerFailure(underlying: cause)
      let expected = "providerFailure(underlying: <redacted \(name)>)"

      XCTAssertEqual(error.description, expected)
      XCTAssertEqual(error.debugDescription, expected)
      XCTAssertEqual("\(error)", expected)
      XCTAssertEqual(String(reflecting: error), expected)
      XCTAssertEqual("\(error as Error)", expected, "The existential must dispatch to the same rendering")
    }
  }

  func test_localizedDescription_isUnchangedByTheRedactedRendering() {
    let error = PortalCredentialError.providerFailure(underlying: StructCause(token: Self.token))

    XCTAssertEqual(error.localizedDescription, "[Portal] The credential provider failed to supply a credential.")
    XCTAssertEqual(error.localizedDescription, error.errorDescription)
  }

  func test_customMirror_willExposeOnlyTheRedactedCause() {
    for (name, cause) in self.causes {
      let mirror = Mirror(reflecting: PortalCredentialError.providerFailure(underlying: cause))
      let children = mirror.children.map { (label: $0.label, value: "\($0.value)") }

      XCTAssertEqual(mirror.displayStyle, .enum)
      XCTAssertEqual(children.count, 1, "Only the redacted cause may appear: \(children)")
      XCTAssertEqual(children.first?.label, "underlying")
      XCTAssertEqual(children.first?.value, "<redacted \(name)>")
    }
  }

  func test_patternMatching_stillReachesTheCause() {
    let cause = NSError(domain: "TestProvider", code: 7)
    let error = PortalCredentialError.providerFailure(underlying: cause)

    guard case let .providerFailure(underlying) = error else {
      return XCTFail("Expected .providerFailure, got \(error)")
    }
    XCTAssertEqual(underlying as NSError, cause, "Redaction is a presentation concern; the cause stays on the value")
  }

  // MARK: - Payload-less cases

  func test_payloadlessCases_willRenderAsTheirCaseName_withNoChildren() {
    let expectations: [(error: PortalCredentialError, name: String)] = [
      (.unavailable, "unavailable"),
      (.sessionInvalidated, "sessionInvalidated"),
      (.invalidApiKey, "invalidApiKey")
    ]

    for (error, name) in expectations {
      XCTAssertEqual(error.description, name)
      XCTAssertEqual(error.debugDescription, name)
      XCTAssertEqual("\(error)", name)
      XCTAssertEqual(String(reflecting: error), name)

      let mirror = Mirror(reflecting: error)
      XCTAssertEqual(mirror.displayStyle, .enum)
      XCTAssertEqual(mirror.children.count, 0, "A payload-less case has nothing to reflect: \(name)")
    }
  }
}

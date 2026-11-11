//
//  TotpRequiredResultRedactionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// `TotpRequiredResult` carries the two values the flow must never log: the short-lived
/// `userJwt` and the `otpauth://` link with the shared secret. A struct's synthesized
/// description prints every stored property, so a `"\(step)"` in a log line, an
/// `XCTAssertEqual` failure message or a crash reporter's breadcrumb would carry both. These
/// cases pin that every rendering path — `description`, `debugDescription`, string
/// interpolation, `String(reflecting:)` and the `Mirror` that `dump` walks — is redacted, while
/// the non-secret `endUserId` stays visible for diagnostics.
final class TotpRequiredResultRedactionTests: XCTestCase {
  private static let secret = "JBSWY3DPEHPK3PXP"
  private static let link = "otpauth://totp/Portal:user%40example.com?secret=\(secret)&issuer=Portal"
  private static let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJlbmRVc2VySWQiOiJldS0xIn0.c2lnbmF0dXJl"

  private func renderings(of step: TotpRequiredResult) -> [String] {
    [
      step.description,
      step.debugDescription,
      String(describing: step),
      String(reflecting: step),
      "\(step)"
    ]
  }

  func test_everyRendering_willRedactUserJwtAndTotpLink() {
    let step = TotpRequiredResult(userJwt: Self.jwt, totpLink: Self.link, endUserId: "eu-1")

    for rendering in self.renderings(of: step) {
      XCTAssertFalse(rendering.contains(Self.secret), rendering)
      XCTAssertFalse(rendering.contains(Self.jwt), rendering)
      XCTAssertFalse(rendering.contains("otpauth"), rendering)
      XCTAssertTrue(rendering.contains("<redacted>"), rendering)
      XCTAssertTrue(rendering.contains("eu-1"), "The end-user id is not secret and must stay for diagnostics: \(rendering)")
    }
  }

  func test_everyRendering_willShowNilTotpLink_whenAlreadyEnrolled() {
    let step = TotpRequiredResult(userJwt: Self.jwt, totpLink: nil, endUserId: "eu-1")

    for rendering in self.renderings(of: step) {
      XCTAssertTrue(rendering.contains("totpLink: nil"), rendering)
      XCTAssertFalse(rendering.contains(Self.jwt), rendering)
    }
  }

  func test_customMirror_willNotExposeTheValues() {
    let step = TotpRequiredResult(userJwt: Self.jwt, totpLink: Self.link, endUserId: "eu-1")

    let children = Dictionary(uniqueKeysWithValues: step.customMirror.children.map { ($0.label ?? "", "\($0.value)") })

    XCTAssertEqual(children["endUserId"], "eu-1")
    XCTAssertEqual(children["userJwt"], "<redacted>")
    XCTAssertEqual(children["totpLink"], "<redacted>")
    XCTAssertEqual(children.count, 3, "No other stored property may leak through the mirror")
  }

  func test_equatable_stillComparesTheRealValues() {
    let a = TotpRequiredResult(userJwt: Self.jwt, totpLink: Self.link, endUserId: "eu-1")
    let b = TotpRequiredResult(userJwt: Self.jwt, totpLink: Self.link, endUserId: "eu-1")
    let other = TotpRequiredResult(userJwt: "other", totpLink: Self.link, endUserId: "eu-1")

    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, other, "Redaction is a presentation concern; equality is still on the values")
  }
}

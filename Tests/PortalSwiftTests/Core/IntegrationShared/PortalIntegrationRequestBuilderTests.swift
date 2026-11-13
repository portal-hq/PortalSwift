//
//  PortalIntegrationRequestBuilderTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class PortalIntegrationRequestBuilderTests: XCTestCase {
  private struct EmptyIdentifier: Error, Equatable {
    let name: String
  }

  private let builder = PortalIntegrationRequestBuilder(
    baseUrl: "https://api.portalhq.io",
    basePath: "/api/v3/clients/me/integrations/example",
    emptyIdentifier: { EmptyIdentifier(name: $0) }
  )

  // MARK: - encodeURIComponent

  func test_encodeURIComponent_escapesReservedCharactersLikeJavaScript() {
    XCTAssertEqual(
      PortalIntegrationRequestBuilder.encodeURIComponent("a+b&c=d,e/f:g h?i#j%k"),
      "a%2Bb%26c%3Dd%2Ce%2Ff%3Ag%20h%3Fi%23j%25k"
    )
  }

  func test_encodeURIComponent_leavesTheUnreservedCharactersAlone() {
    let unreserved = "ABCXYZabcxyz0189-_.!~*'()"

    XCTAssertEqual(PortalIntegrationRequestBuilder.encodeURIComponent(unreserved), unreserved)
  }

  func test_encodeURIComponent_encodesNonAsciiAsUtf8() {
    XCTAssertEqual(PortalIntegrationRequestBuilder.encodeURIComponent("é"), "%C3%A9")
  }

  // MARK: - joined

  func test_joined_commaJoinsTheValuesInOrder() {
    XCTAssertEqual(PortalIntegrationRequestBuilder.joined(["b", "a", "c"]), "b,a,c")
  }

  func test_joined_skipsEmptyEntries() {
    XCTAssertEqual(PortalIntegrationRequestBuilder.joined(["a", "", "b"]), "a,b")
  }

  func test_joined_isNilForNoValues() {
    XCTAssertNil(PortalIntegrationRequestBuilder.joined(nil))
    XCTAssertNil(PortalIntegrationRequestBuilder.joined([]))
    XCTAssertNil(PortalIntegrationRequestBuilder.joined(["", ""]))
  }

  // MARK: - pathSegment

  func test_pathSegment_encodesTheValueAsOneSegment() throws {
    XCTAssertEqual(try builder.pathSegment("id", "a/b c"), "a%2Fb%20c")
  }

  func test_pathSegment_rejectsAnEmptyValueWithTheParameterName() {
    XCTAssertThrowsError(try builder.pathSegment("transactionId", "")) { error in
      XCTAssertEqual(error as? EmptyIdentifier, EmptyIdentifier(name: "transactionId"))
    }
  }

  func test_pathSegment_rejectsDotSegments() {
    for value in [".", ".."] {
      XCTAssertThrowsError(try builder.pathSegment("sessionId", value), value) { error in
        XCTAssertEqual(error as? PortalApiError, .unableToEncodeData, value)
      }
    }
  }

  func test_pathSegment_acceptsDotsInsideAValue() throws {
    XCTAssertEqual(try builder.pathSegment("id", "..."), "...")
    XCTAssertEqual(try builder.pathSegment("id", "a.b"), "a.b")
    XCTAssertEqual(try builder.pathSegment("id", "../x"), "..%2Fx")
    XCTAssertEqual(try builder.pathSegment("id", "%2E%2E"), "%252E%252E")
  }

  // MARK: - makeUrl

  func test_makeUrl_joinsTheHostBasePathAndPath() throws {
    XCTAssertEqual(
      try builder.makeUrl(path: "/items").absoluteString,
      "https://api.portalhq.io/api/v3/clients/me/integrations/example/items"
    )
  }

  func test_makeUrl_sendsTheQueryInOrderAndEncodesEachValue() throws {
    let url = try builder.makeUrl(path: "/items", query: [("b", "2"), ("a", "x,y z")])

    XCTAssertEqual(url.absoluteString, "https://api.portalhq.io/api/v3/clients/me/integrations/example/items?b=2&a=x%2Cy%20z")
  }

  func test_makeUrl_dropsNilAndEmptyValues() throws {
    let url = try builder.makeUrl(path: "/items", query: [("a", nil), ("b", "1"), ("c", "")])

    XCTAssertEqual(url.absoluteString, "https://api.portalhq.io/api/v3/clients/me/integrations/example/items?b=1")
  }

  func test_makeUrl_hasNoQueryWhenEveryValueIsDropped() throws {
    let url = try builder.makeUrl(path: "/items", query: [("a", nil), ("b", "")])

    XCTAssertEqual(url.absoluteString, "https://api.portalhq.io/api/v3/clients/me/integrations/example/items")
  }
}

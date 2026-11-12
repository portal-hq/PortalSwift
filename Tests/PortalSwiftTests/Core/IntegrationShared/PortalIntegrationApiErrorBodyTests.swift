//
//  PortalIntegrationApiErrorBodyTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalIntegrationApiErrorBodyTests: XCTestCase {
  private static let url = "https://api.portalhq.io/api/v3/clients/me/integrations/example/items"

  func test_parse_readsTheStatusErrorIdAndDetails() {
    let error = PortalRequestsError.clientError(
      #"409 - {"error":"Customer already exists","id":"CUSTOMER_EXISTS","details":{"customerId":"c-1"}}"#,
      url: Self.url
    )

    XCTAssertEqual(
      PortalIntegrationApiErrorBody.parse(error),
      PortalIntegrationApiErrorBody(
        status: 409,
        id: "CUSTOMER_EXISTS",
        message: "Customer already exists",
        details: ["customerId": AnyCodable("c-1")]
      )
    )
  }

  func test_parse_aServerError_readsItsStatusAndBody() {
    let error = PortalRequestsError.internalServerError(#"502 - {"error":"Upstream failed"}"#, url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 502, message: "Upstream failed"))
  }

  func test_parse_aRedirect_readsItsStatus() {
    let error = PortalRequestsError.redirectError(#"302 - {"error":"Moved"}"#)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 302, message: "Moved"))
  }

  func test_parse_unauthorized_is401WithoutABody() {
    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(.unauthorized), PortalIntegrationApiErrorBody(status: 401))
  }

  func test_parse_noHttpResponse_isNil() {
    XCTAssertNil(PortalIntegrationApiErrorBody.parse(.couldNotParseHttpResponse))
  }

  func test_parse_keepsAnErrorMessageThatContainsTheSeparator() {
    let error = PortalRequestsError.clientError(#"400 - {"error":"Invalid amount - must be positive"}"#, url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error)?.message, "Invalid amount - must be positive")
  }

  func test_parse_aBodyThatIsNotJson_isTheMessage() {
    let error = PortalRequestsError.internalServerError("502 - <html>Bad Gateway</html>", url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 502, message: "<html>Bad Gateway</html>"))
  }

  func test_parse_aJsonBodyWithoutAnError_isTheMessage() {
    let body = #"{"message":"not a Portal error"}"#
    let error = PortalRequestsError.clientError("422 - \(body)", url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 422, message: body))
  }

  func test_parse_aJsonBodyThatIsNotAnObject_isTheMessage() {
    let error = PortalRequestsError.clientError("400 - [1,2]", url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 400, message: "[1,2]"))
  }

  func test_parse_anEmptyBody_hasOnlyTheStatus() {
    let error = PortalRequestsError.internalServerError("503 - ", url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: 503))
  }

  func test_parse_aMessageWithoutAStatus_hasNoStatusOrBody() {
    let error = PortalRequestsError.clientError("Bad request", url: Self.url)

    XCTAssertEqual(PortalIntegrationApiErrorBody.parse(error), PortalIntegrationApiErrorBody(status: nil))
  }
}

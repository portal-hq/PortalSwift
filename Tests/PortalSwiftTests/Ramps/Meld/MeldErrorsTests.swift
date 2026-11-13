//
//  MeldErrorsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class MeldErrorsTests: XCTestCase {
  private static let url = "https://api.portalhq.io/api/v3/clients/me/integrations/meld"

  private static func clientError(_ status: Int, _ body: String) -> PortalRequestsError {
    .clientError("\(status) - \(body)", url: url)
  }

  // MARK: - Captured bodies

  func test_duplicateCustomer_readsTheExistingCustomersId() {
    let error = Self.clientError(409, MeldFixtures.errorCustomerDuplicate)

    XCTAssertEqual(
      MeldApiError.from(error),
      MeldApiError(
        status: 409,
        message: "Meld customer already exists for this client. Use GET /customers to retrieve it.",
        meldCustomerId: "meld-customer-1"
      )
    )
  }

  func test_portalValidationFailure_is400WithItsMessage() {
    let error = Self.clientError(400, MeldFixtures.errorQuoteMissingCountry)

    XCTAssertEqual(MeldApiError.from(error), MeldApiError(status: 400, message: "countryCode must be a string."))
  }

  func test_meldsOwnRejections_keepMeldsMessage() {
    let cases = [
      (MeldFixtures.errorQuoteUnsupportedPair, "Meld API error: Invalid Parameters passed "),
      (MeldFixtures.errorTransactionInvalidId, "Meld API error: Not a valid id: does-not-exist"),
      (MeldFixtures.errorWidgetUnknownProvider, "Meld API error: Invalid JSON"),
      (MeldFixtures.errorWidgetClientIpRequired, "Meld API error: clientIpAddress is required for the requested service provider")
    ]

    for (body, message) in cases {
      let apiError = MeldApiError.from(Self.clientError(400, body))
      XCTAssertEqual(apiError?.status, 400)
      XCTAssertEqual(apiError?.message, message)
      XCTAssertNil(apiError?.meldCustomerId)
    }
  }

  // MARK: - Other statuses

  func test_notFound_is404() {
    let error = Self.clientError(404, #"{"error":"Meld transaction does not exist."}"#)

    XCTAssertEqual(MeldApiError.from(error), MeldApiError(status: 404, message: "Meld transaction does not exist."))
  }

  func test_unauthorized_is401WithoutABody() {
    XCTAssertEqual(MeldApiError.from(PortalRequestsError.unauthorized), MeldApiError(status: 401))
  }

  func test_badGatewayWithABodyThatIsNotJson_keepsTheBodyAsTheMessage() {
    let error = PortalRequestsError.internalServerError("502 - <html>Bad Gateway</html>", url: Self.url)

    XCTAssertEqual(MeldApiError.from(error), MeldApiError(status: 502, message: "<html>Bad Gateway</html>"))
  }

  func test_anErrorWithAnId_readsIt() {
    let error = Self.clientError(400, #"{"error":"Drifted","id":"INTEGRATION_RESPONSE_SCHEMA_DRIFT"}"#)

    XCTAssertEqual(MeldApiError.from(error)?.id, "INTEGRATION_RESPONSE_SCHEMA_DRIFT")
  }

  // MARK: - Not HTTP failures

  func test_anErrorThatIsNotAnHttpFailure_isNil() {
    XCTAssertNil(MeldApiError.from(nil))
    XCTAssertNil(MeldApiError.from(PortalRequestsError.couldNotParseHttpResponse))
    XCTAssertNil(MeldApiError.from(MeldError.emptyIdentifier(name: "sessionId")))
    XCTAssertNil(MeldApiError.from(URLError(.notConnectedToInternet)))
    XCTAssertNil(MeldApiError.from(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))))
  }

  func test_aMeldApiError_isReturnedAsIs() {
    let apiError = MeldApiError(status: 409, meldCustomerId: "c1")

    XCTAssertEqual(MeldApiError.from(apiError), apiError)
  }

  // MARK: - MeldError

  func test_emptyIdentifier_namesTheParameter() {
    XCTAssertEqual(MeldError.emptyIdentifier(name: "transactionId").errorDescription, "[Meld] transactionId must not be empty.")
  }
}

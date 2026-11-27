//
//  PortalApiPasskeyPrfTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalApiPasskeyPrfTests: XCTestCase {
  private var requests: PortalRequestsSpy!
  private var api: PortalApi!

  override func setUpWithError() throws {
    requests = PortalRequestsSpy()
    api = PortalApi(credentials: MockConstants.mockCredentials, apiHost: "api.example.test", requests: requests)
  }

  override func tearDownWithError() throws {
    api = nil
    requests = nil
  }

  private let envelope = Data("""
  {
    "data": { "credentialId": "AQID-_8", "rpId": "portalhq.io", "transports": ["internal", "hybrid"] },
    "metadata": { "clientId": "client-id" }
  }
  """.utf8)

  // MARK: - GET

  func test_getPasskeyPrfCredential_requestsTheRecord_andUnwrapsTheEnvelope() async throws {
    requests.returnData = envelope

    let credential = try await api.getPasskeyPrfCredential(traceId: nil)

    XCTAssertEqual(credential, PasskeyPrfCredential(credentialId: "AQID-_8", rpId: "portalhq.io", transports: ["internal", "hybrid"]))
    let request = try XCTUnwrap(requests.executeRequestHistory.last)
    XCTAssertEqual(request.url.absoluteString, "https://api.example.test/api/v3/clients/me/passkey-prf-credential")
    XCTAssertEqual(request.method, .get)
  }

  func test_getPasskeyPrfCredential_withoutTransports_decodes() async throws {
    requests.returnData = Data(#"{"data":{"credentialId":"AQID","rpId":"example.com"},"metadata":{}}"#.utf8)

    let credential = try await api.getPasskeyPrfCredential(traceId: nil)

    XCTAssertEqual(credential, PasskeyPrfCredential(credentialId: "AQID", rpId: "example.com"))
  }

  func test_getPasskeyPrfCredential_rejectsAnUnwrappedBody() async {
    // The web SDK once read the record without unwrapping `data`; this one must not.
    requests.returnData = Data(#"{"credentialId":"AQID","rpId":"example.com"}"#.utf8)

    do {
      _ = try await api.getPasskeyPrfCredential(traceId: nil)
      XCTFail("Expected a decoding error")
    } catch {
      XCTAssertTrue(error is DecodingError)
    }
  }

  func test_getPasskeyPrfCredential_on404_returnsNil() async throws {
    requests.executeThrowableErrorSequence = [PortalRequestsError.clientError("404 - {\"error\":\"not found\"}", url: "u")]

    let credential = try await api.getPasskeyPrfCredential(traceId: nil)

    XCTAssertNil(credential)
  }

  func test_getPasskeyPrfCredential_onOtherErrors_throws() async {
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    requests.executeThrowableErrorSequence = [failure]

    do {
      _ = try await api.getPasskeyPrfCredential(traceId: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
    }
  }

  // MARK: - PUT

  func test_storePasskeyPrfCredential_putsTheRecord_andUnwrapsTheEnvelope() async throws {
    requests.returnData = envelope

    let stored = try await api.storePasskeyPrfCredential(
      PasskeyPrfCredential(credentialId: "AQID-_8", rpId: "portalhq.io", transports: ["internal", "hybrid"]),
      traceId: nil
    )

    XCTAssertEqual(stored.credentialId, "AQID-_8")
    let request = try XCTUnwrap(requests.executeRequestHistory.last)
    XCTAssertEqual(request.url.absoluteString, "https://api.example.test/api/v3/clients/me/passkey-prf-credential")
    XCTAssertEqual(request.method, .put)
    let body = try XCTUnwrap(request.payload as? PasskeyPrfCredential)
    XCTAssertEqual(body.transports, ["internal", "hybrid"])
  }

  func test_passkeyPrfCredential_body_omitsAbsentTransports() throws {
    let body = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(PasskeyPrfCredential(credentialId: "AQID", rpId: "portalhq.io"))
    ) as? [String: Any]

    XCTAssertEqual(body?.keys.sorted(), ["credentialId", "rpId"])
  }

  func test_storePasskeyPrfCredential_on409_throwsAConflict() async {
    requests.executeThrowableErrorSequence = [PortalRequestsError.clientError("409 - conflict", url: "u")]

    do {
      _ = try await api.storePasskeyPrfCredential(PasskeyPrfCredential(credentialId: "AQID", rpId: "portalhq.io"), traceId: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual((error as? PortalRequestsError)?.statusCode, 409)
    }
  }

  // MARK: - Status codes

  func test_portalRequestsError_statusCode() {
    XCTAssertEqual(PortalRequestsError.clientError("404 - body", url: "").statusCode, 404)
    XCTAssertEqual(PortalRequestsError.clientError("409 - a - b", url: "").statusCode, 409)
    XCTAssertEqual(PortalRequestsError.internalServerError("503 - ", url: "").statusCode, 503)
    XCTAssertEqual(PortalRequestsError.redirectError("302 - moved").statusCode, 302)
    XCTAssertNil(PortalRequestsError.unauthorized.statusCode)
    XCTAssertNil(PortalRequestsError.couldNotParseHttpResponse.statusCode)
    XCTAssertNil(PortalRequestsError.clientError("bad", url: "").statusCode)
  }

  // MARK: - Default implementations

  func test_olderApiConformers_reportPasskeyPrfAsUnsupported() async {
    let legacy: PortalApiProtocol = PortalApiSpy()

    do {
      _ = try await legacy.getPasskeyPrfCredential(traceId: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .apiUnsupported)
    }

    do {
      _ = try await legacy.storePasskeyPrfCredential(PasskeyPrfCredential(credentialId: "AQID", rpId: "portalhq.io"), traceId: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .apiUnsupported)
    }
  }
}

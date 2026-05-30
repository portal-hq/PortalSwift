//
//  PortalNoahApiTests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalNoahApiTests: XCTestCase {
  private let encoder = JSONEncoder()

  var api: PortalNoahApi?

  override func setUpWithError() throws {
    self.api = PortalNoahApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      requests: PortalRequestsMock()
    )
  }

  override func tearDownWithError() throws {
    api = nil
  }
}

// MARK: - Test Helpers

extension PortalNoahApiTests {
  func initPortalNoahApiWith(
    apiKey: String = MockConstants.mockApiKey,
    apiHost: String = MockConstants.mockHost,
    requests: PortalRequestsProtocol = PortalRequestsMock()
  ) {
    self.api = PortalNoahApi(
      apiKey: apiKey,
      apiHost: apiHost,
      requests: requests
    )
  }
}

// MARK: - initiateKyc tests

extension PortalNoahApiTests {
  func test_initiateKyc_willReturnCorrectResponse() async throws {
    let mockResponse = NoahInitiateKycResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.initiateKyc(request: .stub())

    XCTAssertNotNil(response)
    XCTAssertEqual(response?.data.hostedUrl, NoahInitiateKycResponse.stub().data.hostedUrl)
  }

  func test_initiateKyc_willCall_executeRequest_onlyOnce() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahInitiateKycResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.initiateKyc(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_initiateKyc_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahInitiateKycResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.initiateKyc(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/customers/kyc")
  }

  func test_initiateKyc_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalNoahApiWith(requests: portalRequestsFailMock)

    do {
      _ = try await api?.initiateKyc(request: .stub())
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - initiatePayin tests

extension PortalNoahApiTests {
  func test_initiatePayin_willReturnCorrectResponse() async throws {
    let mockResponse = NoahInitiatePayinResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.initiatePayin(request: .stub())

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.payinId, "payin-1")
  }

  @available(iOS 16.0, *)
  func test_initiatePayin_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahInitiatePayinResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.initiatePayin(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payins")
  }

  func test_initiatePayin_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalNoahApiWith(requests: portalRequestsFailMock)

    do {
      _ = try await api?.initiatePayin(request: .stub())
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - simulatePayin tests

extension PortalNoahApiTests {
  func test_simulatePayin_willReturnCorrectResponse() async throws {
    let mockResponse = NoahSimulatePayinResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.simulatePayin(request: .stub())

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.fiatDepositId, "fiat-deposit-1")
  }

  @available(iOS 16.0, *)
  func test_simulatePayin_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahSimulatePayinResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.simulatePayin(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payins/simulate")
  }
}

// MARK: - getPaymentMethods tests

extension PortalNoahApiTests {
  func test_getPaymentMethods_willReturnCorrectResponse() async throws {
    let mockResponse = NoahGetPaymentMethodsResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.getPaymentMethods()

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.paymentMethods.count, 1)
  }

  @available(iOS 16.0, *)
  func test_getPaymentMethods_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPaymentMethodsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPaymentMethods()

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payouts/payment-methods")
  }

  @available(iOS 16.0, *)
  func test_getPaymentMethods_willCall_executeRequest_passingCorrectQueryParams() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPaymentMethodsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    let request = NoahGetPaymentMethodsRequest(
      pageSize: 50,
      pageToken: "abc",
      capability: .payinTo
    )

    _ = try await api?.getPaymentMethods(request: request)

    let query = portalRequestsSpy.executeRequestParam?.url.query() ?? ""
    XCTAssertTrue(query.contains("pageSize=50"))
    XCTAssertTrue(query.contains("pageToken=abc"))
    XCTAssertTrue(query.contains("capability=PayinTo"))
  }

  @available(iOS 16.0, *)
  func test_getPaymentMethods_omitsQueryParams_whenAllNil() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPaymentMethodsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPaymentMethods()

    let query = portalRequestsSpy.executeRequestParam?.url.query()
    XCTAssertNil(query)
  }
}

// MARK: - getPayoutCountries tests

extension PortalNoahApiTests {
  func test_getPayoutCountries_willReturnCorrectResponse() async throws {
    let mockResponse = NoahGetPayoutCountriesResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.getPayoutCountries()

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.countries["US"], ["USD"])
  }

  @available(iOS 16.0, *)
  func test_getPayoutCountries_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutCountriesResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPayoutCountries()

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payouts/countries")
  }
}

// MARK: - getPayoutChannels tests

extension PortalNoahApiTests {
  func test_getPayoutChannels_willReturnCorrectResponse() async throws {
    let mockResponse = NoahGetPayoutChannelsResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.getPayoutChannels(request: .stub())

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.items.count, 1)
  }

  @available(iOS 16.0, *)
  func test_getPayoutChannels_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutChannelsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPayoutChannels(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertTrue(portalRequestsSpy.executeRequestParam?.url.path().contains("/api/v3/clients/me/integrations/noah/payouts/channels") ?? false)
  }

  @available(iOS 16.0, *)
  func test_getPayoutChannels_willCall_executeRequest_passingCorrectQueryParams() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutChannelsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    let request = NoahGetPayoutChannelsRequest(
      country: "US",
      cryptoCurrency: "USDC",
      fiatCurrency: "USD",
      fiatAmount: "100.00"
    )

    _ = try await api?.getPayoutChannels(request: request)

    let query = portalRequestsSpy.executeRequestParam?.url.query()
    XCTAssertTrue(query?.contains("country=US") ?? false)
    XCTAssertTrue(query?.contains("cryptoCurrency=USDC") ?? false)
    XCTAssertTrue(query?.contains("fiatCurrency=USD") ?? false)
    XCTAssertTrue(query?.contains("fiatAmount=100.00") ?? false)
  }

  @available(iOS 16.0, *)
  func test_getPayoutChannels_omitsNilFiatAmount() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutChannelsResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    let request = NoahGetPayoutChannelsRequest(
      country: "GB",
      cryptoCurrency: "USDC",
      fiatCurrency: "GBP",
      fiatAmount: nil
    )

    _ = try await api?.getPayoutChannels(request: request)

    let query = portalRequestsSpy.executeRequestParam?.url.query() ?? ""
    XCTAssertFalse(query.contains("fiatAmount="))
    XCTAssertTrue(query.contains("country=GB"))
  }
}

// MARK: - getPayoutChannelForm tests

extension PortalNoahApiTests {
  func test_getPayoutChannelForm_willReturnCorrectResponse() async throws {
    let mockResponse = NoahGetPayoutChannelFormResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.getPayoutChannelForm(channelId: "channel-1")

    XCTAssertNotNil(response?.data)
    XCTAssertNotNil(response?.data.formMetadata)
  }

  @available(iOS 16.0, *)
  func test_getPayoutChannelForm_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutChannelFormResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPayoutChannelForm(channelId: "channel-1")

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payouts/channels/channel-1/form")
  }

  @available(iOS 16.0, *)
  func test_getPayoutChannelForm_percentEncodesChannelId() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutChannelFormResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPayoutChannelForm(channelId: "channel/with spaces & special?")

    let path = portalRequestsSpy.executeRequestParam?.url.path() ?? ""
    XCTAssertTrue(path.contains("/api/v3/clients/me/integrations/noah/payouts/channels/"))
    XCTAssertTrue(path.contains("/form"))
    // raw special characters should not appear unencoded in the path
    XCTAssertFalse(path.contains("channel/with spaces & special?"))
  }

  func test_getPayoutChannelForm_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalNoahApiWith(requests: portalRequestsFailMock)

    do {
      _ = try await api?.getPayoutChannelForm(channelId: "channel-1")
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - getPayoutQuote tests

extension PortalNoahApiTests {
  func test_getPayoutQuote_willReturnCorrectResponse() async throws {
    let mockResponse = NoahGetPayoutQuoteResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.getPayoutQuote(request: .stub())

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.payoutId, "payout-1")
  }

  @available(iOS 16.0, *)
  func test_getPayoutQuote_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutQuoteResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.getPayoutQuote(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payouts/quote")
  }
}

// MARK: - initiatePayout tests

extension PortalNoahApiTests {
  func test_initiatePayout_willReturnCorrectResponse() async throws {
    let mockResponse = NoahInitiatePayoutResponse.stub()
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(mockResponse)
    initPortalNoahApiWith(requests: portalRequestMock)

    let response = try await api?.initiatePayout(request: .stub())

    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data.conditions?.count, 1)
  }

  @available(iOS 16.0, *)
  func test_initiatePayout_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahInitiatePayoutResponse.stub())
    initPortalNoahApiWith(requests: portalRequestsSpy)

    _ = try await api?.initiatePayout(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/noah/payouts")
  }
}

// MARK: - Bearer token tests

extension PortalNoahApiTests {
  @available(iOS 16.0, *)
  func test_initiateKyc_includesBearerToken() async throws {
    let apiKey = "test-noah-key-123"
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahInitiateKycResponse.stub())
    initPortalNoahApiWith(apiKey: apiKey, requests: portalRequestsSpy)

    _ = try await api?.initiateKyc(request: .stub())

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(apiKey)")
  }

  @available(iOS 16.0, *)
  func test_getPayoutCountries_includesBearerToken() async throws {
    let apiKey = "test-noah-key-456"
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try encoder.encode(NoahGetPayoutCountriesResponse.stub())
    initPortalNoahApiWith(apiKey: apiKey, requests: portalRequestsSpy)

    _ = try await api?.getPayoutCountries()

    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(apiKey)")
  }
}

// MARK: - API initialization tests

extension PortalNoahApiTests {
  func test_init_withDefaultHost() {
    let api = PortalNoahApi(apiKey: "test-key")
    XCTAssertNotNil(api)
  }

  func test_init_withLocalhostHost() {
    let api = PortalNoahApi(apiKey: "test-key", apiHost: "localhost:3000")
    XCTAssertNotNil(api)
  }
}

//
//  NoahCodableTests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

final class NoahCodableTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
}

// MARK: - Request round-trips

extension NoahCodableTests {
  func test_initiateKycRequest_roundTrips() throws {
    let original = NoahInitiateKycRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiateKycRequest.self, from: data)
    XCTAssertEqual(decoded.returnUrl, original.returnUrl)
    XCTAssertEqual(decoded.customerType, original.customerType)
    XCTAssertEqual(decoded.fiatOptions?.first?.fiatCurrencyCode, "USD")
    XCTAssertNotNil(decoded.metadata)
    XCTAssertNotNil(decoded.form)
  }

  func test_initiatePayinRequest_roundTrips() throws {
    let original = NoahInitiatePayinRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiatePayinRequest.self, from: data)
    XCTAssertEqual(decoded.fiatCurrency, original.fiatCurrency)
    XCTAssertEqual(decoded.cryptoCurrency, original.cryptoCurrency)
    XCTAssertEqual(decoded.network, original.network)
    XCTAssertEqual(decoded.destinationAddress, original.destinationAddress)
  }

  func test_simulatePayinRequest_roundTrips() throws {
    let original = NoahSimulatePayinRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahSimulatePayinRequest.self, from: data)
    XCTAssertEqual(decoded.paymentMethodId, original.paymentMethodId)
    XCTAssertEqual(decoded.fiatAmount, original.fiatAmount)
    XCTAssertEqual(decoded.fiatCurrency, original.fiatCurrency)
  }

  func test_getPayoutChannelsRequest_roundTrips() throws {
    let original = NoahGetPayoutChannelsRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutChannelsRequest.self, from: data)
    XCTAssertEqual(decoded.country, original.country)
    XCTAssertEqual(decoded.cryptoCurrency, original.cryptoCurrency)
    XCTAssertEqual(decoded.fiatCurrency, original.fiatCurrency)
    XCTAssertEqual(decoded.fiatAmount, original.fiatAmount)
    XCTAssertEqual(decoded.pageToken, original.pageToken)
  }

  func test_getPaymentMethodsRequest_roundTrips() throws {
    let original = NoahGetPaymentMethodsRequest(pageSize: 25, pageToken: "tok-1", capability: .payinTo)
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPaymentMethodsRequest.self, from: data)
    XCTAssertEqual(decoded.pageSize, 25)
    XCTAssertEqual(decoded.pageToken, "tok-1")
    XCTAssertEqual(decoded.capability, .payinTo)
  }

  func test_getPayoutQuoteRequest_roundTrips() throws {
    let original = NoahGetPayoutQuoteRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutQuoteRequest.self, from: data)
    XCTAssertEqual(decoded.channelId, original.channelId)
    XCTAssertEqual(decoded.fiatAmount, original.fiatAmount)
    XCTAssertEqual(decoded.paymentMethodId, original.paymentMethodId)
    XCTAssertNotNil(decoded.form)
  }

  func test_initiatePayoutRequest_roundTrips() throws {
    let original = NoahInitiatePayoutRequest.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiatePayoutRequest.self, from: data)
    XCTAssertEqual(decoded.payoutId, original.payoutId)
    XCTAssertEqual(decoded.sourceAddress, original.sourceAddress)
    XCTAssertEqual(decoded.expiry, original.expiry)
    XCTAssertEqual(decoded.nonce, original.nonce)
    XCTAssertEqual(decoded.network, original.network)
    XCTAssertEqual(decoded.trigger?.type, "SingleOnchainDepositSourceTriggerInput")
  }

  func test_initiatePayoutRequest_triggerUsesPascalCaseKeys() throws {
    let original = NoahInitiatePayoutRequest.stub()
    let data = try encoder.encode(original)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let trigger = try XCTUnwrap(json["trigger"] as? [String: Any])

    XCTAssertEqual(trigger["Type"] as? String, "SingleOnchainDepositSourceTriggerInput")
    XCTAssertNotNil(trigger["Conditions"])
    XCTAssertNotNil(trigger["SourceAddress"])
    XCTAssertNotNil(trigger["Expiry"])
    XCTAssertNotNil(trigger["Nonce"])

    let conditions = try XCTUnwrap(trigger["Conditions"] as? [[String: Any]])
    let firstCondition = try XCTUnwrap(conditions.first)
    XCTAssertNotNil(firstCondition["Network"])
    let amountConditions = try XCTUnwrap(firstCondition["AmountConditions"] as? [[String: Any]])
    let firstAmount = try XCTUnwrap(amountConditions.first)
    XCTAssertEqual(firstAmount["ComparisonOperator"] as? String, "GTEQ")
    XCTAssertNotNil(firstAmount["Value"])
  }
}

// MARK: - Response round-trips

extension NoahCodableTests {
  func test_initiateKycResponse_roundTrips() throws {
    let original = NoahInitiateKycResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiateKycResponse.self, from: data)
    XCTAssertEqual(decoded.data.hostedUrl, original.data.hostedUrl)
    XCTAssertNil(decoded.metadata)
  }

  func test_initiatePayinResponse_roundTrips() throws {
    let original = NoahInitiatePayinResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiatePayinResponse.self, from: data)
    XCTAssertEqual(decoded.data.payinId, original.data.payinId)
    XCTAssertEqual(decoded.data.bankDetails.accountNumber, original.data.bankDetails.accountNumber)
  }

  func test_simulatePayinResponse_roundTrips() throws {
    let original = NoahSimulatePayinResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahSimulatePayinResponse.self, from: data)
    XCTAssertEqual(decoded.data.fiatDepositId, original.data.fiatDepositId)
  }

  func test_getPaymentMethodsResponse_roundTrips() throws {
    let original = NoahGetPaymentMethodsResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPaymentMethodsResponse.self, from: data)
    XCTAssertEqual(decoded.data.paymentMethods.count, original.data.paymentMethods.count)
    XCTAssertEqual(decoded.data.paymentMethods.first?.paymentMethodCategory, "Bank")
    XCTAssertEqual(decoded.data.paymentMethods.first?.country, "US")
    XCTAssertEqual(decoded.data.paymentMethods.first?.displayDetails.type, "BankAccount")
  }

  func test_getPayoutCountriesResponse_roundTrips() throws {
    let original = NoahGetPayoutCountriesResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutCountriesResponse.self, from: data)
    XCTAssertEqual(decoded.data.countries["US"], original.data.countries["US"])
    XCTAssertEqual(decoded.data.countries["GB"], original.data.countries["GB"])
  }

  func test_getPayoutChannelsResponse_roundTrips() throws {
    let original = NoahGetPayoutChannelsResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutChannelsResponse.self, from: data)
    XCTAssertEqual(decoded.data.items.first?.id, original.data.items.first?.id)
    XCTAssertEqual(decoded.data.items.first?.limits.minLimit, original.data.items.first?.limits.minLimit)
    XCTAssertEqual(decoded.data.items.first?.paymentMethodCategory, "Bank")
  }

  func test_getPayoutChannelFormResponse_roundTrips() throws {
    let original = NoahGetPayoutChannelFormResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutChannelFormResponse.self, from: data)
    XCTAssertEqual(decoded.data.formMetadata?.contentHash, original.data.formMetadata?.contentHash)
    XCTAssertNotNil(decoded.data.formSchema)
  }

  func test_getPayoutQuoteResponse_roundTrips() throws {
    let original = NoahGetPayoutQuoteResponse.stub(data: .stub(nextStep: .stub()))
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahGetPayoutQuoteResponse.self, from: data)
    XCTAssertEqual(decoded.data.payoutId, original.data.payoutId)
    XCTAssertEqual(decoded.data.nextStep?.stepId, "step-1")
    XCTAssertEqual(decoded.data.nextStep?.stepType, .dataEntry)
  }

  func test_initiatePayoutResponse_roundTrips() throws {
    let original = NoahInitiatePayoutResponse.stub()
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(NoahInitiatePayoutResponse.self, from: data)
    XCTAssertEqual(decoded.data.destinationAddress, original.data.destinationAddress)
    XCTAssertEqual(decoded.data.conditions?.count, original.data.conditions?.count)
  }
}

// MARK: - Envelope behaviour

extension NoahCodableTests {
  func test_response_decodes_dataOnly_envelope() throws {
    let json = """
    { "data": { "hostedUrl": "https://noah.example.com/kyc/xyz" } }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(NoahInitiateKycResponse.self, from: json)
    XCTAssertEqual(decoded.data.hostedUrl, "https://noah.example.com/kyc/xyz")
    XCTAssertNil(decoded.metadata)
  }

  func test_response_decodes_dataWithMetadata_envelope() throws {
    let json = """
    {
      "data": { "hostedUrl": "https://x" },
      "metadata": { "anything": "goes" }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(NoahInitiateKycResponse.self, from: json)
    XCTAssertEqual(decoded.data.hostedUrl, "https://x")
    XCTAssertEqual(decoded.metadata?["anything"]?.value as? String, "goes")
  }
}

// MARK: - AnyCodable fields

extension NoahCodableTests {
  func test_kycRequest_encodesAnyCodableMetadataAsJsonObject() throws {
    let request = NoahInitiateKycRequest(
      returnUrl: "https://example.com",
      metadata: [
        "userId": AnyCodable("user-1"),
        "count": AnyCodable(42)
      ]
    )

    let data = try encoder.encode(request)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
    XCTAssertEqual(metadata["userId"] as? String, "user-1")
    XCTAssertEqual(metadata["count"] as? Int, 42)
  }

  func test_payoutQuoteRequest_encodesAnyCodableFormAsJsonObject() throws {
    let request = NoahGetPayoutQuoteRequest(
      channelId: "ch-1",
      cryptoCurrency: "USDC",
      fiatAmount: "1",
      form: [
        "accountNumber": AnyCodable("1234"),
        "country": AnyCodable("US")
      ]
    )

    let data = try encoder.encode(request)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let form = try XCTUnwrap(json["form"] as? [String: Any])
    XCTAssertEqual(form["accountNumber"] as? String, "1234")
    XCTAssertEqual(form["country"] as? String, "US")
  }
}

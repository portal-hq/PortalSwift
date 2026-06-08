//
//  Noah.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation
@testable import PortalSwift

// MARK: - Common Types

extension NoahBankAddress {
  static func stub(
    street: String? = "1 Market Street",
    street2: String? = nil,
    city: String? = "San Francisco",
    postCode: String? = "94105",
    state: String? = "CA",
    country: String? = "US"
  ) -> Self {
    NoahBankAddress(
      street: street,
      street2: street2,
      city: city,
      postCode: postCode,
      state: state,
      country: country
    )
  }
}

extension NoahFeeDetails {
  static func stub(
    fiatCurrencyCode: String = "USD",
    totalFeePct: String = "0.5",
    totalFeeBase: String = "0.25",
    totalFeeMin: String = "1.00"
  ) -> Self {
    NoahFeeDetails(
      fiatCurrencyCode: fiatCurrencyCode,
      totalFeePct: totalFeePct,
      totalFeeBase: totalFeeBase,
      totalFeeMin: totalFeeMin
    )
  }
}

extension NoahPersonName {
  static func stub(
    firstName: String = "John",
    lastName: String = "Doe",
    middleName: String? = nil
  ) -> Self {
    NoahPersonName(
      firstName: firstName,
      lastName: lastName,
      middleName: middleName
    )
  }
}

extension NoahBankToAddressRelatedPaymentMethodDetails {
  static func stub(accountNumber: String? = "1234567890", bankCode: String? = "BANKUS33") -> Self {
    NoahBankToAddressRelatedPaymentMethodDetails(accountNumber: accountNumber, bankCode: bankCode)
  }
}

extension NoahBankToAddressRelatedPaymentMethod {
  static func stub(
    paymentMethodId: String = "pm-related-1",
    paymentMethodType: String = "BankAch",
    fee: NoahFeeDetails = .stub(),
    details: NoahBankToAddressRelatedPaymentMethodDetails? = .stub()
  ) -> Self {
    NoahBankToAddressRelatedPaymentMethod(
      paymentMethodId: paymentMethodId,
      paymentMethodType: paymentMethodType,
      fee: fee,
      details: details
    )
  }
}

extension NoahBankDetails {
  static func stub(
    paymentMethodId: String = "pm-1",
    paymentMethodType: String = "BankAch",
    accountNumber: String = "1111222233",
    cryptoCurrency: String = "USDC",
    network: String = "ACH",
    fee: NoahFeeDetails = .stub(),
    accountHolderName: String? = "John Doe",
    bankCode: String? = "BANKUS33",
    bankName: String? = "Test Bank",
    bankAddress: NoahBankAddress? = .stub(),
    reference: String? = "REF-1",
    relatedPaymentMethods: [NoahBankToAddressRelatedPaymentMethod]? = [.stub()]
  ) -> Self {
    NoahBankDetails(
      paymentMethodId: paymentMethodId,
      paymentMethodType: paymentMethodType,
      accountNumber: accountNumber,
      cryptoCurrency: cryptoCurrency,
      network: network,
      fee: fee,
      accountHolderName: accountHolderName,
      bankCode: bankCode,
      bankName: bankName,
      bankAddress: bankAddress,
      reference: reference,
      relatedPaymentMethods: relatedPaymentMethods
    )
  }
}

extension NoahChannelLimits {
  static func stub(minLimit: String = "10.00", maxLimit: String? = "1000.00") -> Self {
    NoahChannelLimits(minLimit: minLimit, maxLimit: maxLimit)
  }
}

extension NoahChannelCalculated {
  static func stub(totalFee: String = "1.25") -> Self {
    NoahChannelCalculated(totalFee: totalFee)
  }
}

extension NoahChannel {
  static func stub(
    id: String = "channel-1",
    paymentMethodCategory: String = "Bank",
    paymentMethodType: String = "BankAch",
    fiatCurrency: String = "USD",
    country: String = "US",
    limits: NoahChannelLimits = .stub(),
    rate: String = "1.00",
    processingSeconds: Int = 3600,
    calculated: NoahChannelCalculated? = .stub(),
    paymentMethods: [NoahChannelPaymentMethodDisplay]? = nil,
    processingTier: String? = nil,
    formSchema: [String: AnyCodable]? = nil,
    formMetadata: NoahFormMetadata? = nil,
    issuer: String? = nil
  ) -> Self {
    NoahChannel(
      id: id,
      paymentMethodCategory: paymentMethodCategory,
      paymentMethodType: paymentMethodType,
      fiatCurrency: fiatCurrency,
      country: country,
      limits: limits,
      rate: rate,
      processingSeconds: processingSeconds,
      calculated: calculated,
      paymentMethods: paymentMethods,
      processingTier: processingTier,
      formSchema: formSchema,
      formMetadata: formMetadata,
      issuer: issuer
    )
  }
}

extension NoahPaymentMethodDisplayDetails {
  static func stub(
    type: String = "BankAccount",
    accountNumber: String? = "1111222233",
    bankCode: String? = "BANKUS33",
    last4: String? = "2233",
    scheme: String? = "ACH",
    identifierType: String? = "IBAN",
    identifier: String? = "US00BANKUS3300001111222233"
  ) -> Self {
    NoahPaymentMethodDisplayDetails(
      type: type,
      accountNumber: accountNumber,
      bankCode: bankCode,
      last4: last4,
      scheme: scheme,
      identifierType: identifierType,
      identifier: identifier
    )
  }
}

extension NoahPaymentMethodCapabilities {
  static func stub(payoutFrom: Bool = false, payinTo: Bool = true, payoutTo: Bool = true) -> Self {
    NoahPaymentMethodCapabilities(payoutFrom: payoutFrom, payinTo: payinTo, payoutTo: payoutTo)
  }
}

extension NoahAccountHolderDetails {
  static func stub(name: NoahPersonName? = .stub()) -> Self {
    NoahAccountHolderDetails(name: name)
  }
}

extension NoahIssuerDetails {
  static func stub(name: String? = "Issuer Name") -> Self {
    NoahIssuerDetails(name: name)
  }
}

extension NoahPaymentMethod {
  static func stub(
    id: String = "pm-1",
    paymentMethodCategory: String = "Bank",
    country: String = "US",
    displayDetails: NoahPaymentMethodDisplayDetails = .stub(),
    customerId: String? = "customer-1",
    capabilities: NoahPaymentMethodCapabilities? = .stub(),
    accountHolderDetails: NoahAccountHolderDetails? = .stub(),
    issuerDetails: NoahIssuerDetails? = .stub()
  ) -> Self {
    NoahPaymentMethod(
      id: id,
      paymentMethodCategory: paymentMethodCategory,
      country: country,
      displayDetails: displayDetails,
      customerId: customerId,
      capabilities: capabilities,
      accountHolderDetails: accountHolderDetails,
      issuerDetails: issuerDetails
    )
  }
}

extension NoahFormNextStep {
  static func stub(
    stepId: String = "step-1",
    stepType: NoahFormNextStepType = .dataEntry,
    schema: [String: AnyCodable]? = ["field": AnyCodable("value")]
  ) -> Self {
    NoahFormNextStep(stepId: stepId, stepType: stepType, schema: schema)
  }
}

extension NoahAmountCondition {
  static func stub(comparisonOperator: NoahComparisonOperator = .gteq, value: String = "0") -> Self {
    NoahAmountCondition(comparisonOperator: comparisonOperator, value: value)
  }
}

extension NoahDepositSourceTriggerCondition {
  static func stub(
    amountConditions: [NoahAmountCondition] = [.stub()],
    cryptoCurrency: String = "USDC",
    network: String = "Ethereum",
    destinationAddress: String = "0x0000000000000000000000000000000000000000"
  ) -> Self {
    NoahDepositSourceTriggerCondition(
      amountConditions: amountConditions,
      cryptoCurrency: cryptoCurrency,
      network: network,
      destinationAddress: destinationAddress
    )
  }
}

extension NoahSingleOnchainDepositSourceTriggerAmountCondition {
  static func stub(comparisonOperator: NoahComparisonOperator = .gteq, value: String = "1") -> Self {
    NoahSingleOnchainDepositSourceTriggerAmountCondition(comparisonOperator: comparisonOperator, value: value)
  }
}

extension NoahSingleOnchainDepositSourceTriggerCondition {
  static func stub(
    amountConditions: [NoahSingleOnchainDepositSourceTriggerAmountCondition] = [.stub()],
    network: String = NoahNetwork.ethereum
  ) -> Self {
    NoahSingleOnchainDepositSourceTriggerCondition(amountConditions: amountConditions, network: network)
  }
}

extension NoahSingleOnchainDepositSourceTriggerInput {
  static func stub(
    type: String = "SingleOnchainDepositSourceTriggerInput",
    conditions: [NoahSingleOnchainDepositSourceTriggerCondition] = [.stub()],
    sourceAddress: String = "0x1111111111111111111111111111111111111111",
    expiry: String = "2099-01-01T00:00:00Z",
    nonce: String = "nonce-1"
  ) -> Self {
    NoahSingleOnchainDepositSourceTriggerInput(
      type: type,
      conditions: conditions,
      sourceAddress: sourceAddress,
      expiry: expiry,
      nonce: nonce
    )
  }
}

// MARK: - InitiateKyc

extension NoahFiatOption {
  static func stub(fiatCurrencyCode: String = "USD") -> Self {
    NoahFiatOption(fiatCurrencyCode: fiatCurrencyCode)
  }
}

extension NoahInitiateKycRequest {
  static func stub(
    returnUrl: String = "https://example.com/return",
    fiatOptions: [NoahFiatOption]? = [.stub()],
    customerType: NoahCustomerType? = .individual,
    metadata: [String: AnyCodable]? = ["userId": AnyCodable("user-1")],
    form: [String: AnyCodable]? = ["firstName": AnyCodable("John")]
  ) -> Self {
    NoahInitiateKycRequest(
      returnUrl: returnUrl,
      fiatOptions: fiatOptions,
      customerType: customerType,
      metadata: metadata,
      form: form
    )
  }
}

extension NoahInitiateKycData {
  static func stub(hostedUrl: String = "https://noah.example.com/kyc/abc") -> Self {
    NoahInitiateKycData(hostedUrl: hostedUrl)
  }
}

extension NoahInitiateKycResponse {
  static func stub(data: NoahInitiateKycData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahInitiateKycResponse(data: data, metadata: metadata)
  }
}

// MARK: - InitiatePayin

extension NoahInitiatePayinRequest {
  static func stub(
    fiatCurrency: String = "USD",
    cryptoCurrency: String = "USDC",
    network: String = NoahNetwork.ethereum,
    destinationAddress: String = "0x0000000000000000000000000000000000000000"
  ) -> Self {
    NoahInitiatePayinRequest(
      fiatCurrency: fiatCurrency,
      cryptoCurrency: cryptoCurrency,
      network: network,
      destinationAddress: destinationAddress
    )
  }
}

extension NoahInitiatePayinData {
  static func stub(payinId: String = "payin-1", bankDetails: NoahBankDetails = .stub()) -> Self {
    NoahInitiatePayinData(payinId: payinId, bankDetails: bankDetails)
  }
}

extension NoahInitiatePayinResponse {
  static func stub(data: NoahInitiatePayinData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahInitiatePayinResponse(data: data, metadata: metadata)
  }
}

// MARK: - SimulatePayin

extension NoahSimulatePayinRequest {
  static func stub(
    paymentMethodId: String = "pm-1",
    fiatAmount: String = "100.00",
    fiatCurrency: String = "USD"
  ) -> Self {
    NoahSimulatePayinRequest(
      paymentMethodId: paymentMethodId,
      fiatAmount: fiatAmount,
      fiatCurrency: fiatCurrency
    )
  }
}

extension NoahSimulatePayinData {
  static func stub(fiatDepositId: String = "fiat-deposit-1", reference: String? = nil) -> Self {
    NoahSimulatePayinData(fiatDepositId: fiatDepositId, reference: reference)
  }
}

extension NoahSimulatePayinResponse {
  static func stub(data: NoahSimulatePayinData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahSimulatePayinResponse(data: data, metadata: metadata)
  }
}

// MARK: - GetPayoutCountries

extension NoahGetPayoutCountriesData {
  static func stub(countries: [String: [String]] = ["US": ["USD"], "GB": ["GBP", "EUR"]]) -> Self {
    NoahGetPayoutCountriesData(countries: countries)
  }
}

extension NoahGetPayoutCountriesResponse {
  static func stub(data: NoahGetPayoutCountriesData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahGetPayoutCountriesResponse(data: data, metadata: metadata)
  }
}

// MARK: - GetPayoutChannels

extension NoahGetPayoutChannelsRequest {
  static func stub(
    country: String = "US",
    cryptoCurrency: String = "USDC",
    fiatCurrency: String = "USD",
    fiatAmount: String? = "100.00",
    pageToken: String? = nil
  ) -> Self {
    NoahGetPayoutChannelsRequest(
      country: country,
      cryptoCurrency: cryptoCurrency,
      fiatCurrency: fiatCurrency,
      fiatAmount: fiatAmount,
      pageToken: pageToken
    )
  }
}

extension NoahGetPayoutChannelsData {
  static func stub(items: [NoahChannel] = [.stub()], pageToken: String? = nil) -> Self {
    NoahGetPayoutChannelsData(items: items, pageToken: pageToken)
  }
}

extension NoahGetPayoutChannelsResponse {
  static func stub(data: NoahGetPayoutChannelsData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahGetPayoutChannelsResponse(data: data, metadata: metadata)
  }
}

// MARK: - GetPayoutChannelForm

extension NoahFormMetadata {
  static func stub(contentHash: String = "sha256:abc") -> Self {
    NoahFormMetadata(contentHash: contentHash)
  }
}

extension NoahGetPayoutChannelFormData {
  static func stub(
    formSchema: [String: AnyCodable]? = ["type": AnyCodable("object")],
    formMetadata: NoahFormMetadata? = .stub()
  ) -> Self {
    NoahGetPayoutChannelFormData(formSchema: formSchema, formMetadata: formMetadata)
  }
}

extension NoahGetPayoutChannelFormResponse {
  static func stub(data: NoahGetPayoutChannelFormData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahGetPayoutChannelFormResponse(data: data, metadata: metadata)
  }
}

// MARK: - GetPaymentMethods

extension NoahGetPaymentMethodsRequest {
  static func stub(
    pageSize: Int? = nil,
    pageToken: String? = nil,
    capability: NoahPaymentMethodCapability? = nil
  ) -> Self {
    NoahGetPaymentMethodsRequest(pageSize: pageSize, pageToken: pageToken, capability: capability)
  }
}

extension NoahGetPaymentMethodsData {
  static func stub(paymentMethods: [NoahPaymentMethod] = [.stub()], pageToken: String? = nil) -> Self {
    NoahGetPaymentMethodsData(paymentMethods: paymentMethods, pageToken: pageToken)
  }
}

extension NoahGetPaymentMethodsResponse {
  static func stub(data: NoahGetPaymentMethodsData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahGetPaymentMethodsResponse(data: data, metadata: metadata)
  }
}

// MARK: - GetPayoutQuote

extension NoahGetPayoutQuoteRequest {
  static func stub(
    channelId: String = "channel-1",
    cryptoCurrency: String = "USDC",
    fiatAmount: String = "100.00",
    form: [String: AnyCodable]? = ["accountNumber": AnyCodable("1111222233")],
    fiatCurrency: String? = "USD",
    paymentMethodId: String? = "pm-1"
  ) -> Self {
    NoahGetPayoutQuoteRequest(
      channelId: channelId,
      cryptoCurrency: cryptoCurrency,
      fiatAmount: fiatAmount,
      form: form,
      fiatCurrency: fiatCurrency,
      paymentMethodId: paymentMethodId
    )
  }
}

extension NoahGetPayoutQuoteData {
  static func stub(
    payoutId: String = "payout-1",
    totalFee: String = "1.25",
    cryptoAmountEstimate: String = "101.25",
    cryptoAuthorizedAmount: String = "101.25",
    formSessionId: String = "session-1",
    rate: String? = nil,
    breakdown: [NoahTransactionBreakdownItem]? = nil,
    quote: NoahSellQuote? = nil,
    nextStep: NoahFormNextStep? = nil
  ) -> Self {
    NoahGetPayoutQuoteData(
      payoutId: payoutId,
      totalFee: totalFee,
      cryptoAmountEstimate: cryptoAmountEstimate,
      cryptoAuthorizedAmount: cryptoAuthorizedAmount,
      formSessionId: formSessionId,
      rate: rate,
      breakdown: breakdown,
      quote: quote,
      nextStep: nextStep
    )
  }
}

extension NoahGetPayoutQuoteResponse {
  static func stub(data: NoahGetPayoutQuoteData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahGetPayoutQuoteResponse(data: data, metadata: metadata)
  }
}

// MARK: - InitiatePayout

extension NoahInitiatePayoutRequest {
  static func stub(
    payoutId: String = "payout-1",
    sourceAddress: String = "0x1111111111111111111111111111111111111111",
    expiry: String = "2099-01-01T00:00:00Z",
    nonce: String = "nonce-1",
    network: String = NoahNetwork.ethereum,
    trigger: NoahSingleOnchainDepositSourceTriggerInput? = .stub()
  ) -> Self {
    NoahInitiatePayoutRequest(
      payoutId: payoutId,
      sourceAddress: sourceAddress,
      expiry: expiry,
      nonce: nonce,
      network: network,
      trigger: trigger
    )
  }
}

extension NoahInitiatePayoutData {
  static func stub(
    destinationAddress: String? = "0x2222222222222222222222222222222222222222",
    conditions: [NoahDepositSourceTriggerCondition]? = [.stub()],
    ruleId: String? = nil
  ) -> Self {
    NoahInitiatePayoutData(destinationAddress: destinationAddress, conditions: conditions, ruleId: ruleId)
  }
}

extension NoahInitiatePayoutResponse {
  static func stub(data: NoahInitiatePayoutData = .stub(), metadata: NoahResponseMetadata? = nil) -> Self {
    NoahInitiatePayoutResponse(data: data, metadata: metadata)
  }
}

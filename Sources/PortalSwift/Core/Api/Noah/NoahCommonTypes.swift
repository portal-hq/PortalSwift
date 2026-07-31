//
//  NoahCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

// MARK: - Customer type

/// Noah customer type. Validated server-side by `isNoahCustomerType` in connect-api.
public enum NoahCustomerType: String, Codable {
  case individual = "Individual"
  case business = "Business"
}

// MARK: - Payment method capability (request filter)

/// Capability filter accepted by the `getPaymentMethods` request.
/// Validated by `isNoahPaymentMethodCapability` in connect-api.
public enum NoahPaymentMethodCapability: String, Codable {
  case payoutFrom = "PayoutFrom"
  case payinTo = "PayinTo"
  case payoutTo = "PayoutTo"
}

// MARK: - Comparison operator (payout trigger)

/// Comparison operator accepted by Noah's `AmountCondition`. The BFF currently
/// forwards this string to Noah unchanged; Noah accepts `EQ`, `LTEQ`, or `GTEQ`.
public enum NoahComparisonOperator: String, Codable {
  case eq = "EQ"
  case lteq = "LTEQ"
  case gteq = "GTEQ"
}

// MARK: - Address

/// Bank address shape returned by Noah. Mirrors connect-api's `NoahBankAddress`
/// after the BFF's pascal-to-camel formatter
/// (`Street`/`Street2`/`City`/`PostCode`/`State`/`Country`).
public struct NoahBankAddress: Codable {
  public let street: String?
  public let street2: String?
  public let city: String?
  public let postCode: String?
  public let state: String?
  public let country: String?

  public init(
    street: String? = nil,
    street2: String? = nil,
    city: String? = nil,
    postCode: String? = nil,
    state: String? = nil,
    country: String? = nil
  ) {
    self.street = street
    self.street2 = street2
    self.city = city
    self.postCode = postCode
    self.state = state
    self.country = country
  }
}

// MARK: - Fee details

/// Fee breakdown returned with payin bank details. Mirrors connect-api's
/// `NoahFeeDetails`.
public struct NoahFeeDetails: Codable {
  public let fiatCurrencyCode: String
  public let totalFeePct: String
  public let totalFeeBase: String
  public let totalFeeMin: String

  public init(
    fiatCurrencyCode: String,
    totalFeePct: String,
    totalFeeBase: String,
    totalFeeMin: String
  ) {
    self.fiatCurrencyCode = fiatCurrencyCode
    self.totalFeePct = totalFeePct
    self.totalFeeBase = totalFeeBase
    self.totalFeeMin = totalFeeMin
  }
}

// MARK: - Payin (bank details)

/// Bank-side payment method related to a payin destination address.
public struct NoahBankToAddressRelatedPaymentMethod: Codable {
  public let paymentMethodId: String
  /// Specific payment method type such as `"BankSepa"` or `"IdentifierPix"`.
  public let paymentMethodType: String
  public let fee: NoahFeeDetails
  public let details: NoahBankToAddressRelatedPaymentMethodDetails?

  public init(
    paymentMethodId: String,
    paymentMethodType: String,
    fee: NoahFeeDetails,
    details: NoahBankToAddressRelatedPaymentMethodDetails? = nil
  ) {
    self.paymentMethodId = paymentMethodId
    self.paymentMethodType = paymentMethodType
    self.fee = fee
    self.details = details
  }
}

public struct NoahBankToAddressRelatedPaymentMethodDetails: Codable {
  public let accountNumber: String?
  public let bankCode: String?

  public init(accountNumber: String? = nil, bankCode: String? = nil) {
    self.accountNumber = accountNumber
    self.bankCode = bankCode
  }
}

/// Bank details returned with a Noah payin (on-ramp deposit instructions).
public struct NoahBankDetails: Codable {
  public let paymentMethodId: String
  /// Specific payment method type such as `"BankSepa"` or `"IdentifierPix"`.
  public let paymentMethodType: String
  public let accountNumber: String
  public let cryptoCurrency: String
  public let network: String
  public let fee: NoahFeeDetails
  public let accountHolderName: String?
  public let bankCode: String?
  public let bankName: String?
  public let bankAddress: NoahBankAddress?
  public let reference: String?
  public let relatedPaymentMethods: [NoahBankToAddressRelatedPaymentMethod]?

  public init(
    paymentMethodId: String,
    paymentMethodType: String,
    accountNumber: String,
    cryptoCurrency: String,
    network: String,
    fee: NoahFeeDetails,
    accountHolderName: String? = nil,
    bankCode: String? = nil,
    bankName: String? = nil,
    bankAddress: NoahBankAddress? = nil,
    reference: String? = nil,
    relatedPaymentMethods: [NoahBankToAddressRelatedPaymentMethod]? = nil
  ) {
    self.paymentMethodId = paymentMethodId
    self.paymentMethodType = paymentMethodType
    self.accountNumber = accountNumber
    self.cryptoCurrency = cryptoCurrency
    self.network = network
    self.fee = fee
    self.accountHolderName = accountHolderName
    self.bankCode = bankCode
    self.bankName = bankName
    self.bankAddress = bankAddress
    self.reference = reference
    self.relatedPaymentMethods = relatedPaymentMethods
  }
}

// MARK: - Payout channels

/// Min/max payout limits for a Noah payout channel.
public struct NoahChannelLimits: Codable {
  public let minLimit: String
  public let maxLimit: String?

  public init(minLimit: String, maxLimit: String? = nil) {
    self.minLimit = minLimit
    self.maxLimit = maxLimit
  }
}

/// Pre-calculated values (e.g. total fee) returned for a payout channel.
public struct NoahChannelCalculated: Codable {
  public let totalFee: String

  public init(totalFee: String) {
    self.totalFee = totalFee
  }
}

/// A Noah payout channel describing a way to off-ramp into fiat.
///
/// Mirrors the shape emitted by connect-api's `Channel` (after the BFF's
/// pascal-to-camel formatter). Many fields are optional because they're only
/// populated for certain customer / channel / query combinations.
public struct NoahChannel: Codable {
  public let id: String
  /// Broad grouping such as `"Bank"`, `"Card"`, or `"Identifier"`.
  public let paymentMethodCategory: String
  /// Specific payment method type such as `"BankSepa"` or `"IdentifierPix"`.
  public let paymentMethodType: String
  public let fiatCurrency: String
  public let country: String
  public let limits: NoahChannelLimits
  public let rate: String
  public let processingSeconds: Int
  public let calculated: NoahChannelCalculated?
  /// Recent payment methods, only populated if a customer id was supplied.
  public let paymentMethods: [NoahChannelPaymentMethodDisplay]?
  /// Settlement speed tier such as `"Standard"` or `"Priority"`.
  public let processingTier: String?
  /// Inline JSON-Schema for the channel's payout form. Use this instead of
  /// `getPayoutChannelForm` whenever it's present to save a round-trip.
  // TODO: revisit -- strongly type once backend schema is finalized.
  public let formSchema: [String: AnyCodable]?
  public let formMetadata: NoahFormMetadata?
  public let issuer: String?

  public init(
    id: String,
    paymentMethodCategory: String,
    paymentMethodType: String,
    fiatCurrency: String,
    country: String,
    limits: NoahChannelLimits,
    rate: String,
    processingSeconds: Int,
    calculated: NoahChannelCalculated? = nil,
    paymentMethods: [NoahChannelPaymentMethodDisplay]? = nil,
    processingTier: String? = nil,
    formSchema: [String: AnyCodable]? = nil,
    formMetadata: NoahFormMetadata? = nil,
    issuer: String? = nil
  ) {
    self.id = id
    self.paymentMethodCategory = paymentMethodCategory
    self.paymentMethodType = paymentMethodType
    self.fiatCurrency = fiatCurrency
    self.country = country
    self.limits = limits
    self.rate = rate
    self.processingSeconds = processingSeconds
    self.calculated = calculated
    self.paymentMethods = paymentMethods
    self.processingTier = processingTier
    self.formSchema = formSchema
    self.formMetadata = formMetadata
    self.issuer = issuer
  }
}

/// Display payload for a recent payment method attached to a channel.
public struct NoahChannelPaymentMethodDisplay: Codable {
  public let id: String
  /// Specific payment method type such as `"BankSepa"` or `"IdentifierPix"`.
  public let paymentMethodType: String
  public let details: NoahPaymentMethodDisplayDetails
  public let accountHolderDetails: NoahAccountHolderDetails?
  public let issuerDetails: NoahIssuerDetails?

  public init(
    id: String,
    paymentMethodType: String,
    details: NoahPaymentMethodDisplayDetails,
    accountHolderDetails: NoahAccountHolderDetails? = nil,
    issuerDetails: NoahIssuerDetails? = nil
  ) {
    self.id = id
    self.paymentMethodType = paymentMethodType
    self.details = details
    self.accountHolderDetails = accountHolderDetails
    self.issuerDetails = issuerDetails
  }
}

/// Metadata describing the schema content for a Noah form (channel-form or
/// channel inline form).
public struct NoahFormMetadata: Codable {
  public let contentHash: String

  public init(contentHash: String) {
    self.contentHash = contentHash
  }
}

// MARK: - Payment methods

/// Per-method display details (bank/card/identifier shapes flattened by the BFF).
public struct NoahPaymentMethodDisplayDetails: Codable {
  public let type: String
  public let accountNumber: String?
  public let bankCode: String?
  public let bankAddress: NoahBankAddress?
  public let last4: String?
  public let scheme: String?
  public let identifierType: String?
  public let identifier: String?

  public init(
    type: String,
    accountNumber: String? = nil,
    bankCode: String? = nil,
    bankAddress: NoahBankAddress? = nil,
    last4: String? = nil,
    scheme: String? = nil,
    identifierType: String? = nil,
    identifier: String? = nil
  ) {
    self.type = type
    self.accountNumber = accountNumber
    self.bankCode = bankCode
    self.bankAddress = bankAddress
    self.last4 = last4
    self.scheme = scheme
    self.identifierType = identifierType
    self.identifier = identifier
  }
}

/// Per-payment-method capability flags (which Noah flows the method can be used in).
public struct NoahPaymentMethodCapabilities: Codable {
  public let payoutFrom: Bool
  public let payinTo: Bool
  public let payoutTo: Bool

  public init(payoutFrom: Bool, payinTo: Bool, payoutTo: Bool) {
    self.payoutFrom = payoutFrom
    self.payinTo = payinTo
    self.payoutTo = payoutTo
  }
}


public struct NoahPersonName: Codable {
  public let firstName: String
  public let lastName: String
  public let middleName: String?

  public init(
    firstName: String,
    lastName: String,
    middleName: String? = nil
  ) {
    self.firstName = firstName
    self.lastName = lastName
    self.middleName = middleName
  }
}

/// Information about the holder of a Noah payment method.
///
/// Mirrors connect-api's `AccountHolderDetails`, which only carries the
/// holder's structured `name`.
public struct NoahAccountHolderDetails: Codable {
  public let name: NoahPersonName?

  public init(name: NoahPersonName? = nil) {
    self.name = name
  }
}

/// Information about the issuer (e.g. bank) of a Noah payment method.
///
/// Mirrors connect-api's `IssuerDetails`, which only carries an optional `name`.
public struct NoahIssuerDetails: Codable {
  public let name: String?

  public init(name: String? = nil) {
    self.name = name
  }
}

/// A saved Noah payment method available to the current customer.
///
/// Field shape matches what connect-api's `getPaymentMethods` returns after
/// pascal-to-camel formatting: `id`, `paymentMethodCategory`, `country`,
/// `displayDetails`, and optional `customerId` / `capabilities`.
public struct NoahPaymentMethod: Codable {
  public let id: String
  /// Broad grouping such as `"Bank"`, `"Card"`, or `"Identifier"`.
  public let paymentMethodCategory: String
  public let country: String
  public let displayDetails: NoahPaymentMethodDisplayDetails
  public let customerId: String?
  public let capabilities: NoahPaymentMethodCapabilities?
  public let accountHolderDetails: NoahAccountHolderDetails?
  public let issuerDetails: NoahIssuerDetails?

  public init(
    id: String,
    paymentMethodCategory: String,
    country: String,
    displayDetails: NoahPaymentMethodDisplayDetails,
    customerId: String? = nil,
    capabilities: NoahPaymentMethodCapabilities? = nil,
    accountHolderDetails: NoahAccountHolderDetails? = nil,
    issuerDetails: NoahIssuerDetails? = nil
  ) {
    self.id = id
    self.paymentMethodCategory = paymentMethodCategory
    self.country = country
    self.displayDetails = displayDetails
    self.customerId = customerId
    self.capabilities = capabilities
    self.accountHolderDetails = accountHolderDetails
    self.issuerDetails = issuerDetails
  }
}

// MARK: - Multi-step form

/// Type of a Noah form step.
public enum NoahFormNextStepType: String, Codable {
  case ack = "Ack"
  case dataEntry = "DataEntry"
}

/// Next step in a Noah multi-step form flow.
///
/// Per connect-api `FormNextStep`, `schema` is required when `nextStep` is
/// present. We keep it optional in the SDK to be defensive against missing
/// fields and avoid hard-decode failures.
public struct NoahFormNextStep: Codable {
  public let stepId: String
  public let stepType: NoahFormNextStepType
  // TODO: revisit -- strongly type once backend schema is finalized.
  public let schema: [String: AnyCodable]?

  public init(
    stepId: String,
    stepType: NoahFormNextStepType,
    schema: [String: AnyCodable]? = nil
  ) {
    self.stepId = stepId
    self.stepType = stepType
    self.schema = schema
  }
}

// MARK: - Payout conditions

/// Comparison condition applied to a payout amount.
///
/// `comparisonOperator` is a string for forward-compatibility with new
/// Noah-supported operators, but the canonical values are `EQ`, `LTEQ`, and
/// `GTEQ` — use `NoahComparisonOperator` to construct them safely.
public struct NoahAmountCondition: Codable {
  public let comparisonOperator: String
  public let value: String

  public init(comparisonOperator: String, value: String) {
    self.comparisonOperator = comparisonOperator
    self.value = value
  }

  public init(comparisonOperator: NoahComparisonOperator, value: String) {
    self.comparisonOperator = comparisonOperator.rawValue
    self.value = value
  }
}

/// Condition that must be met for the on-chain deposit to be picked up by Noah.
///
/// - Note: `destinationAddress` is typed as a flat `String` to match
///   connect-api's `DepositSourceTriggerCondition.DestinationAddress: string`.
///   Upstream Noah's OpenAPI describes this field as `{ Address: string }`, so
///   if the BFF starts emitting a nested object this struct will fail to
///   decode and we'll need to update both sides.
public struct NoahDepositSourceTriggerCondition: Codable {
  public let amountConditions: [NoahAmountCondition]
  public let cryptoCurrency: String
  public let network: String
  public let destinationAddress: String

  public init(
    amountConditions: [NoahAmountCondition],
    cryptoCurrency: String,
    network: String,
    destinationAddress: String
  ) {
    self.amountConditions = amountConditions
    self.cryptoCurrency = cryptoCurrency
    self.network = network
    self.destinationAddress = destinationAddress
  }
}

/// Per-condition entry used inside `NoahSingleOnchainDepositSourceTriggerInput`.
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahSingleOnchainDepositSourceTriggerCondition: Codable {
  public let amountConditions: [NoahSingleOnchainDepositSourceTriggerAmountCondition]
  public let network: String

  public init(
    amountConditions: [NoahSingleOnchainDepositSourceTriggerAmountCondition],
    network: String
  ) {
    self.amountConditions = amountConditions
    self.network = network
  }

  enum CodingKeys: String, CodingKey {
    case amountConditions = "AmountConditions"
    case network = "Network"
  }
}

/// Amount condition entry used inside `NoahSingleOnchainDepositSourceTriggerInput`.
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahSingleOnchainDepositSourceTriggerAmountCondition: Codable {
  public let comparisonOperator: String
  public let value: String

  public init(comparisonOperator: String, value: String) {
    self.comparisonOperator = comparisonOperator
    self.value = value
  }

  public init(comparisonOperator: NoahComparisonOperator, value: String) {
    self.comparisonOperator = comparisonOperator.rawValue
    self.value = value
  }

  enum CodingKeys: String, CodingKey {
    case comparisonOperator = "ComparisonOperator"
    case value = "Value"
  }
}

/// Signed payout trigger describing a single on-chain deposit source.
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahSingleOnchainDepositSourceTriggerInput: Codable {
  public let type: String
  public let conditions: [NoahSingleOnchainDepositSourceTriggerCondition]
  public let sourceAddress: String
  public let expiry: String
  public let nonce: String

  public init(
    type: String = "SingleOnchainDepositSourceTriggerInput",
    conditions: [NoahSingleOnchainDepositSourceTriggerCondition],
    sourceAddress: String,
    expiry: String,
    nonce: String
  ) {
    self.type = type
    self.conditions = conditions
    self.sourceAddress = sourceAddress
    self.expiry = expiry
    self.nonce = nonce
  }

  enum CodingKeys: String, CodingKey {
    case type = "Type"
    case conditions = "Conditions"
    case sourceAddress = "SourceAddress"
    case expiry = "Expiry"
    case nonce = "Nonce"
  }
}

/// Per-condition entry used inside permanent/quoted triggers. Unlike the single
/// trigger, these conditions only constrain the network (no amount conditions).
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahNetworkOnlyOnchainDepositSourceTriggerCondition: Codable {
  public let network: String

  public init(network: String) {
    self.network = network
  }

  enum CodingKeys: String, CodingKey {
    case network = "Network"
  }
}

/// Trigger that keeps a payout source active across multiple deposits (until
/// expiry), rather than for a single matching amount.
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahPermanentOnchainDepositSourceTriggerInput: Codable {
  public let type: String
  public let conditions: [NoahNetworkOnlyOnchainDepositSourceTriggerCondition]
  public let sourceAddress: String
  public let expiry: String
  public let nonce: String
  /// When `true`, the trigger matches deposits on any supported network.
  public let networkAgnostic: Bool?

  public init(
    type: String = "PermanentOnchainDepositSourceTriggerInput",
    conditions: [NoahNetworkOnlyOnchainDepositSourceTriggerCondition],
    sourceAddress: String,
    expiry: String,
    nonce: String,
    networkAgnostic: Bool? = nil
  ) {
    self.type = type
    self.conditions = conditions
    self.sourceAddress = sourceAddress
    self.expiry = expiry
    self.nonce = nonce
    self.networkAgnostic = networkAgnostic
  }

  enum CodingKeys: String, CodingKey {
    case type = "Type"
    case conditions = "Conditions"
    case sourceAddress = "SourceAddress"
    case expiry = "Expiry"
    case nonce = "Nonce"
    case networkAgnostic = "NetworkAgnostic"
  }
}

/// Trigger backed by a signed quote (rate-locked payout). Requires the
/// `SignedQuote` obtained from a `getPayoutQuote` call made with `quoted: true`.
/// JSON keys use PascalCase to match the Noah API wire format.
public struct NoahQuotedOnchainDepositSourceTriggerInput: Codable {
  public let type: String
  public let signedQuote: String
  public let conditions: [NoahNetworkOnlyOnchainDepositSourceTriggerCondition]
  public let sourceAddress: String
  public let nonce: String
  public let expiry: String?

  public init(
    type: String = "QuotedOnchainDepositSourceTriggerInput",
    signedQuote: String,
    conditions: [NoahNetworkOnlyOnchainDepositSourceTriggerCondition],
    sourceAddress: String,
    nonce: String,
    expiry: String? = nil
  ) {
    self.type = type
    self.signedQuote = signedQuote
    self.conditions = conditions
    self.sourceAddress = sourceAddress
    self.nonce = nonce
    self.expiry = expiry
  }

  enum CodingKeys: String, CodingKey {
    case type = "Type"
    case signedQuote = "SignedQuote"
    case conditions = "Conditions"
    case sourceAddress = "SourceAddress"
    case nonce = "Nonce"
    case expiry = "Expiry"
  }
}

/// The three Noah on-chain deposit source trigger variants accepted by
/// `POST /payouts`. The wire shape is discriminated by the `Type` field, so this
/// enum encodes the wrapped value transparently (no extra nesting).
public enum NoahOnchainDepositSourceTrigger: Codable {
  case single(NoahSingleOnchainDepositSourceTriggerInput)
  case permanent(NoahPermanentOnchainDepositSourceTriggerInput)
  case quoted(NoahQuotedOnchainDepositSourceTriggerInput)

  private enum TypeKey: String, CodingKey {
    case type = "Type"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .single(value):
      try container.encode(value)
    case let .permanent(value):
      try container.encode(value)
    case let .quoted(value):
      try container.encode(value)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TypeKey.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "SingleOnchainDepositSourceTriggerInput":
      self = .single(try NoahSingleOnchainDepositSourceTriggerInput(from: decoder))
    case "PermanentOnchainDepositSourceTriggerInput":
      self = .permanent(try NoahPermanentOnchainDepositSourceTriggerInput(from: decoder))
    case "QuotedOnchainDepositSourceTriggerInput":
      self = .quoted(try NoahQuotedOnchainDepositSourceTriggerInput(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: TypeKey.type,
        in: container,
        debugDescription: "Unknown Noah trigger Type: \(type)"
      )
    }
  }
}

// MARK: - Business fee

/// Optional business (partner) fee applied to a Noah payout or payin.
///
/// JSON keys use PascalCase to match the Noah API wire format. The BFF forwards
/// this object straight through to Noah, so the inner field names must stay
/// PascalCase even though the surrounding request keys are camelCase.
public struct NoahBusinessFee: Codable {
  public let feeBase: String?
  public let feePct: String?
  public let fiatCurrency: String?

  public init(
    feeBase: String? = nil,
    feePct: String? = nil,
    fiatCurrency: String? = nil
  ) {
    self.feeBase = feeBase
    self.feePct = feePct
    self.fiatCurrency = fiatCurrency
  }

  enum CodingKeys: String, CodingKey {
    case feeBase = "FeeBase"
    case feePct = "FeePct"
    case fiatCurrency = "FiatCurrency"
  }
}

// MARK: - Response envelope metadata

/// Response envelope metadata returned by connect-api alongside `data`.
///
/// The BFF sends a freeform object here, so we expose it as `[String: AnyCodable]`.
public typealias NoahResponseMetadata = [String: AnyCodable]

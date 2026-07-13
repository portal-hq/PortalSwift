//
//  Noah.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol defining the Noah on/off-ramp provider surface.
public protocol NoahProtocol {
  /// Start a Noah KYC session for the current customer.
  /// - Parameter request: KYC request payload (return URL, fiat options, etc.).
  /// - Returns: `NoahInitiateKycResponse` containing the hosted KYC URL.
  /// - Throws: An error if the operation fails.
  func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse

  /// Initiate a Noah payin (on-ramp) and receive bank deposit instructions.
  /// - Parameter request: Payin request payload.
  /// - Returns: `NoahInitiatePayinResponse` containing the payin id and bank details.
  /// - Throws: An error if the operation fails.
  func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse

  /// Simulate a Noah payin (sandbox-only fiat deposit).
  /// - Parameter request: Simulate payin request payload.
  /// - Returns: `NoahSimulatePayinResponse` containing the simulated fiat deposit id.
  /// - Throws: An error if the operation fails.
  func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse

  /// List stored Noah payment methods for the current customer.
  /// - Parameter request: Pagination / capability filter. Use the no-argument
  ///   overload to call with default request values.
  /// - Returns: `NoahGetPaymentMethodsResponse` with the stored payment methods.
  /// - Throws: An error if the operation fails.
  func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse

  /// List the countries and fiat currencies supported for Noah payouts.
  /// - Returns: `NoahGetPayoutCountriesResponse` keyed by country code.
  /// - Throws: An error if the operation fails.
  func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse

  /// List Noah payout channels matching the supplied filters.
  /// - Parameter request: Payout channels filter request.
  /// - Returns: `NoahGetPayoutChannelsResponse` containing matching channels.
  /// - Throws: An error if the operation fails.
  func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse

  /// Fetch the dynamic form schema for the given Noah payout channel.
  /// - Parameter channelId: The Noah channel identifier (will be percent-encoded).
  /// - Returns: `NoahGetPayoutChannelFormResponse` containing the form schema and metadata.
  /// - Throws: An error if the operation fails.
  func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse

  /// Request a Noah payout quote for the given channel and form responses.
  /// - Parameter request: Payout quote request payload.
  /// - Returns: `NoahGetPayoutQuoteResponse` containing the quote and any next step.
  /// - Throws: An error if the operation fails.
  func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse

  /// Initiate a Noah payout from a previously quoted payout.
  /// - Parameter request: Initiate payout request payload (includes trigger conditions).
  /// - Returns: `NoahInitiatePayoutResponse` containing the destination address and conditions.
  /// - Throws: An error if the operation fails.
  func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse
}

public extension NoahProtocol {
  /// Convenience overload for `getPaymentMethods` using default request values.
  func getPaymentMethods() async throws -> NoahGetPaymentMethodsResponse {
    try await getPaymentMethods(request: NoahGetPaymentMethodsRequest())
  }
}

/// Noah on/off-ramp provider implementation.
///
/// Thin domain wrapper that forwards calls to a `PortalNoahApiProtocol`.
public class Noah: NoahProtocol {
  private let api: PortalNoahApiProtocol

  /// Create an instance of `Noah`.
  /// - Parameter api: The `PortalNoahApi` instance to use for Noah operations.
  public init(api: PortalNoahApiProtocol) {
    self.api = api
  }

  public func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    return try await api.initiateKyc(request: request)
  }

  public func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse {
    return try await api.initiatePayin(request: request)
  }

  public func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse {
    return try await api.simulatePayin(request: request)
  }

  public func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    return try await api.getPaymentMethods(request: request)
  }

  public func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse {
    return try await api.getPayoutCountries()
  }

  public func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    return try await api.getPayoutChannels(request: request)
  }

  public func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse {
    return try await api.getPayoutChannelForm(channelId: channelId)
  }

  public func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse {
    return try await api.getPayoutQuote(request: request)
  }

  public func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse {
    return try await api.initiatePayout(request: request)
  }
}

//
//  Blockaid.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//
//  Stub factory methods for Blockaid request/response models.
//

import Foundation
@testable import PortalSwift

// MARK: - Request Stubs

extension BlockaidScanEVMRequest {
  static func stub(
    chain: String = "eip155:1",
    metadata: BlockaidScanEVMMetadata = .stub(),
    data: BlockaidScanEVMTransactionData = .stub(),
    options: [BlockaidScanEVMOption]? = [.simulation, .validation],
    block: String? = "21211118"
  ) -> Self {
    BlockaidScanEVMRequest(chain: chain, metadata: metadata, data: data, options: options, block: block)
  }
}

extension BlockaidScanEVMTransactionData {
  static func stub(
    from: String = "0x5e1a0d484c5f0de722e82f9dca3a9d5a421d47cb",
    to: String? = "0x0d524a5b52737c0a02880d5e84f7d20b8d66bfba",
    data: String? = "0x",
    value: String? = "0x1000000000000000",
    gas: String? = nil,
    gasPrice: String? = nil
  ) -> Self {
    BlockaidScanEVMTransactionData(from: from, to: to, data: data, value: value, gas: gas, gasPrice: gasPrice)
  }
}

extension BlockaidScanEVMMetadata {
  static func stub(domain: String? = "https://example.com") -> Self {
    BlockaidScanEVMMetadata(domain: domain)
  }
}

extension BlockaidScanSolanaRequest {
  static func stub(
    accountAddress: String = "86xCnPeV69n6t3DnyGvkKobf9FdN2H9oiVDdaMpo2MMY",
    transactions: [String] = ["base58encodedtx"],
    metadata: BlockaidScanSolanaMetadata? = .stub(),
    encoding: BlockaidScanSolanaEncoding? = .base58,
    chain: String = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
    options: [BlockaidScanSolanaOption]? = [.simulation, .validation],
    method: String? = "signAndSendTransaction"
  ) -> Self {
    BlockaidScanSolanaRequest(
      accountAddress: accountAddress,
      transactions: transactions,
      metadata: metadata,
      encoding: encoding,
      chain: chain,
      options: options,
      method: method
    )
  }
}

extension BlockaidScanSolanaMetadata {
  static func stub(url: String? = "https://example.com") -> Self {
    BlockaidScanSolanaMetadata(url: url)
  }
}

extension BlockaidScanAddressRequest {
  static func stub(
    address: String = "0x946D45c866AFD5b8F436d40E551D8E50A5B84230",
    chain: String = "eip155:1",
    metadata: BlockaidScanAddressMetadata? = nil
  ) -> Self {
    BlockaidScanAddressRequest(address: address, chain: chain, metadata: metadata)
  }
}

extension BlockaidScanAddressMetadata {
  static func stub(domain: String? = "https://example.com") -> Self {
    BlockaidScanAddressMetadata(domain: domain)
  }
}

extension BlockaidScanTokensRequest {
  static func stub(
    chain: String = "eip155:1",
    tokens: [String] = ["0xtoken1"],
    metadata: BlockaidTokenMetadata? = nil
  ) -> Self {
    BlockaidScanTokensRequest(chain: chain, tokens: tokens, metadata: metadata)
  }
}

extension BlockaidScanURLRequest {
  static func stub(
    url: String = "https://app.uniswap.org",
    metadata: BlockaidScanURLMetadata? = nil
  ) -> Self {
    BlockaidScanURLRequest(url: url, metadata: metadata)
  }
}

extension BlockaidScanURLMetadata {
  static func stub(type: BlockaidScanURLMetadataType? = .catalog) -> Self {
    BlockaidScanURLMetadata(type: type)
  }
}

// MARK: - EVM Response Stubs

extension BlockaidScanEVMResponse {
  static func stub(data: BlockaidScanEVMData? = .stub(), error: String? = nil) -> Self {
    BlockaidScanEVMResponse(data: data, error: error)
  }
}

extension BlockaidScanEVMData {
  static func stub(rawResponse: BlockaidScanEVMRawResponse = .stub()) -> Self {
    BlockaidScanEVMData(rawResponse: rawResponse)
  }
}

extension BlockaidScanEVMRawResponse {
  static func stub(
    validation: BlockaidValidationResult? = .stub(),
    simulation: BlockaidSimulationResult? = nil,
    block: String = "21211118",
    chain: String = "eip155:1",
    accountAddress: String? = nil
  ) -> Self {
    BlockaidScanEVMRawResponse(
      validation: validation,
      simulation: simulation,
      block: block,
      chain: chain,
      accountAddress: accountAddress
    )
  }
}

extension BlockaidValidationResult {
  static func stub(
    status: String = "Success",
    resultType: String = "Benign",
    classification: String? = nil,
    reason: String? = nil,
    description: String? = nil,
    features: [BlockaidValidationFeature]? = nil
  ) -> Self {
    BlockaidValidationResult(
      status: status,
      resultType: resultType,
      classification: classification,
      reason: reason,
      description: description,
      features: features
    )
  }
}

extension BlockaidSimulationResult {
  static func stub(
    status: String = "Success",
    assetsDiffs: [String: [BlockaidAssetDiffResult]]? = nil,
    transactionActions: [String]? = nil,
    params: BlockaidSimulationParams? = nil,
    totalUsdDiff: [String: BlockaidTotalUsdDiff]? = nil,
    exposures: [String: [[String: String]]]? = nil,
    totalUsdExposure: [String: String]? = nil,
    addressDetails: [String: BlockaidAddressDetails]? = nil,
    accountSummary: BlockaidAccountSummary? = nil
  ) -> Self {
    BlockaidSimulationResult(
      status: status,
      assetsDiffs: assetsDiffs,
      transactionActions: transactionActions,
      params: params,
      totalUsdDiff: totalUsdDiff,
      exposures: exposures,
      totalUsdExposure: totalUsdExposure,
      addressDetails: addressDetails,
      accountSummary: accountSummary
    )
  }
}

extension BlockaidAssetDiffResult {
  static func stub(
    assetType: String = "native",
    asset: BlockaidAsset = .stub(),
    in: [BlockaidAssetDiffMovement]? = nil,
    out: [BlockaidAssetDiffMovement]? = nil,
    balanceChanges: BlockaidBalanceChanges? = nil
  ) -> Self {
    BlockaidAssetDiffResult(assetType: assetType, asset: asset, in: `in`, out: out, balanceChanges: balanceChanges)
  }
}

extension BlockaidAsset {
  static func stub(
    type: String = "native",
    chainName: String? = nil,
    decimals: Int? = 18,
    chainId: Int? = 1,
    logoUrl: String? = nil,
    name: String? = "Ether",
    symbol: String? = "ETH",
    address: String? = nil
  ) -> Self {
    BlockaidAsset(
      type: type,
      chainName: chainName,
      decimals: decimals,
      chainId: chainId,
      logoUrl: logoUrl,
      name: name,
      symbol: symbol,
      address: address
    )
  }
}

// MARK: - Solana Response Stubs

extension BlockaidScanSolanaResponse {
  static func stub(data: BlockaidScanSolanaData? = .stub(), error: String? = nil) -> Self {
    BlockaidScanSolanaResponse(data: data, error: error)
  }
}

extension BlockaidScanSolanaData {
  static func stub(rawResponse: BlockaidScanSolanaRawResponse = .stub()) -> Self {
    BlockaidScanSolanaData(rawResponse: rawResponse)
  }
}

extension BlockaidScanSolanaRawResponse {
  static func stub(
    encoding: String? = "base58",
    status: String? = "SUCCESS",
    result: BlockaidSolanaResult? = .stub(),
    error: String? = nil,
    errorDetails: [String: String]? = nil,
    requestId: String? = nil
  ) -> Self {
    BlockaidScanSolanaRawResponse(
      encoding: encoding,
      status: status,
      result: result,
      error: error,
      errorDetails: errorDetails,
      requestId: requestId
    )
  }
}

extension BlockaidSolanaResult {
  static func stub(
    simulation: BlockaidSolanaSimulation? = nil,
    validation: BlockaidSolanaValidation? = .stub()
  ) -> Self {
    BlockaidSolanaResult(simulation: simulation, validation: validation)
  }
}

extension BlockaidSolanaValidation {
  static func stub(
    resultType: String = "Benign",
    reason: String? = nil,
    features: [String]? = nil,
    extendedFeatures: [BlockaidSolanaExtendedFeature]? = nil
  ) -> Self {
    BlockaidSolanaValidation(
      resultType: resultType,
      reason: reason,
      features: features,
      extendedFeatures: extendedFeatures
    )
  }
}

// MARK: - Address Response Stubs

extension BlockaidScanAddressResponse {
  static func stub(data: BlockaidScanAddressData? = .stub(), error: String? = nil) -> Self {
    BlockaidScanAddressResponse(data: data, error: error)
  }
}

extension BlockaidScanAddressData {
  static func stub(rawResponse: BlockaidScanAddressRawResponse = .stub()) -> Self {
    BlockaidScanAddressData(rawResponse: rawResponse)
  }
}

extension BlockaidScanAddressRawResponse {
  static func stub(
    resultType: String = "Benign",
    features: [BlockaidAddressFeature]? = nil,
    error: String? = nil
  ) -> Self {
    BlockaidScanAddressRawResponse(resultType: resultType, features: features, error: error)
  }
}

extension BlockaidAddressFeature {
  static func stub(
    type: String = "Benign",
    featureId: String = "KNOWN_SAFE",
    description: String = "Known safe"
  ) -> Self {
    BlockaidAddressFeature(type: type, featureId: featureId, description: description)
  }
}

// MARK: - Tokens Response Stubs

extension BlockaidScanTokensResponse {
  static func stub(data: BlockaidScanTokensData? = .stub(), error: String? = nil) -> Self {
    BlockaidScanTokensResponse(data: data, error: error)
  }
}

extension BlockaidScanTokensData {
  static func stub(rawResponse: BlockaidScanTokensRawResponse = .stub()) -> Self {
    BlockaidScanTokensData(rawResponse: rawResponse)
  }
}

extension BlockaidScanTokensRawResponse {
  static func stub(results: [String: BlockaidTokenResult] = ["0xtoken1": .stub()]) -> Self {
    BlockaidScanTokensRawResponse(results: results)
  }
}

extension BlockaidTokenResult {
  static func stub(
    resultType: String = "Benign",
    maliciousScore: String? = nil,
    attackTypes: [String: BlockaidAttackType]? = nil,
    chain: String = "eip155:1",
    address: String = "0xtoken1",
    metadata: BlockaidTokenMetadataResult? = nil,
    fees: BlockaidTokenFees? = nil,
    features: [BlockaidTokenFeature]? = nil,
    tradingLimits: BlockaidTradingLimits? = nil,
    financialStats: BlockaidFinancialStats? = nil
  ) -> Self {
    BlockaidTokenResult(
      resultType: resultType,
      maliciousScore: maliciousScore,
      attackTypes: attackTypes,
      chain: chain,
      address: address,
      metadata: metadata,
      fees: fees,
      features: features,
      tradingLimits: tradingLimits,
      financialStats: financialStats
    )
  }
}

// MARK: - URL Response Stubs

extension BlockaidScanURLResponse {
  static func stub(data: BlockaidScanURLData? = .stub(), error: String? = nil) -> Self {
    BlockaidScanURLResponse(data: data, error: error)
  }
}

extension BlockaidScanURLData {
  static func stub(rawResponse: BlockaidScanURLRawResponse = .stub()) -> Self {
    BlockaidScanURLData(rawResponse: rawResponse)
  }
}

extension BlockaidScanURLRawResponse {
  static func stub(
    status: String = "hit",
    url: String? = "https://app.uniswap.org",
    scanStartTime: String? = nil,
    scanEndTime: String? = nil,
    maliciousScore: Int? = nil,
    isReachable: Bool? = nil,
    isWeb3Site: Bool? = nil,
    isMalicious: Bool? = nil,
    attackTypes: [String: BlockaidAttackEntry]? = nil,
    networkOperations: [String]? = nil,
    jsonRpcOperations: [String]? = nil,
    contractWrite: BlockaidContractOperations? = nil,
    contractRead: BlockaidContractOperations? = nil,
    modals: [String]? = nil
  ) -> Self {
    BlockaidScanURLRawResponse(
      status: status,
      url: url,
      scanStartTime: scanStartTime,
      scanEndTime: scanEndTime,
      maliciousScore: maliciousScore,
      isReachable: isReachable,
      isWeb3Site: isWeb3Site,
      isMalicious: isMalicious,
      attackTypes: attackTypes,
      networkOperations: networkOperations,
      jsonRpcOperations: jsonRpcOperations,
      contractWrite: contractWrite,
      contractRead: contractRead,
      modals: modals
    )
  }
}

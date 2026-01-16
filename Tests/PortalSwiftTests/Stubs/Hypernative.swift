//
//  Hypernative.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

// MARK: - Request Stubs

extension ScanEVMRequest {
  static func stub(
    transaction: HypernativeTransactionObject = .stub(),
    url: String? = nil,
    blockNumber: Int? = nil,
    validateNonce: Bool? = nil,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) -> Self {
    ScanEVMRequest(
      transaction: transaction,
      url: url,
      blockNumber: blockNumber,
      validateNonce: validateNonce,
      showFullFindings: showFullFindings,
      policy: policy
    )
  }
}

extension HypernativeTransactionObject {
  static func stub(
    chain: String = "eip155:1",
    fromAddress: String = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    toAddress: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    input: String? = "0x095ea7b3",
    value: Int? = 0,
    nonce: Int? = 2340,
    hash: String? = nil,
    gas: Int? = 3000000,
    gasPrice: Int? = 3000000,
    maxPriorityFeePerGas: Int? = nil,
    maxFeePerGas: Int? = nil
  ) -> Self {
    HypernativeTransactionObject(
      chain: chain,
      fromAddress: fromAddress,
      toAddress: toAddress,
      input: input,
      value: value,
      nonce: nonce,
      hash: hash,
      gas: gas,
      gasPrice: gasPrice,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas
    )
  }
}

extension ScanEip712Request {
  static func stub(
    walletAddress: String = "0x12345",
    chainId: String = "eip155:1",
    eip712Message: Eip712TypedData = .stub(),
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) -> Self {
    ScanEip712Request(
      walletAddress: walletAddress,
      chainId: chainId,
      eip712Message: eip712Message,
      showFullFindings: showFullFindings,
      policy: policy
    )
  }
}

extension Eip712TypedData {
  static func stub(
    primaryType: String = "Permit",
    types: [String: [Eip712TypeProperty]] = [
      "Permit": [
        Eip712TypeProperty(name: "owner", type: "address"),
        Eip712TypeProperty(name: "spender", type: "address")
      ]
    ],
    domain: Eip712Domain = .stub(),
    message: Eip712Message = .stub()
  ) -> Self {
    Eip712TypedData(
      primaryType: primaryType,
      types: types,
      domain: domain,
      message: message
    )
  }
}

extension Eip712Domain {
  static func stub(
    name: String? = "MyToken",
    version: String? = "1",
    chainId: String? = "eip155:1",
    verifyingContract: String? = "0xa0b86991c6218b36c1d19d4a2e9Eb0cE3606eB48",
    salt: String? = nil
  ) -> Self {
    Eip712Domain(
      name: name,
      version: version,
      chainId: chainId,
      verifyingContract: verifyingContract,
      salt: salt
    )
  }
}

extension Eip712Message {
  static func stub(
    owner: String = "0x7b1363f33b86d16ef7c8d03d11f4394a37d95c36",
    spender: String = "0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186",
    value: Int = 3000,
    nonce: Int = 0,
    deadline: Int64 = 50000000000
  ) -> Self {
    Eip712Message(
      owner: owner,
      spender: spender,
      value: value,
      nonce: nonce,
      deadline: deadline
    )
  }
}

extension ScanSolanaRequest {
  static func stub(
    transaction: SolanaTransaction = .stub(),
    url: String? = nil,
    validateRecentBlockHash: Bool? = nil,
    showFullFindings: Bool? = true,
    policy: String? = nil
  ) -> Self {
    ScanSolanaRequest(
      transaction: transaction,
      url: url,
      validateRecentBlockHash: validateRecentBlockHash,
      showFullFindings: showFullFindings,
      policy: policy
    )
  }
}

extension SolanaTransaction {
  static func stub(
    message: SolanaMessage? = nil,
    signatures: [String]? = nil,
    rawTransaction: String? = "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAQADCQkVR3SiiKbW0l4c3NBsEn6",
    version: String? = "0"
  ) -> Self {
    SolanaTransaction(
      message: message,
      signatures: signatures,
      rawTransaction: rawTransaction,
      version: version
    )
  }
}

extension ScanAddressesRequest {
  static func stub(
    addresses: [String] = ["0x123", "0x456"],
    screenerPolicyId: String? = nil
  ) -> Self {
    ScanAddressesRequest(
      addresses: addresses,
      screenerPolicyId: screenerPolicyId
    )
  }
}

extension ScanNftsRequest {
  static func stub(
    nfts: [ScanNftsRequestItem] = [.stub()]
  ) -> Self {
    ScanNftsRequest(nfts: nfts)
  }
}

extension ScanNftsRequestItem {
  static func stub(
    address: String = "0x5C1B9caA8492585182eD994633e76d744A876548",
    chain: String? = nil,
    evmChainId: String? = "eip155:1"
  ) -> Self {
    ScanNftsRequestItem(
      address: address,
      chain: chain,
      evmChainId: evmChainId
    )
  }
}

extension ScanTokensRequest {
  static func stub(
    tokens: [ScanTokensRequestItem] = [.stub()]
  ) -> Self {
    ScanTokensRequest(tokens: tokens)
  }
}

extension ScanTokensRequestItem {
  static func stub(
    address: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    chain: String? = nil,
    evmChainId: String? = "eip155:1"
  ) -> Self {
    ScanTokensRequestItem(
      address: address,
      chain: chain,
      evmChainId: evmChainId
    )
  }
}

extension ScanUrlRequest {
  static func stub(
    url: String = "https://example.com"
  ) -> Self {
    ScanUrlRequest(url: url)
  }
}

// MARK: - Response Stubs

extension TransactionRiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = "2024-01-01T00:00:00Z",
    recommendation: HypernativeRecommendation = .accept,
    expectedStatus: HypernativeExpectedStatus? = .success,
    findings: [HypernativeFinding]? = nil,
    involvedAssets: [HypernativeAsset]? = nil,
    balanceChanges: [String: [HypernativeBalanceChange]]? = nil,
    parsedActions: HypernativeParsedActions? = nil,
    blockNumber: Int? = nil,
    trace: [HypernativeTrace]? = nil,
    riIds: [String]? = nil,
    signature: String? = nil
  ) -> Self {
    TransactionRiskData(
      assessmentId: assessmentId,
      assessmentTimestamp: assessmentTimestamp,
      recommendation: recommendation,
      expectedStatus: expectedStatus,
      findings: findings,
      involvedAssets: involvedAssets,
      balanceChanges: balanceChanges,
      parsedActions: parsedActions,
      blockNumber: blockNumber,
      trace: trace,
      riIds: riIds,
      signature: signature
    )
  }
}

extension ScanEVMRawResponse {
  static func stub(
    success: Bool = true,
    data: TransactionRiskData? = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanEVMRawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanEVMData {
  static func stub(
    rawResponse: ScanEVMRawResponse = .stub()
  ) -> Self {
    ScanEVMData(rawResponse: rawResponse)
  }
}

extension ScanEVMResponse {
  static func stub(
    data: ScanEVMData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanEVMResponse(data: data, error: error)
  }
}

extension TypedMessageRiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = nil,
    blockNumber: Int? = nil,
    recommendation: HypernativeRecommendation = .accept,
    findings: [HypernativeFinding]? = nil,
    involvedAssets: [HypernativeAsset]? = nil,
    parsedActions: HypernativeParsedActions? = nil,
    trace: [HypernativeTrace]? = nil,
    riIds: [String]? = nil
  ) -> Self {
    TypedMessageRiskData(
      assessmentId: assessmentId,
      assessmentTimestamp: assessmentTimestamp,
      blockNumber: blockNumber,
      recommendation: recommendation,
      findings: findings,
      involvedAssets: involvedAssets,
      parsedActions: parsedActions,
      trace: trace,
      riIds: riIds
    )
  }
}

extension ScanEip712RawResponse {
  static func stub(
    success: Bool = true,
    data: TypedMessageRiskData? = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanEip712RawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanEip712Data {
  static func stub(
    rawResponse: ScanEip712RawResponse = .stub()
  ) -> Self {
    ScanEip712Data(rawResponse: rawResponse)
  }
}

extension ScanEip712Response {
  static func stub(
    data: ScanEip712Data? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanEip712Response(data: data, error: error)
  }
}

extension SolanaTransactionRiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = "2024-01-01T00:00:00Z",
    recommendation: HypernativeRecommendation = .accept,
    expectedStatus: HypernativeExpectedStatus? = nil,
    findings: [HypernativeFinding]? = nil,
    involvedAssets: [HypernativeAsset]? = nil,
    balanceChanges: [String: [HypernativeBalanceChange]]? = nil,
    parsedActions: HypernativeParsedActions? = nil,
    blockNumber: Int? = nil,
    trace: [HypernativeTrace]? = nil,
    riIds: [String]? = nil
  ) -> Self {
    SolanaTransactionRiskData(
      assessmentId: assessmentId,
      assessmentTimestamp: assessmentTimestamp,
      recommendation: recommendation,
      expectedStatus: expectedStatus,
      findings: findings,
      involvedAssets: involvedAssets,
      balanceChanges: balanceChanges,
      parsedActions: parsedActions,
      blockNumber: blockNumber,
      trace: trace,
      riIds: riIds
    )
  }
}

extension ScanSolanaRawResponse {
  static func stub(
    success: Bool = true,
    data: SolanaTransactionRiskData? = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanSolanaRawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanSolanaData {
  static func stub(
    rawResponse: ScanSolanaRawResponse = .stub()
  ) -> Self {
    ScanSolanaData(rawResponse: rawResponse)
  }
}

extension ScanSolanaResponse {
  static func stub(
    data: ScanSolanaData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanSolanaResponse(data: data, error: error)
  }
}

extension ScanAddressesResponseItem {
  static func stub(
    address: String = "0x123",
    recommendation: String = "accept",
    severity: String = "low",
    totalIncomingUsd: Double = 0.0,
    policyId: String = "test-policy-id",
    timestamp: String = "2024-01-01T00:00:00Z",
    flags: [HypernativeFlag] = []
  ) -> Self {
    ScanAddressesResponseItem(
      address: address,
      recommendation: recommendation,
      severity: severity,
      totalIncomingUsd: totalIncomingUsd,
      policyId: policyId,
      timestamp: timestamp,
      flags: flags
    )
  }
}

extension ScanAddressesData {
  static func stub(
    rawResponse: [ScanAddressesResponseItem] = []
  ) -> Self {
    ScanAddressesData(rawResponse: rawResponse)
  }
}

extension ScanAddressesResponse {
  static func stub(
    data: ScanAddressesData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanAddressesResponse(data: data, error: error)
  }
}

extension ScanNftsResponseItem {
  static func stub(
    address: String = "0x5C1B9caA8492585182eD994633e76d744A876548",
    chain: String = "ethereum",
    evmChainId: String = "eip155:1",
    accept: Bool = true
  ) -> Self {
    ScanNftsResponseItem(
      address: address,
      chain: chain,
      evmChainId: evmChainId,
      accept: accept
    )
  }
}

extension ScanNftsDataContent {
  static func stub(
    nfts: [ScanNftsResponseItem] = [.stub()]
  ) -> Self {
    ScanNftsDataContent(nfts: nfts)
  }
}

extension ScanNftsRawResponse {
  static func stub(
    success: Bool = true,
    data: ScanNftsDataContent = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanNftsRawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanNftsData {
  static func stub(
    rawResponse: ScanNftsRawResponse = .stub()
  ) -> Self {
    ScanNftsData(rawResponse: rawResponse)
  }
}

extension ScanNftsResponse {
  static func stub(
    data: ScanNftsData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanNftsResponse(data: data, error: error)
  }
}

extension TokenReputation {
  static func stub(
    recommendation: String = "accept"
  ) -> Self {
    TokenReputation(recommendation: recommendation)
  }
}

extension ScanTokensResponseItem {
  static func stub(
    address: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    chain: String = "ethereum",
    reputation: TokenReputation = .stub()
  ) -> Self {
    ScanTokensResponseItem(
      address: address,
      chain: chain,
      reputation: reputation
    )
  }
}

extension ScanTokensDataContent {
  static func stub(
    tokens: [ScanTokensResponseItem] = [.stub()]
  ) -> Self {
    ScanTokensDataContent(tokens: tokens)
  }
}

extension ScanTokensRawResponse {
  static func stub(
    success: Bool = true,
    data: ScanTokensDataContent = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanTokensRawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanTokensData {
  static func stub(
    rawResponse: ScanTokensRawResponse = .stub()
  ) -> Self {
    ScanTokensData(rawResponse: rawResponse)
  }
}

extension ScanTokensResponse {
  static func stub(
    data: ScanTokensData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanTokensResponse(data: data, error: error)
  }
}

extension ScanUrlDataContent {
  static func stub(
    isMalicious: Bool = false,
    deepScanTriggered: Bool? = nil
  ) -> Self {
    ScanUrlDataContent(
      isMalicious: isMalicious,
      deepScanTriggered: deepScanTriggered
    )
  }
}

extension ScanUrlRawResponse {
  static func stub(
    success: Bool = true,
    data: ScanUrlDataContent = .stub(),
    error: String? = nil,
    version: String? = "1.0",
    service: String? = "hypernative"
  ) -> Self {
    ScanUrlRawResponse(
      success: success,
      data: data,
      error: error,
      version: version,
      service: service
    )
  }
}

extension ScanUrlData {
  static func stub(
    rawResponse: ScanUrlRawResponse = .stub()
  ) -> Self {
    ScanUrlData(rawResponse: rawResponse)
  }
}

extension ScanUrlResponse {
  static func stub(
    data: ScanUrlData? = .stub(),
    error: String? = nil
  ) -> Self {
    ScanUrlResponse(data: data, error: error)
  }
}

// MARK: - Risk Data Detail Stubs

extension HypernativeFinding {
  static func stub(
    typeId: String = "test-type-id",
    title: String = "Test Finding",
    description: String = "Test finding description",
    details: String? = nil,
    severity: HypernativeSeverity = .Accept,
    relatedAssets: [HypernativeAsset]? = nil
  ) -> Self {
    HypernativeFinding(
      typeId: typeId,
      title: title,
      description: description,
      details: details,
      severity: severity,
      relatedAssets: relatedAssets
    )
  }
}

extension HypernativeAsset {
  static func stub(
    chain: String = "ethereum",
    evmChainId: String? = "eip155:1",
    address: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    type: HypernativeAssetType = .Contract,
    involvementTypes: [String] = ["transfer"],
    tag: String = "USDC",
    alias: String? = nil,
    note: String? = nil
  ) -> Self {
    HypernativeAsset(
      chain: chain,
      evmChainId: evmChainId,
      address: address,
      type: type,
      involvementTypes: involvementTypes,
      tag: tag,
      alias: alias,
      note: note
    )
  }
}

extension HypernativeBalanceChange {
  static func stub(
    changeType: HypernativeChangeType = .send,
    tokenSymbol: String = "USDC",
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    usdValue: String? = "100.00",
    amount: String = "100000000",
    chain: String = "ethereum",
    evmChainId: String? = "eip155:1"
  ) -> Self {
    HypernativeBalanceChange(
      changeType: changeType,
      tokenSymbol: tokenSymbol,
      tokenAddress: tokenAddress,
      usdValue: usdValue,
      amount: amount,
      chain: chain,
      evmChainId: evmChainId
    )
  }
}

extension HypernativeParsedActions {
  static func stub(
    ethValues: [HypernativeParsedActionItem]? = nil,
    tokenValues: [HypernativeParsedActionItem]? = nil,
    nftValues: [HypernativeParsedActionItem]? = nil,
    approval: [HypernativeParsedApprovalItem]? = nil,
    approve: [HypernativeParsedApproveItem]? = nil
  ) -> Self {
    HypernativeParsedActions(
      ethValues: ethValues,
      tokenValues: tokenValues,
      nftValues: nftValues,
      approval: approval,
      approve: approve
    )
  }
}

extension HypernativeParsedActionItem {
  static func stub(
    amountInUsd: Double? = 100.0,
    amount: Double? = 1.0,
    from: String? = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    decimals: Int? = 6,
    decimalValue: Int? = nil,
    callIndex: Int? = 0,
    price: Double? = nil,
    priceSource: String? = nil
  ) -> Self {
    HypernativeParsedActionItem(
      amountInUsd: amountInUsd,
      amount: amount,
      from: from,
      to: to,
      decimals: decimals,
      decimalValue: decimalValue,
      callIndex: callIndex,
      price: price,
      priceSource: priceSource
    )
  }
}

extension HypernativeParsedApprovalItem {
  static func stub(
    tokenName: String? = "USD Coin",
    tokenSymbol: String? = "USDC",
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    tokenTotalSupply: Double? = nil,
    tokenMarketCap: Double? = nil,
    tokenTotalVolume: Double? = nil,
    amountInUsd: Double? = 100.0,
    amount: Double? = 100.0,
    amountAfterDecimals: Double? = nil,
    tokenId: Int? = nil,
    owner: String? = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    spender: String? = "0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186",
    isNft: Bool? = false,
    priceSource: String? = nil,
    logIndex: Int? = nil,
    action: String? = "approve"
  ) -> Self {
    HypernativeParsedApprovalItem(
      tokenName: tokenName,
      tokenSymbol: tokenSymbol,
      tokenAddress: tokenAddress,
      tokenTotalSupply: tokenTotalSupply,
      tokenMarketCap: tokenMarketCap,
      tokenTotalVolume: tokenTotalVolume,
      amountInUsd: amountInUsd,
      amount: amount,
      amountAfterDecimals: amountAfterDecimals,
      tokenId: tokenId,
      owner: owner,
      spender: spender,
      isNft: isNft,
      priceSource: priceSource,
      logIndex: logIndex,
      action: action
    )
  }
}

extension HypernativeParsedApproveItem {
  static func stub(
    from: String? = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String? = "0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186"
  ) -> Self {
    HypernativeParsedApproveItem(
      from: from,
      to: to
    )
  }
}

extension HypernativeFlag {
  static func stub(
    title: String = "Test Flag",
    flagId: String = "test-flag-id",
    chain: String = "ethereum",
    severity: String = "low",
    lastUpdate: String? = "2024-01-01T00:00:00Z",
    events: [HypernativeEvent] = [],
    exposures: [HypernativeExposure] = []
  ) -> Self {
    HypernativeFlag(
      title: title,
      flagId: flagId,
      chain: chain,
      severity: severity,
      lastUpdate: lastUpdate,
      events: events,
      exposures: exposures
    )
  }
}

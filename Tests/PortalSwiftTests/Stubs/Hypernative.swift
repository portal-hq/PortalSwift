//
//  Hypernative.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
import AnyCodable
@testable import PortalSwift

// MARK: - Request Stubs

extension ScanEVMRequest {
  static func stub(
    transaction: ScanEVMTransaction = .stub(),
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

extension ScanEVMTransaction {
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
    ScanEVMTransaction(
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
    eip712Message: ScanEip712TypedData = .stub(),
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

extension ScanEip712TypedData {
  static func stub(
    primaryType: String = "Permit",
    types: [String: [ScanEip712TypeProperty]] = [
      "Permit": [
        ScanEip712TypeProperty(name: "owner", type: "address"),
        ScanEip712TypeProperty(name: "spender", type: "address")
      ]
    ],
    domain: ScanEip712Domain = .stub(),
    message: [String: AnyCodable] = [
      "owner": AnyCodable("0x7b1363f33b86d16ef7c8d03d11f4394a37d95c36"),
      "spender": AnyCodable("0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186"),
      "value": AnyCodable(3000),
      "nonce": AnyCodable(0),
      "deadline": AnyCodable(50000000000)
    ]
  ) -> Self {
    ScanEip712TypedData(
      primaryType: primaryType,
      types: types,
      domain: domain,
      message: message
    )
  }
}

extension ScanEip712Domain {
  static func stub(
    name: String? = "MyToken",
    version: String? = "1",
    chainId: String? = "eip155:1",
    verifyingContract: String? = "0xa0b86991c6218b36c1d19d4a2e9Eb0cE3606eB48",
    salt: String? = nil
  ) -> Self {
    ScanEip712Domain(
      name: name,
      version: version,
      chainId: chainId,
      verifyingContract: verifyingContract,
      salt: salt
    )
  }
}

extension ScanSolanaRequest {
  static func stub(
    transaction: ScanSolanaTransaction = .stub(),
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

extension ScanSolanaTransaction {
  static func stub(
    message: ScanSolanaMessage? = nil,
    signatures: [String]? = nil,
    rawTransaction: String? = "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAQADCQkVR3SiiKbW0l4c3NBsEn6",
    version: String? = "0"
  ) -> Self {
    ScanSolanaTransaction(
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

extension ScanEVMRiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = "2024-01-01T00:00:00Z",
    recommendation: String = "accept",
    findings: [ScanEVMFinding]? = nil,
    balanceChanges: [String: [ScanEVMBalanceChange]]? = nil,
    parsedActions: ScanEVMParsedActions? = nil,
    blockNumber: Int? = nil,
    trace: [ScanEVMTrace]? = nil,
    riIds: [String]? = nil
  ) -> Self {
    ScanEVMRiskData(
      assessmentId: assessmentId,
      assessmentTimestamp: assessmentTimestamp,
      recommendation: recommendation,
      findings: findings,
      balanceChanges: balanceChanges,
      parsedActions: parsedActions,
      blockNumber: blockNumber,
      trace: trace,
      riIds: riIds
    )
  }
}

extension ScanEVMRawResponse {
  static func stub(
    success: Bool = true,
    data: ScanEVMRiskData? = .stub(),
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

extension ScanEip712RiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = nil,
    blockNumber: Int? = nil,
    recommendation: String = "accept",
    trace: [ScanEip712Trace]? = nil,
    riIds: [String]? = nil,
    parsedActions: ScanEip712ParsedActions? = nil
  ) -> Self {
    ScanEip712RiskData(
      assessmentId: assessmentId,
      assessmentTimestamp: assessmentTimestamp,
      blockNumber: blockNumber,
      recommendation: recommendation,
      trace: trace,
      riIds: riIds,
      parsedActions: parsedActions
    )
  }
}

extension ScanEip712RawResponse {
  static func stub(
    success: Bool = true,
    data: ScanEip712RiskData? = .stub(),
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

extension ScanSolanaRiskData {
  static func stub(
    assessmentId: String = "test-id",
    assessmentTimestamp: String? = "2024-01-01T00:00:00Z",
    recommendation: String = "accept",
    expectedStatus: String? = nil,
    findings: [ScanSolanaFinding]? = nil,
    involvedAssets: [ScanSolanaAsset]? = nil,
    balanceChanges: [String: [ScanSolanaBalanceChange]]? = nil,
    parsedActions: ScanSolanaParsedActions? = nil,
    blockNumber: Int? = nil,
    trace: [ScanSolanaTrace]? = nil,
    riIds: [String]? = nil
  ) -> Self {
    ScanSolanaRiskData(
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
    data: ScanSolanaRiskData? = .stub(),
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

extension ScanAddressesItem {
  static func stub(
    address: String = "0x123",
    recommendation: String = "accept",
    severity: String = "low",
    totalIncomingUsd: Double = 0.0,
    policyId: String = "test-policy-id",
    timestamp: String = "2024-01-01T00:00:00Z",
    flags: [ScanAddressesFlag] = []
  ) -> Self {
    ScanAddressesItem(
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
    rawResponse: [ScanAddressesItem] = []
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
    evmChainId: String = "eip155:1",
    accept: Bool = true,
    chain: String = "ethereum"
  ) -> Self {
    ScanNftsResponseItem(
      address: address,
      evmChainId: evmChainId,
      accept: accept,
      chain: chain
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

extension ScanTokensResponseItem {
  static func stub(
    address: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    chain: String = "ethereum",
    reputation: ScanTokensReputation = .stub()
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

extension ScanEVMFinding {
  static func stub(
    typeId: String = "test-type-id",
    title: String = "Test Finding",
    description: String = "Test finding description",
    details: String? = nil,
    severity: String = "Accept",
    relatedAssets: [ScanEVMAsset]? = nil
  ) -> Self {
    ScanEVMFinding(
      typeId: typeId,
      title: title,
      description: description,
      details: details,
      severity: severity,
      relatedAssets: relatedAssets
    )
  }
}

extension ScanEVMAsset {
  static func stub(
    chain: String = "ethereum",
    evmChainId: String? = "eip155:1",
    address: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    type: String = "Contract",
    involvementTypes: [String] = ["transfer"],
    alias: String? = nil,
    tag: String = "USDC"
  ) -> Self {
    ScanEVMAsset(
      chain: chain,
      evmChainId: evmChainId,
      address: address,
      type: type,
      involvementTypes: involvementTypes,
      alias: alias,
      tag: tag
    )
  }
}

extension ScanEVMBalanceChange {
  static func stub(
    changeType: String = "send",
    tokenSymbol: String = "USDC",
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    usdValue: String? = "100.00",
    amount: String = "100000000",
    chain: String = "ethereum",
    evmChainId: String? = "eip155:1"
  ) -> Self {
    ScanEVMBalanceChange(
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

extension ScanEVMParsedActions {
  static func stub(
    ethValues: [ScanEVMParsedActionItem]? = nil,
    tokenValues: [ScanEVMParsedActionItem]? = nil,
    nftValues: [ScanEVMParsedActionItem]? = nil,
    approval: [ScanEVMApprovalItem]? = nil,
    approve: [ScanEVMApproveItem]? = nil
  ) -> Self {
    ScanEVMParsedActions(
      ethValues: ethValues,
      tokenValues: tokenValues,
      nftValues: nftValues,
      approval: approval,
      approve: approve
    )
  }
}

extension ScanEVMParsedActionItem {
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
    ScanEVMParsedActionItem(
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

extension ScanEVMApprovalItem {
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
    ScanEVMApprovalItem(
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

extension ScanEVMApproveItem {
  static func stub(
    from: String? = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String? = "0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186"
  ) -> Self {
    ScanEVMApproveItem(
      from: from,
      to: to
    )
  }
}

extension ScanEVMTrace {
  static func stub(
    from: String = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    funcId: String? = nil,
    callType: String? = nil,
    value: Int? = nil,
    traceAddress: [Int]? = nil,
    status: Int? = 1,
    callInput: String? = nil,
    extraInfo: [String: String]? = nil
  ) -> Self {
    ScanEVMTrace(
      from: from,
      to: to,
      funcId: funcId,
      callType: callType,
      value: value,
      traceAddress: traceAddress,
      status: status,
      callInput: callInput,
      extraInfo: extraInfo
    )
  }
}

extension ScanAddressesFlag {
  static func stub(
    title: String = "Test Flag",
    flagId: String = "test-flag-id",
    chain: String = "ethereum",
    severity: String = "low",
    events: [ScanAddressesEvent] = [],
    lastUpdate: String? = "2024-01-01T00:00:00Z",
    exposures: [ScanAddressesExposure] = []
  ) -> Self {
    ScanAddressesFlag(
      title: title,
      flagId: flagId,
      chain: chain,
      severity: severity,
      events: events,
      lastUpdate: lastUpdate,
      exposures: exposures
    )
  }
}

extension ScanTokensReputation {
  static func stub(
    recommendation: String = "accept"
  ) -> Self {
    ScanTokensReputation(recommendation: recommendation)
  }
}

// MARK: - Missing Request Type Stubs

extension ScanEip712TypeProperty {
  static func stub(
    name: String = "owner",
    type: String = "address"
  ) -> Self {
    ScanEip712TypeProperty(name: name, type: type)
  }
}

extension ScanSolanaMessage {
  static func stub(
    accountKeys: [String] = ["0x123"],
    header: ScanSolanaHeader = .stub(),
    instructions: [ScanSolanaInstruction] = [.stub()],
    addressTableLookups: [ScanSolanaAddressTableLookup]? = nil,
    recentBlockhash: String = "test-blockhash"
  ) -> Self {
    ScanSolanaMessage(
      accountKeys: accountKeys,
      header: header,
      instructions: instructions,
      addressTableLookups: addressTableLookups,
      recentBlockhash: recentBlockhash
    )
  }
}

extension ScanSolanaHeader {
  static func stub(
    numReadonlySignedAccounts: Int = 0,
    numReadonlyUnsignedAccounts: Int = 0,
    numRequiredSignatures: Int = 1
  ) -> Self {
    ScanSolanaHeader(
      numReadonlySignedAccounts: numReadonlySignedAccounts,
      numReadonlyUnsignedAccounts: numReadonlyUnsignedAccounts,
      numRequiredSignatures: numRequiredSignatures
    )
  }
}

extension ScanSolanaInstruction {
  static func stub(
    accounts: [Int] = [0],
    data: String = "test-data",
    programIdIndex: Int = 0
  ) -> Self {
    ScanSolanaInstruction(
      accounts: accounts,
      data: data,
      programIdIndex: programIdIndex
    )
  }
}

extension ScanSolanaAddressTableLookup {
  static func stub(
    accountKey: String = "0x123",
    writableIndexes: [Int] = [],
    readonlyIndexes: [Int] = []
  ) -> Self {
    ScanSolanaAddressTableLookup(
      accountKey: accountKey,
      writableIndexes: writableIndexes,
      readonlyIndexes: readonlyIndexes
    )
  }
}

// MARK: - Missing EIP-712 Response Type Stubs

extension ScanEip712Trace {
  static func stub(
    from: String = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    funcId: String? = nil,
    callType: String? = nil,
    value: Int? = nil,
    traceAddress: [Int]? = nil,
    status: Int? = 1,
    callInput: String? = nil,
    extraInfo: [String: String]? = nil
  ) -> Self {
    ScanEip712Trace(
      from: from,
      to: to,
      funcId: funcId,
      callType: callType,
      value: value,
      traceAddress: traceAddress,
      status: status,
      callInput: callInput,
      extraInfo: extraInfo
    )
  }
}

extension ScanEip712ParsedActions {
  static func stub(
    approval: [ScanEip712ApprovalItem]? = nil,
    ethValues: [ScanEip712ParsedActionItem]? = nil
  ) -> Self {
    ScanEip712ParsedActions(
      approval: approval,
      ethValues: ethValues
    )
  }
}

extension ScanEip712ApprovalItem {
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
    ScanEip712ApprovalItem(
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

extension ScanEip712ParsedActionItem {
  static func stub(
    amountInUsd: Double? = 100.0,
    amount: Double? = 1.0,
    from: String? = "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
    to: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  ) -> Self {
    ScanEip712ParsedActionItem(
      amountInUsd: amountInUsd,
      amount: amount,
      from: from,
      to: to
    )
  }
}

// MARK: - Missing Solana Response Type Stubs

extension ScanSolanaFinding {
  static func stub(
    typeId: String = "test-type-id",
    title: String = "Test Finding",
    description: String = "Test finding description",
    details: String? = nil,
    severity: String = "Accept",
    relatedAssets: [ScanSolanaAsset]? = nil
  ) -> Self {
    ScanSolanaFinding(
      typeId: typeId,
      title: title,
      description: description,
      details: details,
      severity: severity,
      relatedAssets: relatedAssets
    )
  }
}

extension ScanSolanaAsset {
  static func stub(
    chain: String = "solana",
    address: String = "0x123",
    type: String = "Contract",
    involvementTypes: [String] = ["transfer"],
    alias: String? = nil,
    tag: String = "SOL"
  ) -> Self {
    ScanSolanaAsset(
      chain: chain,
      address: address,
      type: type,
      involvementTypes: involvementTypes,
      alias: alias,
      tag: tag
    )
  }
}

extension ScanSolanaBalanceChange {
  static func stub(
    changeType: String = "send",
    tokenSymbol: String = "SOL",
    tokenAddress: String? = nil,
    usdValue: String? = "100.00",
    amount: String = "1000000000",
    chain: String = "solana"
  ) -> Self {
    ScanSolanaBalanceChange(
      changeType: changeType,
      tokenSymbol: tokenSymbol,
      tokenAddress: tokenAddress,
      usdValue: usdValue,
      amount: amount,
      chain: chain
    )
  }
}

extension ScanSolanaParsedActions {
  static func stub(
    ethValues: [ScanSolanaParsedActionItem]? = nil,
    tokenValues: [ScanSolanaParsedActionItem]? = nil
  ) -> Self {
    ScanSolanaParsedActions(
      ethValues: ethValues,
      tokenValues: tokenValues
    )
  }
}

extension ScanSolanaParsedActionItem {
  static func stub(
    amountInUsd: Double? = 100.0,
    amount: Double? = 1.0,
    from: String? = "0x123",
    to: String? = "0x456",
    decimals: Int? = 9,
    decimalValue: Int? = nil,
    callIndex: Int? = 0,
    price: Double? = nil,
    priceSource: String? = nil
  ) -> Self {
    ScanSolanaParsedActionItem(
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

extension ScanSolanaTrace {
  static func stub(
    from: String = "0x123",
    to: String = "0x456",
    funcId: String? = nil,
    callType: String? = nil,
    value: Int? = nil,
    traceAddress: [Int]? = nil,
    status: String? = "True",
    callInput: ScanSolanaTraceCallInput? = nil,
    extraInfo: [String: String]? = nil
  ) -> Self {
    ScanSolanaTrace(
      from: from,
      to: to,
      funcId: funcId,
      callType: callType,
      value: value,
      traceAddress: traceAddress,
      status: status,
      callInput: callInput,
      extraInfo: extraInfo
    )
  }
}

extension ScanSolanaTraceCallInput {
  static func stub(
    type: String? = "transfer",
    info: ScanSolanaTraceCallInputInfo? = nil
  ) -> Self {
    ScanSolanaTraceCallInput(
      type: type,
      info: info
    )
  }
}

extension ScanSolanaTransferInfo {
  static func stub(
    source: String? = "0x123",
    destination: String? = "0x456",
    lamports: Int? = 1000000000
  ) -> Self {
    ScanSolanaTransferInfo(
      source: source,
      destination: destination,
      lamports: lamports
    )
  }
}

// MARK: - Missing Addresses Response Type Stubs

extension ScanAddressesEvent {
  static func stub(
    eventId: String? = "test-event-id",
    address: String? = "0x123",
    chain: String? = "ethereum",
    flagId: String? = "test-flag-id",
    timestampEvent: String? = "2024-01-01T00:00:00Z",
    txHash: String? = "0xhash",
    direction: String? = "incoming",
    hop: Int? = 1,
    counterpartyAddress: String? = "0x456",
    counterpartyAlias: String? = nil,
    counterpartyFlagId: String? = "test-flag-id",
    tokenSymbol: String? = "USDC",
    tokenAmount: Double? = 100.0,
    tokenUsdValue: Double? = 100.0,
    reason: String? = "test-reason",
    source: String? = "test-source",
    originalFlaggedAddress: String? = "0x789",
    originalFlaggedAlias: String? = nil,
    originalFlaggedChain: String? = "ethereum"
  ) -> Self {
    ScanAddressesEvent(
      eventId: eventId,
      address: address,
      chain: chain,
      flagId: flagId,
      timestampEvent: timestampEvent,
      txHash: txHash,
      direction: direction,
      hop: hop,
      counterpartyAddress: counterpartyAddress,
      counterpartyAlias: counterpartyAlias,
      counterpartyFlagId: counterpartyFlagId,
      tokenSymbol: tokenSymbol,
      tokenAmount: tokenAmount,
      tokenUsdValue: tokenUsdValue,
      reason: reason,
      source: source,
      originalFlaggedAddress: originalFlaggedAddress,
      originalFlaggedAlias: originalFlaggedAlias,
      originalFlaggedChain: originalFlaggedChain
    )
  }
}

extension ScanAddressesExposure {
  static func stub(
    exposurePortion: Double = 0.5,
    exposureType: String? = "direct",
    totalExposureUsd: Double = 1000.0,
    flaggedInteractions: [ScanAddressesFlaggedInteraction] = []
  ) -> Self {
    ScanAddressesExposure(
      exposurePortion: exposurePortion,
      exposureType: exposureType,
      totalExposureUsd: totalExposureUsd,
      flaggedInteractions: flaggedInteractions
    )
  }
}

extension ScanAddressesFlaggedInteraction {
  static func stub(
    address: String = "0x123",
    chain: String = "ethereum",
    alias: String? = nil,
    minHop: Int = 1,
    totalExposureUsd: Double = 500.0
  ) -> Self {
    ScanAddressesFlaggedInteraction(
      address: address,
      chain: chain,
      alias: alias,
      minHop: minHop,
      totalExposureUsd: totalExposureUsd
    )
  }
}

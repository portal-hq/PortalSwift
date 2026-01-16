//
//  HypernativeModels.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Request Models

/// Request to scan an EVM transaction for security risks
public struct ScanEVMRequest: Codable {
  public let transaction: HypernativeTransactionObject
  public let url: String?
  public let blockNumber: Int?
  public let validateNonce: Bool?
  public let showFullFindings: Bool?
  public let policy: String?
  
  public init(
    transaction: HypernativeTransactionObject,
    url: String? = nil,
    blockNumber: Int? = nil,
    validateNonce: Bool? = nil,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) {
    self.transaction = transaction
    self.url = url
    self.blockNumber = blockNumber
    self.validateNonce = validateNonce
    self.showFullFindings = showFullFindings
    self.policy = policy
  }
}

/// Request to scan an EIP-712 typed message for security risks
public struct ScanEip712Request: Codable {
  public let walletAddress: String
  public let chainId: String
  public let eip712Message: Eip712TypedData
  public let showFullFindings: Bool?
  public let policy: String?
  
  public init(
    walletAddress: String,
    chainId: String,
    eip712Message: Eip712TypedData,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) {
    self.walletAddress = walletAddress
    self.chainId = chainId
    self.eip712Message = eip712Message
    self.showFullFindings = showFullFindings
    self.policy = policy
  }
}

/// Request to scan a Solana transaction for security risks
public struct ScanSolanaRequest: Codable {
  public let transaction: SolanaTransaction
  public let url: String?
  public let validateRecentBlockHash: Bool?
  public let showFullFindings: Bool?
  public let policy: String?
  
  public init(
    transaction: SolanaTransaction,
    url: String? = nil,
    validateRecentBlockHash: Bool? = nil,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) {
    self.transaction = transaction
    self.url = url
    self.validateRecentBlockHash = validateRecentBlockHash
    self.showFullFindings = showFullFindings
    self.policy = policy
  }
}

/// Request to screen addresses for security risks
public struct ScanAddressesRequest: Codable {
  public let addresses: [String]
  public let screenerPolicyId: String?
  
  public init(
    addresses: [String],
    screenerPolicyId: String? = nil
  ) {
    self.addresses = addresses
    self.screenerPolicyId = screenerPolicyId
  }
}

/// Request to scan NFTs for security risks
public struct ScanNftsRequest: Codable {
  public let nfts: [ScanNftsRequestItem]
  
  public init(nfts: [ScanNftsRequestItem]) {
    self.nfts = nfts
  }
}

/// Request to scan tokens for security risks
public struct ScanTokensRequest: Codable {
  public let tokens: [ScanTokensRequestItem]
  
  public init(tokens: [ScanTokensRequestItem]) {
    self.tokens = tokens
  }
}

/// Request to scan a URL for security risks
public struct ScanUrlRequest: Codable {
  public let url: String
  
  public init(url: String) {
    self.url = url
  }
}

// MARK: - Response Models

/// Response from EVM transaction scan
public struct ScanEVMResponse: Codable {
  public let data: ScanEVMData?
  public let error: String?
}

public struct ScanEVMData: Codable {
  public let rawResponse: ScanEVMRawResponse
}

public struct ScanEVMRawResponse: Codable {
  public let success: Bool
  public let data: TransactionRiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

/// Response from EIP-712 transaction scan
public struct ScanEip712Response: Codable {
  public let data: ScanEip712Data?
  public let error: String?
}

public struct ScanEip712Data: Codable {
  public let rawResponse: ScanEip712RawResponse
}

public struct ScanEip712RawResponse: Codable {
  public let success: Bool
  public let data: TypedMessageRiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

/// Response from Solana transaction scan
public struct ScanSolanaResponse: Codable {
  public let data: ScanSolanaData?
  public let error: String?
}

public struct ScanSolanaData: Codable {
  public let rawResponse: ScanSolanaRawResponse
}

public struct ScanSolanaRawResponse: Codable {
  public let success: Bool
  public let data: SolanaTransactionRiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

/// Response from address screening
public struct ScanAddressesResponse: Codable {
  public let data: ScanAddressesData?
  public let error: String?
}

public struct ScanAddressesData: Codable {
  public let rawResponse: [ScanAddressesResponseItem]
}

/// Response from NFT scan
public struct ScanNftsResponse: Codable {
  public let data: ScanNftsData?
  public let error: String?
}

public struct ScanNftsData: Codable {
  public let rawResponse: ScanNftsRawResponse
}

public struct ScanNftsRawResponse: Codable {
  public let success: Bool
  public let data: ScanNftsDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanNftsDataContent: Codable {
  public let nfts: [ScanNftsResponseItem]
}

/// Response from token scan
public struct ScanTokensResponse: Codable {
  public let data: ScanTokensData?
  public let error: String?
}

public struct ScanTokensData: Codable {
  public let rawResponse: ScanTokensRawResponse
}

public struct ScanTokensRawResponse: Codable {
  public let success: Bool
  public let data: ScanTokensDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanTokensDataContent: Codable {
  public let tokens: [ScanTokensResponseItem]
}

/// Response from URL scan
public struct ScanUrlResponse: Codable {
  public let data: ScanUrlData?
  public let error: String?
}

public struct ScanUrlData: Codable {
  public let rawResponse: ScanUrlRawResponse
}

public struct ScanUrlRawResponse: Codable {
  public let success: Bool
  public let data: ScanUrlDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanUrlDataContent: Codable {
  public let isMalicious: Bool
  public let deepScanTriggered: Bool?
}

// MARK: - Transaction Objects

public struct HypernativeTransactionObject: Codable {
  public let chain: String
  public let fromAddress: String
  public let toAddress: String
  public let input: String?
  public let value: Int?
  public let nonce: Int?
  public let hash: String?
  public let gas: Int?
  public let gasPrice: Int?
  public let maxPriorityFeePerGas: Int?
  public let maxFeePerGas: Int?
  
  public init(
    chain: String,
    fromAddress: String,
    toAddress: String,
    input: String? = nil,
    value: Int? = nil,
    nonce: Int? = nil,
    hash: String? = nil,
    gas: Int? = nil,
    gasPrice: Int? = nil,
    maxPriorityFeePerGas: Int? = nil,
    maxFeePerGas: Int? = nil
  ) {
    self.chain = chain
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.input = input
    self.value = value
    self.nonce = nonce
    self.hash = hash
    self.gas = gas
    self.gasPrice = gasPrice
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
  }
}

// MARK: - EIP-712 Types

public struct Eip712TypedData: Codable {
  public let primaryType: String
  public let types: [String: [Eip712TypeProperty]]
  public let domain: Eip712Domain
  public let message: Eip712Message
  
  public init(
    primaryType: String,
    types: [String: [Eip712TypeProperty]],
    domain: Eip712Domain,
    message: Eip712Message
  ) {
    self.primaryType = primaryType
    self.types = types
    self.domain = domain
    self.message = message
  }
}

public struct Eip712TypeProperty: Codable {
  public let name: String
  public let type: String
  
  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

public struct Eip712Domain: Codable {
  public let name: String?
  public let version: String?
  public let chainId: String?
  public let verifyingContract: String?
  public let salt: String?
  
  public init(
    name: String? = nil,
    version: String? = nil,
    chainId: String? = nil,
    verifyingContract: String? = nil,
    salt: String? = nil
  ) {
    self.name = name
    self.version = version
    self.chainId = chainId
    self.verifyingContract = verifyingContract
    self.salt = salt
  }
}

public struct Eip712Message: Codable {
  public let owner: String
  public let spender: String
  public let value: Int
  public let nonce: Int
  public let deadline: Int64
  
  public init(
    owner: String,
    spender: String,
    value: Int,
    nonce: Int,
    deadline: Int64
  ) {
    self.owner = owner
    self.spender = spender
    self.value = value
    self.nonce = nonce
    self.deadline = deadline
  }
}

// MARK: - Solana Transaction Types

public struct SolanaTransaction: Codable {
  public let message: SolanaMessage?
  public let signatures: [String]?
  public let rawTransaction: String?
  public let version: String?
  
  public init(
    message: SolanaMessage? = nil,
    signatures: [String]? = nil,
    rawTransaction: String? = nil,
    version: String? = nil
  ) {
    self.message = message
    self.signatures = signatures
    self.rawTransaction = rawTransaction
    self.version = version
  }
}

public struct SolanaMessage: Codable {
  public let accountKeys: [String]
  public let header: SolanaHeader
  public let instructions: [SolanaInstruction]
  public let addressTableLookups: [AddressTableLookup]?
  public let recentBlockhash: String
  
  public init(
    accountKeys: [String],
    header: SolanaHeader,
    instructions: [SolanaInstruction],
    addressTableLookups: [AddressTableLookup]? = nil,
    recentBlockhash: String
  ) {
    self.accountKeys = accountKeys
    self.header = header
    self.instructions = instructions
    self.addressTableLookups = addressTableLookups
    self.recentBlockhash = recentBlockhash
  }
}

public struct SolanaInstruction: Codable {
  public let accounts: [Int]
  public let data: String
  public let programIdIndex: Int
  
  public init(
    accounts: [Int],
    data: String,
    programIdIndex: Int
  ) {
    self.accounts = accounts
    self.data = data
    self.programIdIndex = programIdIndex
  }
}

public struct AddressTableLookup: Codable {
  public let accountKey: String
  public let writableIndexes: [Int]
  public let readonlyIndexes: [Int]
  
  public init(
    accountKey: String,
    writableIndexes: [Int],
    readonlyIndexes: [Int]
  ) {
    self.accountKey = accountKey
    self.writableIndexes = writableIndexes
    self.readonlyIndexes = readonlyIndexes
  }
}

// MARK: - Risk Data Models

public struct TransactionRiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let recommendation: HypernativeRecommendation
  public let expectedStatus: HypernativeExpectedStatus?
  public let findings: [HypernativeFinding]?
  public let involvedAssets: [HypernativeAsset]?
  public let balanceChanges: [String: [HypernativeBalanceChange]]?
  public let parsedActions: HypernativeParsedActions?
  public let blockNumber: Int?
  public let trace: [HypernativeTrace]?
  public let riIds: [String]?
  public let signature: String?
}

public struct TypedMessageRiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let blockNumber: Int?
  public let recommendation: HypernativeRecommendation
  public let findings: [HypernativeFinding]?
  public let involvedAssets: [HypernativeAsset]?
  public let parsedActions: HypernativeParsedActions?
  public let trace: [HypernativeTrace]?
  public let riIds: [String]?
}

public struct SolanaTransactionRiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let recommendation: HypernativeRecommendation
  public let expectedStatus: HypernativeExpectedStatus?
  public let findings: [HypernativeFinding]?
  public let involvedAssets: [HypernativeAsset]?
  public let balanceChanges: [String: [HypernativeBalanceChange]]?
  public let parsedActions: HypernativeParsedActions?
  public let blockNumber: Int?
  public let trace: [HypernativeTrace]?
  public let riIds: [String]?
}

// MARK: - Finding and Asset Models

public struct HypernativeFinding: Codable {
  public let typeId: String
  public let title: String
  public let description: String
  public let details: String?
  public let severity: HypernativeSeverity
  public let relatedAssets: [HypernativeAsset]?
}

public struct HypernativeAsset: Codable {
  public let chain: String
  public let evmChainId: String?
  public let address: String
  public let type: HypernativeAssetType
  public let involvementTypes: [String]
  public let tag: String
  public let alias: String?
  public let note: String?
}

public struct HypernativeBalanceChange: Codable {
  public let changeType: HypernativeChangeType
  public let tokenSymbol: String
  public let tokenAddress: String?
  public let usdValue: String?
  public let amount: String
  public let chain: String
  public let evmChainId: String?
}

// MARK: - Address Screening Models

public struct ScanAddressesResponseItem: Codable {
  public let address: String
  public let recommendation: String
  public let severity: String
  public let totalIncomingUsd: Double
  public let policyId: String
  public let timestamp: String
  public let flags: [HypernativeFlag]
}

public struct HypernativeFlag: Codable {
  public let title: String
  public let flagId: String
  public let chain: String
  public let severity: String
  public let lastUpdate: String?
  public let events: [HypernativeEvent]
  public let exposures: [HypernativeExposure]
}

public struct HypernativeEvent: Codable {
  public let eventId: String
  public let address: String
  public let chain: String
  public let flagId: String
  public let timestampEvent: String
  public let txHash: String
  public let direction: String
  public let hop: Int
  public let counterpartyAddress: String
  public let counterpartyAlias: String?
  public let counterpartyFlagId: String
  public let tokenSymbol: String
  public let tokenAmount: Double
  public let tokenUsdValue: Double
  public let reason: String
  public let source: String
  public let originalFlaggedAddress: String
  public let originalFlaggedAlias: String?
  public let originalFlaggedChain: String
}

public struct HypernativeExposure: Codable {
  public let exposurePortion: Double
  public let exposureType: String?
  public let totalExposureUsd: Double
  public let flaggedInteractions: [HypernativeFlaggedInteraction]
}

public struct HypernativeFlaggedInteraction: Codable {
  public let address: String
  public let chain: String
  public let alias: String?
  public let minHop: Int
  public let totalExposureUsd: Double
}

// MARK: - NFT and Token Models

public struct ScanNftsRequestItem: Codable {
  public let address: String
  public let chain: String?
  public let evmChainId: String?
  
  public init(
    address: String,
    chain: String? = nil,
    evmChainId: String? = nil
  ) {
    self.address = address
    self.chain = chain
    self.evmChainId = evmChainId
  }
}

public struct ScanNftsResponseItem: Codable {
  public let address: String
  public let chain: String
  public let evmChainId: String
  public let accept: Bool
}

public struct ScanTokensRequestItem: Codable {
  public let address: String
  public let chain: String?
  public let evmChainId: String?
  
  public init(
    address: String,
    chain: String? = nil,
    evmChainId: String? = nil
  ) {
    self.address = address
    self.chain = chain
    self.evmChainId = evmChainId
  }
}

public struct ScanTokensResponseItem: Codable {
  public let address: String
  public let chain: String
  public let reputation: TokenReputation?
}

public struct TokenReputation: Codable {
  public let recommendation: String
}

// MARK: - Enums

public enum HypernativeRecommendation: String, Codable {
  case accept
  case notes
  case warn
  case deny
  case autoAccept
}

public enum HypernativeSeverity: String, Codable {
  case Accept
  case Notes
  case Warn
  case Deny
  case AutoAccept
}

public enum HypernativeAssetType: String, Codable {
  case Wallet
  case Contract
}

public enum HypernativeChangeType: String, Codable {
  case send
  case receive
}

public enum HypernativeExpectedStatus: String, Codable {
  case success
  case fail
}

// MARK: - Parsed Actions Models

public struct HypernativeParsedActions: Codable {
  public let ethValues: [HypernativeParsedActionItem]?
  public let tokenValues: [HypernativeParsedActionItem]?
  public let nftValues: [HypernativeParsedActionItem]?
  public let approval: [HypernativeParsedApprovalItem]?
  public let approve: [HypernativeParsedApproveItem]? 
  
  private enum CodingKeys: String, CodingKey {
    case ethValues
    case tokenValues
    case nftValues
    case approval
    case approve = "Approve"
  }
}

public struct HypernativeParsedApproveItem: Codable {
  public let from: String?
  public let to: String?
}

public struct HypernativeParsedActionItem: Codable {
  public let amountInUsd: Double?
  public let amount: Double?
  public let from: String?
  public let to: String?
  public let decimals: Int?
  public let decimalValue: Int?
  public let callIndex: Int?
  public let price: Double?
  public let priceSource: String?
}

public struct HypernativeParsedApprovalItem: Codable {
  public let tokenName: String?
  public let tokenSymbol: String?
  public let tokenAddress: String?
  public let tokenTotalSupply: Double?
  public let tokenMarketCap: Double?
  public let tokenTotalVolume: Double?
  public let amountInUsd: Double?
  public let amount: Double?
  public let amountAfterDecimals: Double?
  public let tokenId: Int?
  public let owner: String?
  public let spender: String?
  public let isNft: Bool?
  public let priceSource: String?
  public let logIndex: Int?
  public let action: String?
}

// MARK: - Trace Models

public struct HypernativeTrace: Codable {
  public let from: String
  public let to: String
  public let funcId: String?
  public let callType: String?
  public let value: Int?
  public let traceAddress: [Int]?
  public let status: HypernativeTraceStatus?
  public let callInput: HypernativeTraceCallInput?
}

/// Handles both int (EVM: 1) and string (Solana: "True") status values
public enum HypernativeTraceStatus: Codable {
  case int(Int)
  case string(String)
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intValue = try? container.decode(Int.self) {
      self = .int(intValue)
    } else if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else {
      self = .int(0)
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .int(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }
  
  public var isSuccess: Bool {
    switch self {
    case .int(let value): return value == 1
    case .string(let value): return value.lowercased() == "true"
    }
  }
}

/// Handles both string (EVM: "0x...") and object (Solana: { type, info }) callInput values
public enum HypernativeTraceCallInput: Codable {
  case hexString(String)
  case object(HypernativeTraceCallInputObject)
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringValue = try? container.decode(String.self) {
      self = .hexString(stringValue)
    } else if let objectValue = try? container.decode(HypernativeTraceCallInputObject.self) {
      self = .object(objectValue)
    } else {
      self = .hexString("")
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .hexString(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}

public struct HypernativeTraceCallInputObject: Codable {
  public let type: String?
  public let info: HypernativeTraceCallInputInfo?
}

/// Handles both string info ("K17Tvf") and object info (transfer details)
public enum HypernativeTraceCallInputInfo: Codable {
  case string(String)
  case transfer(HypernativeTransferInfo)
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else if let transferInfo = try? container.decode(HypernativeTransferInfo.self) {
      self = .transfer(transferInfo)
    } else {
      self = .string("")
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .transfer(let value): try container.encode(value)
    }
  }
}

public struct HypernativeTransferInfo: Codable {
  public let source: String?
  public let destination: String?
  public let lamports: Int?
}

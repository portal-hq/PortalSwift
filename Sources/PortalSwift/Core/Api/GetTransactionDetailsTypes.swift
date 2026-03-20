import AnyCodable

// MARK: - Top-level Response

public struct GetTransactionDetailsResponse: Codable {
  public let data: TransactionLookupResponse
  public let metadata: GetTransactionDetailsMetadata
}

public struct GetTransactionDetailsMetadata: Codable {
  public let chainId: String
  public let signature: String
}

public struct TransactionLookupResponse: Codable {
  public let evmTransaction: EvmTransactionLookupResult?
  public let evmUserOperation: EvmUserOperationLookupResult?
  public let solanaTransaction: SolanaTransactionLookupResult?
  public let bitcoinTransaction: BitcoinTransactionLookupResult?
  public let stellarTransaction: StellarTransactionLookupResult?
  public let tronTransaction: TronTransactionLookupResult?
}

// MARK: - EVM Transaction

public struct EvmTransactionLookupResult: Codable {
  public let hash: String
  public let from: String
  public let to: String?
  public let value: String
  public let nonce: String
  public let blockNumber: String?
  public let blockHash: String?
  public let transactionIndex: String?
  public let gas: String
  public let gasPrice: String?
  public let maxFeePerGas: String?
  public let maxPriorityFeePerGas: String?
  public let input: String
  public let type: String
  public let status: String?
  public let gasUsed: String?
  public let effectiveGasPrice: String?
  public let logs: [EvmTransactionLookupLog]?
  public let contractAddress: String?
}

public struct EvmTransactionLookupLog: Codable {
  public let address: String
  public let topics: [String]
  public let data: String
  public let blockNumber: String
  public let transactionHash: String
  public let logIndex: String
}

// MARK: - EVM User Operation

public struct EvmUserOperationLookupResult: Codable {
  public let sender: String
  public let nonce: String
  public let callData: String
  public let callGasLimit: String
  public let verificationGasLimit: String
  public let preVerificationGas: String
  public let maxFeePerGas: String
  public let maxPriorityFeePerGas: String
  public let signature: String
  public let entryPoint: String
  public let success: Bool?
  public let actualGasCost: String?
  public let actualGasUsed: String?
  public let receipt: EvmTransactionLookupResult?
}

// MARK: - Solana Transaction

public struct SolanaTransactionLookupResult: Codable {
  public let blockTime: Int?
  public let error: String?
  public let signature: String
  public let status: String
  public let transactionDetails: SolanaTransactionDetailsInner?
}

public struct SolanaTransactionDetailsInner: Codable {
  public let transaction: SolanaTransactionContent?
  public let signatureDetails: SolanaLookupSignatureDetails?
  public let metadata: SolanaTransactionLookupMetadata?
}

public struct SolanaTransactionContent: Codable {
  public let message: SolanaTransactionLookupMessage?
  public let signatures: [String]?
}

public struct SolanaTransactionLookupMessage: Codable {
  public let accountKeys: [String]?
  public let header: SolanaLookupMessageHeader?
  public let instructions: [SolanaLookupInstruction]?
  public let recentBlockhash: String?
}

public struct SolanaLookupMessageHeader: Codable {
  public let numReadonlySignedAccounts: Int?
  public let numReadonlyUnsignedAccounts: Int?
  public let numRequiredSignatures: Int?
}

public struct SolanaLookupInstruction: Codable {
  public let accounts: [Int]?
  public let data: String?
  public let programIdIndex: Int?
  public let stackHeight: Int?
}

public struct SolanaLookupSignatureDetails: Codable {
  public let blockTime: Int?
  public let confirmationStatus: String?
  public let error: AnyCodable?
  public let memo: String?
  public let signature: String?
  public let slot: Int?
}

public struct SolanaTransactionLookupMetadata: Codable {
  public let blockTime: Int?
  public let slot: Int?
  public let error: AnyCodable?
  public let fee: Int?
  public let innerInstructions: [AnyCodable]?
  public let loadedAddresses: SolanaLookupLoadedAddresses?
  public let logMessages: [String]?
  public let postBalances: [AnyCodable]?
  public let postTokenBalances: [AnyCodable]?
  public let preBalances: [AnyCodable]?
  public let preTokenBalances: [AnyCodable]?
  public let rewards: [AnyCodable]?
  public let status: AnyCodable?
  public let version: String?
}

public struct SolanaLookupLoadedAddresses: Codable {
  public let readonly: [String]?
  public let writable: [String]?
}

// MARK: - Bitcoin Transaction

public struct BitcoinTransactionLookupResult: Codable {
  public let txid: String
  public let version: Int
  public let size: Int
  public let weight: Int
  public let locktime: Int
  public let fee: Int
  public let status: BitcoinTransactionLookupStatus
  public let vin: [BitcoinLookupVin]
  public let vout: [BitcoinLookupVout]
}

public struct BitcoinTransactionLookupStatus: Codable {
  public let confirmed: Bool
  public let blockHeight: Int?
  public let blockHash: String?
  public let blockTime: Int?
}

public struct BitcoinLookupVin: Codable {
  public let txid: String
  public let vout: Int
  public let prevout: BitcoinLookupPrevout?
  public let scriptsig: String
  public let witness: [String]
  public let sequence: UInt

  enum CodingKeys: String, CodingKey {
    case txid, vout, prevout, scriptsig, witness, sequence
  }
}

public struct BitcoinLookupPrevout: Codable {
  public let scriptpubkey: String
  public let scriptpubkeyAddress: String
  public let value: Int

  enum CodingKeys: String, CodingKey {
    case scriptpubkey
    case scriptpubkeyAddress = "scriptpubkey_address"
    case value
  }
}

public struct BitcoinLookupVout: Codable {
  public let scriptpubkey: String
  public let scriptpubkeyAddress: String
  public let value: Int

  enum CodingKeys: String, CodingKey {
    case scriptpubkey
    case scriptpubkeyAddress = "scriptpubkey_address"
    case value
  }
}

// MARK: - Stellar Transaction

public struct StellarTransactionLookupResult: Codable {
  public let id: String
  public let hash: String
  public let ledger: Int
  public let createdAt: String
  public let sourceAccount: String
  public let feeCharged: String
  public let maxFee: String
  public let operationCount: Int
  public let successful: Bool
  public let memo: String?
  public let memoType: String
  public let operations: [AnyCodable]
}

// MARK: - Tron Transaction

public struct TronTransactionLookupResult: Codable {
  public let txID: String
  public let blockNumber: Int?
  public let blockTimeStamp: Int64?
  public let contractResult: [String]
  public let receipt: TronTransactionLookupReceipt?
  public let contractType: String?
  public let contractData: AnyCodable?
  public let result: String?
}

public struct TronTransactionLookupReceipt: Codable {
  public let result: String?
  public let energyUsage: Int?
  public let energyUsageTotal: Int?
  public let netUsage: Int?
}

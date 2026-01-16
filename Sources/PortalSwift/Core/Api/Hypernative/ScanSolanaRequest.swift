//
//  ScanSolanaRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanSolanaRequest

public struct ScanSolanaRequest: Codable {
  public let transaction: ScanSolanaTransaction
  public let url: String?
  public let validateRecentBlockHash: Bool?
  public let showFullFindings: Bool?
  public let policy: String?

  public init(
    transaction: ScanSolanaTransaction,
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

// MARK: - Solana-Specific Types

public struct ScanSolanaTransaction: Codable {
  public let message: ScanSolanaMessage?
  public let signatures: [String]?
  public let rawTransaction: String?
  public let version: String?

  public init(
    message: ScanSolanaMessage? = nil,
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

public struct ScanSolanaMessage: Codable {
  public let accountKeys: [String]
  public let header: ScanSolanaHeader
  public let instructions: [ScanSolanaInstruction]
  public let addressTableLookups: [ScanSolanaAddressTableLookup]?
  public let recentBlockhash: String

  public init(
    accountKeys: [String],
    header: ScanSolanaHeader,
    instructions: [ScanSolanaInstruction],
    addressTableLookups: [ScanSolanaAddressTableLookup]? = nil,
    recentBlockhash: String
  ) {
    self.accountKeys = accountKeys
    self.header = header
    self.instructions = instructions
    self.addressTableLookups = addressTableLookups
    self.recentBlockhash = recentBlockhash
  }
}

public struct ScanSolanaHeader: Codable {
  public let numReadonlySignedAccounts: Int
  public let numReadonlyUnsignedAccounts: Int
  public let numRequiredSignatures: Int

  public init(
    numReadonlySignedAccounts: Int,
    numReadonlyUnsignedAccounts: Int,
    numRequiredSignatures: Int
  ) {
    self.numReadonlySignedAccounts = numReadonlySignedAccounts
    self.numReadonlyUnsignedAccounts = numReadonlyUnsignedAccounts
    self.numRequiredSignatures = numRequiredSignatures
  }
}

public struct ScanSolanaInstruction: Codable {
  public let accounts: [Int]
  public let data: String
  public let programIdIndex: Int

  public init(accounts: [Int], data: String, programIdIndex: Int) {
    self.accounts = accounts
    self.data = data
    self.programIdIndex = programIdIndex
  }
}

public struct ScanSolanaAddressTableLookup: Codable {
  public let accountKey: String
  public let writableIndexes: [Int]
  public let readonlyIndexes: [Int]

  public init(accountKey: String, writableIndexes: [Int], readonlyIndexes: [Int]) {
    self.accountKey = accountKey
    self.writableIndexes = writableIndexes
    self.readonlyIndexes = readonlyIndexes
  }
}

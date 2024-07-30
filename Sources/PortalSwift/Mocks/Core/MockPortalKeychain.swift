//
//  MockPortalKeychain.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalKeychain: PortalKeychain {
  override public func deleteShares() async throws {}

  override public func getAddress(_ forChainId: String) async throws -> String? {
    if forChainId.starts(with: "eip155") {
      return MockConstants.mockEip155Address
    } else if forChainId.starts(with: "solana") {
      return MockConstants.mockSolanaAddress
    }

    throw PortalKeychain.KeychainError.unsupportedNamespace(forChainId)
  }

  override public func getAddresses() async throws -> [PortalNamespace: String?] {
    [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress
    ]
  }

  override public func getMetadata() async throws -> PortalKeychainClientMetadata {
    MockConstants.mockKeychainClientMetadata
  }

  override public func getShare(_ forChainId: String) async throws -> String {
    if forChainId.starts(with: "eip155") {
      return try MockConstants.mockMpcShareString
    } else if forChainId.starts(with: "solana") {
      return try MockConstants.mockMpcShareString
    }

    throw PortalKeychain.KeychainError.unsupportedNamespace(forChainId)
  }

  override public func getShares() async throws -> PortalKeychainClientShares {
    try await MockConstants.mockGenerateResponse
  }

  override public func loadMetadata() async throws {
    try await super.loadMetadata()
    self.legacyAddress = try self.getAddress()
  }

  override public func setMetadata(_: PortalKeychainClientMetadata) async throws {}

  override public func setShares(_: [String: PortalMpcGeneratedShare]) async throws {}

  // Deprecated functions

  override public func getAddress() throws -> String {
    MockConstants.mockEip155Address
  }

  override public func getSigningShare() throws -> String {
    try MockConstants.mockMpcShareString
  }

  override public func deleteAddress() throws {}

  override public func deleteSigningShare() throws {}

  override public func setAddress(address _: String, completion: @escaping (Result<OSStatus>) -> Void) {
    completion(Result(data: OSStatus(1)))
  }

  override public func setSigningShare(signingShare _: String, completion: @escaping (Result<OSStatus>) -> Void) {
    completion(Result(data: OSStatus(1)))
  }

  override public func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    completion(Result(data: OSStatus(1)))
  }
}

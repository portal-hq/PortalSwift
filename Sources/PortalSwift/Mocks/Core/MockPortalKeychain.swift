//
//  MockPortalKeychain.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalKeychain: PortalKeychainProtocol {
  public var metadata: PortalKeychainMetadata?
  public var api: (any PortalApiProtocol)?

  public var legacyAddress: String?

  public func deleteShares() async throws {}

  public func getAddress(_ forChainId: String) async throws -> String? {
    if forChainId.starts(with: "eip155") {
      return MockConstants.mockEip155Address
    } else if forChainId.starts(with: "solana") {
      return MockConstants.mockSolanaAddress
    }

    throw PortalKeychain.KeychainError.unsupportedNamespace(forChainId)
  }

  public func getAddresses() async throws -> [PortalNamespace: String?] {
    return [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress
    ]
  }

  public func getMetadata() async throws -> PortalKeychainClientMetadata {
    return MockConstants.mockKeychainClientMetadata
  }

  public func getShare(_ forChainId: String) async throws -> String {
    if forChainId.starts(with: "eip155") {
      return try MockConstants.mockMpcShareString
    } else if forChainId.starts(with: "solana") {
      return try MockConstants.mockMpcShareString
    }

    throw PortalKeychain.KeychainError.unsupportedNamespace(forChainId)
  }

  var getSharesReturnValue: PortalKeychainClientShares?

  public func getShares() async throws -> PortalKeychainClientShares {
    return try getSharesReturnValue ?? MockConstants.mockGenerateResponse
  }

  public func loadMetadata() async throws -> PortalKeychainMetadata {
    PortalKeychainMetadata(
      namespaces: [:]
    )
  }

  public func setMetadata(_: PortalKeychainClientMetadata) async throws {}

  public func setShares(_: [String: PortalMpcGeneratedShare]) async throws {}

  // Deprecated functions

  public func getAddress() throws -> String {
    return MockConstants.mockEip155Address
  }

  public func getSigningShare() throws -> String {
    return try MockConstants.mockMpcShareString
  }

  public func deleteAddress() throws {}

  public func deleteSigningShare() throws {}

  public func setAddress(address _: String, completion: @escaping (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }

  public func setSigningShare(signingShare _: String, completion: @escaping (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }

  public func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }
}

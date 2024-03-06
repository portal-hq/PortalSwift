//
//  MockPortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalApi: PortalApi {
  public var client: Client?
  public var dapps: [Dapp]?
  public var networks: [ContractNetwork]?

  override public func getClient(completion: @escaping (Result<Client>) -> Void) {
    // Make an instance of Client.
    let client = Client(
      id: "fakeClientID",
      address: mockAddress,
      custodian: Custodian(
        id: "fakeCustodianID",
        name: "name"
      )
    )

    // Call the completion handler.
    completion(Result(data: client))
  }

  override public func getEnabledDapps(completion: @escaping (Result<[Dapp]>) -> Void) {
    if let dapps {
      completion(Result(data: dapps))
    }
  }

  override public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) {
    if let networks {
      completion(Result(data: networks))
    }
  }

  // Mocking the storedClientSigningShare function
  override public func storedClientSigningShare(
    signingSharePairId _: String,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    // Mock response with data
    let mockResponse = Result(data: "Mock signing share response")
    completion(mockResponse)
  }

  // Mocking the storedClientBackupShare function
  override public func storedClientBackupShare(
    success: Bool,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    // Mock response based on the success parameter
    if success {
      completion(Result(data: "Backup share successfully stored"))
    } else {
      completion(Result<String>(error: NSError(domain: "MockError", code: 0, userInfo: nil)))
    }
  }

  // Mocking the storedClientBackupShare function
  override public func storedClientBackupShareKey(
    backupMethod _: String,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    // Mock response based on the success parameter
    let mockResponse = Result(data: "Backup share key successfully stored")
    completion(mockResponse)
  }

  // Mocking the ejectClient function
  override public func ejectClient(completion: @escaping (Result<String>) -> Void) throws {
    // Mock response based on the success parameter
    let mockResponse = Result(data: "")
    completion(mockResponse)
  }

  override public func identify(traits _: [String: Any] = [:], completion: @escaping (Result<MetricsResponse>) -> Void) throws {
    let mockResponse = Result(data: MetricsResponse(status: true))

    completion(mockResponse)
  }

  override public func track(event _: String, properties _: [String: Any], completion: ((Result<MetricsResponse>) -> Void)? = nil) {
    let mockResponse = Result(data: MetricsResponse(status: true))
    guard let completion else {
      return
    }

    completion(mockResponse)
  }
}

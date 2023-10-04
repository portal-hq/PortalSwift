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
    if let dapps = dapps {
      completion(Result(data: dapps))
    }
  }

  override public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) {
    if let networks = networks {
      completion(Result(data: networks))
    }
  }

  // Mocking the storedClientSigningShare function
  override public func storedClientSigningShare(
    recoverSigning _: Bool? = nil,
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
    let mockResponse: Result<String>
    if success {
      mockResponse = Result(data: "Backup share successfully stored")
    } else {
      mockResponse = Result(error: NSError(domain: "MockError", code: 0, userInfo: nil))
    }
    completion(mockResponse)
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
}

//
//  MockPortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalApi: PortalApi {
  public var dapps: [Dapp]?
  public var networks: [ContractNetwork]?

  // Mocking the storedClientBackupShare function
  override public func storedClientBackupShare(
    success: Bool,
    backupMethod _: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    // Mock response based on the success parameter
    if success {
      completion(Result(data: "Backup share successfully stored"))
    } else {
      completion(Result<String>(error: NSError(domain: "MockError", code: 0, userInfo: nil)))
    }
  }

  // Mocking the ejectClient function
  override public func ejectClient(completion: @escaping (Result<String>) -> Void) throws {
    // Mock response based on the success parameter
    let mockResponse = Result(data: "")
    completion(mockResponse)
  }

  override public func track(event _: String, properties _: [String: String], completion: ((Result<MetricsResponse>) -> Void)? = nil) {
    let mockResponse = Result(data: MetricsResponse(status: true))
    guard let completion else {
      return
    }

    completion(mockResponse)
  }
}

public let mockApi = MockPortalApi(apiKey: MockConstants.mockApiKey)

//
//  MockPortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A `PortalApi` whose legacy completion-based endpoints answer canned results.
///
/// It declares no initializers of its own, so it inherits every `PortalApi` initializer:
/// `MockPortalApi(credentials:apiHost:enclaveMPCHost:provider:featureFlags:requests:)` is the
/// form to use, and the deprecated `MockPortalApi(apiKey:…)` keeps compiling for existing hosts.
/// The credentials form is what `mockApi` below is built with, so the mocks share one credential
/// instance the way a real `Portal` shares one across its subsystems.
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

/// The shared mock API, built on `MockConstants.mockCredentials` so it authenticates with
/// `MockConstants.mockApiKey` without going through the deprecated `apiKey` initializer.
public let mockApi = MockPortalApi(credentials: MockConstants.mockCredentials)

//
//  MockICloudStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockICloudStorage: ICloudStorage {
  // Async decrypt implementation
  public func decrypt(_: String, withKey _: String) async throws -> String {
    return try await MockConstants.mockMpcShareString
  }

  // Async delete implementation
  override public func delete() async throws -> Bool {
    return true
  }

  // Async encrypt implementation
  public func encrypt(_: String) async throws -> EncryptData {
    return MockConstants.mockEncryptData
  }

  // Async read implementation
  override public func read() async throws -> String {
    return try MockConstants.mockMpcShareString
  }

  // Async write implementation
  override public func write(_: String) async throws -> Bool {
    return true
  }

  override public func validateOperations() async throws -> Bool {
    return true
  }
}

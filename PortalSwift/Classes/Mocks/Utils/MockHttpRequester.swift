//
//  MockHttpRequester.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockHttpRequester: HttpRequester {
  public func get(
    path: String,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<String>) -> Void
  ) throws -> Void {
    completion(Result(data: mockBackupShare))
  }

  public func post(
    path: String,
    body: Dictionary<String, Any>,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<String>) -> Void
  ) throws -> Void {
    completion(Result(data: mockBackupShare))
  }
}

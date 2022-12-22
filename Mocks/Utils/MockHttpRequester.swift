//
//  MockHttpRequester.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public struct MockHttpRequester {
  var baseUrl: String

  init(baseUrl: String) {
    self.baseUrl = baseUrl
  }

  public func get(
    path: String,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<Any>) -> Void
  ) throws -> Void {
    completion(Result(data: mockBackupShare))
  }

  public func post(
    path: String,
    body: Dictionary<String, Any>,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<Any>) -> Void
  ) throws -> Void {
    completion(Result(data: mockBackupShare))
  }
}

//
//  MockHttpRequest.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockHttpRequest: HttpRequest<String, Any> {
  public override func send(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }
}

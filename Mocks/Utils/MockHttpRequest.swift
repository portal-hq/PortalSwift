//
//  MockHttpRequest.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockHttpRequest: HttpRequest<Any, Any> {
  public override func send(completion: @escaping (Result<Any>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }
}

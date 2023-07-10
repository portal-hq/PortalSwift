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
        path _: String,
        headers _: [String: String],
        completion: @escaping (Result<String>) -> Void
    ) throws {
        completion(Result(data: mockBackupShare))
    }

    public func post(
        path _: String,
        body _: [String: Any],
        headers _: [String: String],
        completion: @escaping (Result<String>) -> Void
    ) throws {
        completion(Result(data: mockBackupShare))
    }
}

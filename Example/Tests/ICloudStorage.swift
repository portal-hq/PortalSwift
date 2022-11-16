//
//  ICloudStorage.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class ICloudStorageTest: XCTestCase {
    var storage: ICloudStorage?

    override func setUpWithError() throws {
        storage = ICloudStorage()
        storage?.api = MockPortalApi(apiKey: "")
    }

    override func tearDownWithError() throws {
        storage = nil
    }

    func testDelete() throws {
        _ = try storage!.write(privateKey: "test")
        XCTAssert(try storage!.delete())
    }

    func testRead() throws {
        _ = try storage!.write(privateKey: "test")
        XCTAssert(try storage!.read() == "test")
    }

    func testWrite() throws {
        XCTAssert(try storage!.write(privateKey: "test") == "test")
    }
}

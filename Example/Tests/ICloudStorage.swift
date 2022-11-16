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
        let privateKey = "privateKey"
        _ = try storage!.write(privateKey: privateKey)
        XCTAssert(try storage!.read() == privateKey)
        _ = try storage!.delete()
        XCTAssert(try storage!.read() == "")
    }

    func testRead() throws {
        XCTAssert(try storage!.read() == "")
    }

    func testWrite() throws {
        let privateKey = "privateKey"
        _ = try storage!.write(privateKey: privateKey)
        XCTAssert(try storage!.read() == privateKey)
    }
}

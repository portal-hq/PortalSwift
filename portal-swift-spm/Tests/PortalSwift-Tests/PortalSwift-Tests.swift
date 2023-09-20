//
//  PortalSwift-Tests.swift
//
//
//  Created by Rami Shahatit on 9/20/23.
//

@testable import PortalSwift
import XCTest

final class PortalSwift_Tests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  func testExample() throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    let backup = BackupOptions(icloud: ICloudStorage())
    let keychain = PortalKeychain()
    let portal = try PortalSwift.Portal(
      apiKey: "bd8c424a-4f25-4992-9292-6b25bea41ffc",
      backup: backup,
      chainId: 5,
      keychain: keychain,
      gatewayConfig: [
        5: "https://eth-goerli.g.alchemy.com/v2/53va-QZAS8TnaBH3-oBHqcNJtIlygLi-",
      ],
      version: "v1",
      autoApprove: true
    )
    portal.createWallet { addressResult in
      guard addressResult.error == nil else {
        print(addressResult.error)
        return
      }
      print(addressResult.data)

    } progress: { status in
      print("Generate Status: ", status)
    }

    XCTAssertEqual(portal.chainId, 5)
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
    }
  }
}

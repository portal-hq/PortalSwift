//
//  PortalMpcTests.swift
//  PortalSwift_Tests
//
//  Created by Rami Shahatit on 11/15/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import XCTest
import PortalSwift

final class PortalMpcTests: XCTestCase {
  var portalMpc: PortalMpc?

    override func setUpWithError() throws {

      portalMpc = PortalMpc(apiKey: "3d68e265-0d88-41a4-bc8b-142191999061", chainId: 2, keychain: PortalKeychain(), storage: BackupOptions(icloud: ICloudStorage()), gatewayUrl: "https://gatewayUrl.com")
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGenerate() throws {
      let address = try portalMpc!.generate()
//      XCTAssert(<#T##expression: Bool##Bool#>)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
  
  func testBackup() throws {
    portalMpc?.backup(method: BackupMethods.iCloud.rawValue)  {
      (result: Result<String>) -> Void in
      print(result.data)
      print(result.error)
    }

  }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

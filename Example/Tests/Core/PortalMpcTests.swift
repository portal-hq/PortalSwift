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
      //3d68e265-0d88-41a4-bc8b-142191999061
      
      portalMpc = PortalMpc(apiKey: "4d9f0c9e-fd45-45c1-b549-5495da2f5b71", chainId: 2, keychain: PortalKeychain(), storage: BackupOptions(icloud: ICloudStorage()), gatewayUrl: "https://gatewayUrl.com")
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
  
  func testBackupAndRecover() throws {
    portalMpc!.backup(method: BackupMethods.iCloud.rawValue) {
      (result: Result<String>) -> Void in
      print("Data: ", result.data)
      print("Error: ", result.error)
      portalMpc!.recover(cipherText: result.data!, method: BackupMethods.iCloud.rawValue) {
        (result: Result<String>) -> Void in
        print("Data: in recover", result.data)
        print("Error: in recover ", result.error)
      }
    }

  }
  
  func testRecover() throws {
    
  }
  
  func testSign() throws {
   var sig = try portalMpc!.sign(method: "eth_sign", params: "[\"0xaeabe5b13828f691fdb56007502ef9035c95e8b2\", \"0x57656c636f6d6520746f204f70656e536561210a0a436c69636b20746f207369676e20696e20616e642061636365707420746865204f70656e536561205465726d73206f6620536572766963653a2068747470733a2f2f6f70656e7365612e696f2f746f730a0a5468697320726571756573742077696c6c206e6f742074726967676572206120626c6f636b636861696e207472616e73616374696f6e206f7220636f737420616e792067617320666565732e0a0a596f75722061757468656e7469636174696f6e207374617475732077696c6c20726573657420616674657220323420686f7572732e0a0a57616c6c657420616464726573733a0a3078616561626535623133383238663639316664623536303037353032656639303335633935653862320a0a4e6f6e63653a0a37623563643832302d653433322d343934322d386434352d663561666563343135663262\"]")
    
    XCTAssert(type(of: sig.R) == String.Type.self && type(of: sig.S) == String.Type.self, "Signature doesnt match R and S values")
  }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

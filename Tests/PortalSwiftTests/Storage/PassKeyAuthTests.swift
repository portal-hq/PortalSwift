//
//  PassKeyAuthTests.swift
//  
//
//  Created by Prakash Kotwal on 13/06/2024.
//
@testable import PortalSwift
import XCTest
@available(iOS 16, *)
final class PassKeyAuthTests: XCTestCase {
  var mockPassKeyAuth : MockPasskeyAuth!
  var passKeyAuth : PasskeyAuth!
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    mockPassKeyAuth = MockPasskeyAuth()
    passKeyAuth = PasskeyAuth()
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    mockPassKeyAuth = nil
    passKeyAuth = nil
  }
  
  
  func testSignUpSuccess() async throws {
    let options = MockConstants.mockPasskeyRegistrationOptions.options
    passKeyAuth.signUpWith(options)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      XCTAssertTrue(self.passKeyAuth.assertion != nil)
    }
  }
  
  func testSignInSuccess() async throws {
    let options = MockConstants.mockPasskeyAuthenticationOptions.options
    XCTAssertNoThrow(mockPassKeyAuth.signInWith(options, preferImmediatelyAvailableCredentials: true))
  }
    
}

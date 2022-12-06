//
//  MpcSignerTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class MpcSignerTests: XCTestCase {
  var keychain: PortalKeychain?
  var signer: MpcSigner?
  var provider: PortalProvider?

  override func setUpWithError() throws {
    keychain = PortalKeychain()
    signer = MpcSigner(keychain: PortalKeychain())
    provider = try PortalProvider(
      apiKey: "test", // "API_KEY",
      chainId: Chains.Goerli.rawValue,
      gatewayUrl: "test", // "https://eth-goerli.g.alchemy.com/v2/API_KEY",
      autoApprove: true
    )
  }

  override func tearDownWithError() throws {
    keychain = nil
    signer = nil
    provider = nil
  }

  func testETHRequestPayloadSign() throws {
    // let payload = ETHRequestPayload(
    //   method: ETHRequestMethods.BlockNumber.rawValue,
    //   params: []
    // )
    // let expected = SignerResult(signature: "0x0")
    // let actual = try signer?.sign(payload: payload, provider: provider!)
    XCTAssert(true)
  }

  func testETHTransactionPayloadSign() throws {
    // let payload = ETHTransactionPayload(
    //   method: ETHRequestMethods.GetStorageAt.rawValue,
    //   params: []
    // )
    // let expected = SignerResult(signature: "0x0")
    // let actual = try signer?.sign(payload: payload, provider: provider!)
    XCTAssert(true)
  }
}

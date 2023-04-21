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
    do {
      keychain = MockPortalKeychain()
      keychain!.setSigningShare(signingShare: mockSigningShare) { result in }
      signer = MpcSigner(keychain: keychain!)
      provider = try MockPortalProvider(
        apiKey: "API_KEY",
        chainId: Chains.Goerli.rawValue,
        gatewayUrl: "https://eth-goerli.g.alchemy.com/v2/API_KEY",
        autoApprove: true
      )
    } catch {
      throw error
    }
  }

  override func tearDownWithError() throws {
    keychain = nil
    signer = nil
    provider = nil
  }

  func testETHRequestPayloadSign() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Accounts.rawValue,
      params: []
    )

    let result: SignerResult = try signer?.sign(payload: payload, provider: provider!) as! SignerResult
    let accounts = result.accounts
    XCTAssert(accounts?.first == mockAddress)
  }

  func testETHTransactionPayloadSign() throws {
    let fakeTransaction = ETHTransactionParam(
      from: mockAddress,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      gas: "0x76c0",
      gasPrice: "0x9184e72a000",
      value: "0x9184e72a",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [fakeTransaction]
    )

    let result = try signer?.sign(payload: payload, provider: provider!, mockClientSign: true)
    XCTAssert(result?.signature == mockSignature)
  }
}

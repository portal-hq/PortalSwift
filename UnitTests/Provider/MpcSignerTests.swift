//
//  MpcSignerTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class MpcSignerTests: XCTestCase {
  var keychain: PortalKeychain?
  var signer: MpcSigner?
  var provider: PortalProvider?

  override func setUpWithError() throws {
    do {
      self.keychain = MockPortalKeychain()
      self.keychain!.setSigningShare(signingShare: mockSigningShare) { _ in }
      self.signer = MpcSigner(apiKey: "API_KEY", keychain: self.keychain!)
      self.provider = try MockPortalProvider(
        apiKey: "API_KEY",
        chainId: Chains.Goerli.rawValue,
        gatewayConfig: [Chains.Goerli.rawValue: "https://eth-goerli.g.alchemy.com/v2/API_KEY"],
        keychain: MockPortalKeychain(),
        autoApprove: true
      )
    } catch {
      throw error
    }
  }

  override func tearDownWithError() throws {
    self.keychain = nil
    self.signer = nil
    self.provider = nil
  }

  func testETHRequestPayloadSign() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Accounts.rawValue,
      params: []
    )

    let result: SignerResult = try signer?.sign(payload: payload, provider: self.provider!) as! SignerResult
    let accounts = result.accounts
    XCTAssert(accounts?.first == mockAddress)
  }

  func testETHTransactionPayloadSign() throws {
    throw XCTSkip("Test is not implemented yet")
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

    let result = try signer?.sign(payload: payload, provider: self.provider!, mockClientSign: true)
    XCTAssert(result?.signature == mockSignature)
  }
}

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
  var keychain: PortalKeychain!
  var signer: MpcSigner!
  var provider: PortalProvider!

  override func setUpWithError() throws {
    self.keychain = MockPortalKeychain()
    self.keychain.setSigningShare(signingShare: mockSigningShare) { _ in }
    self.signer = MpcSigner(apiKey: mockApiKey, keychain: self.keychain, binary: MockMobileWrapper())
    self.provider = try PortalProvider(
      apiKey: mockApiKey,
      chainId: 5,
      gatewayConfig: [5: mockHost],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      gateway: MockHttpRequester(baseUrl: mockHost)
    )
  }

  override func tearDownWithError() throws {
    self.keychain = nil
    self.signer = nil
    self.provider = nil
  }

  func testEthRequestAccounts() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.RequestAccounts.rawValue,
      params: []
    )

    let result: SignerResult = try signer.sign(payload: payload, provider: self.provider!)
    let accounts = result.accounts
    XCTAssert(accounts?.first == mockAddress)
  }

  func testEthAccounts() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Accounts.rawValue,
      params: []
    )

    let result: SignerResult = try signer.sign(payload: payload, provider: self.provider!)
    let accounts = result.accounts
    XCTAssert(accounts?.first == mockAddress)
  }

  func testEthSendTransactionNoGas() throws {
    let fakeTransaction = ETHTransactionParam(
      from: mockAddress,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      value: "0x9184e72a",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [fakeTransaction]
    )

    let result = try signer.sign(payload: payload, provider: self.provider)
    XCTAssert(result.signature == mockSignature)
  }

  func testEthSendTransactionWithGas() throws {
    let fakeTransaction = ETHTransactionParam(
      from: mockAddress,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      gas: "0x9184e72a",
      gasPrice: "0x76c0",
      value: "0x9184e72a000",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [fakeTransaction]
    )

    let result = try signer.sign(payload: payload, provider: self.provider)
    XCTAssert(result.signature == mockSignature)
  }

  func testEthSignWithParams() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Sign.rawValue, params: [mockAddress, "0xdeadbeaf"]
    )

    let result = try signer.sign(payload: payload, provider: self.provider)
    XCTAssert(result.signature == mockSignature)
  }

  func testEthSignWithNoParams() throws {
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Sign.rawValue, params: []
    )

    XCTAssertThrowsError(try self.signer.sign(payload: payload, provider: self.provider))
  }

  func testEthSendTransactionWithNoParams() throws {
    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: []
    )
    XCTAssertThrowsError(try self.signer.sign(payload: payload, provider: self.provider))
  }

  func testEthSignWithParamsError() throws {
    // Override the signer with a instance of the binary that returns an error object.
    self.signer = MpcSigner(apiKey: mockApiKey, keychain: self.keychain, binary: MockMobileErrorWrapper())

    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Sign.rawValue, params: [mockAddress, "0xdeadbeaf"]
    )

    XCTAssertThrowsError(try self.signer.sign(payload: payload, provider: self.provider))
  }

  func testEthSendTransactionWithGasError() throws {
    // Override the signer with a instance of the binary that returns an error object.
    self.signer = MpcSigner(apiKey: mockApiKey, keychain: self.keychain, binary: MockMobileErrorWrapper())

    let fakeTransaction = ETHTransactionParam(
      from: mockAddress,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      gas: "0x9184e72a",
      gasPrice: "0x76c0",
      value: "0x9184e72a000",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    let payload = ETHTransactionPayload(
      method: ETHRequestMethods.SendTransaction.rawValue,
      params: [fakeTransaction]
    )

    XCTAssertThrowsError(try self.signer.sign(payload: payload, provider: self.provider))
  }
}

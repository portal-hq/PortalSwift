//
//  PortalProviderTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalProviderTests: XCTestCase {
  var provider: PortalProvider!

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.provider = try PortalProvider(
      apiKey: mockApiKey,
      chainId: 11_155_111,
      gatewayConfig: [11_155_111: mockHost],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      gateway: MockHttpRequester(baseUrl: mockHost)
    )
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.provider = nil
  }

  func testEmit() throws {
    let expectation = XCTestExpectation(description: "testEmit")
    var timesCalled = 0

    // Listen for the event.
    let _ = self.provider!.on(event: "test", callback: { data in
      print("data", data)
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    })

    // Emit 3 times.
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetApiKey() throws {
    let apiKey = self.provider!.apiKey
    XCTAssertEqual(apiKey, mockApiKey)
  }

  func testOn() throws {
    let expectation = XCTestExpectation(description: "testEmit")
    var timesCalled = 0

    // Listen for the event.
    let _ = self.provider!.on(event: "test", callback: { data in
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    })

    // Emit 3 times.
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    wait(for: [expectation], timeout: 5.0)
  }

  func testOnce() throws {
    let expectation = XCTestExpectation(description: "testEmit")

    let _ = self.provider!.once(event: "test", callback: { data in
      XCTAssertEqual(data as! String, "test")
      expectation.fulfill()
    })

    let _ = self.provider!.emit(event: "test", data: "test")
    wait(for: [expectation], timeout: 5.0)
  }

  func testRemoveListener() throws {
    let expectation = XCTestExpectation(description: "testEmit")

    // Listen for the event.
    let _ = self.provider!.on(event: "test-remove", callback: { _ in
      // Expect not to be called.
      XCTFail()
    })

    // Remove the listener.
    let _ = self.provider!.removeListener(event: "test-remove")

    // Emit the event.
    let _ = self.provider!.emit(event: "test-remove", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      expectation.fulfill()
    }
  }

  // ** Gateway Requests ** //
  func testEthEstimateGas() {
    let expectation = XCTestExpectation(description: "Expecting valid estimate of gas")

    self.performRequest(method: ETHRequestMethods.EstimateGas.rawValue, params: [mockTransaction, "latest"]) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Call result should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Call result should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthBlockNumber() {
    let expectation = XCTestExpectation(description: "Expecting valid block number response")

    self.performRequest(method: ETHRequestMethods.BlockNumber.rawValue, params: []) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Block number should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Block number should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGasPrice() {
    let expectation = XCTestExpectation(description: "Expecting valid gas price response")

    self.performRequest(method: ETHRequestMethods.GasPrice.rawValue, params: []) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Gas price should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Gas price should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  // https://docs.alchemy.com/reference/eth-call
  func testEthCall() {
    let expectation = XCTestExpectation(description: "Expecting valid call response")

    self.performRequest(method: ETHRequestMethods.Call.rawValue, params: [mockTransaction, "latest"]) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Call result should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Call result should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  // Add a check to determine if the balance is the exact eth value we expect to have
  func testEthGetBalance() {
    let expectation = XCTestExpectation(description: "Expecting valid balance response")

    self.performRequest(method: ETHRequestMethods.GetBalance.rawValue, params: [mockAddress, "latest"]) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Balance should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Balance should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetCode() {
    let expectation = XCTestExpectation(description: "Expecting valid code response")

    self.performRequest(method: ETHRequestMethods.GetCode.rawValue, params: [mockAddress, "latest"]) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hexValue.isEmpty, "Code should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Code should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetTransactionCount() {
    let expectation = XCTestExpectation(description: "Expecting valid transaction count response")

    self.performRequest(method: ETHRequestMethods.GetTransactionCount.rawValue, params: [mockAddress, "latest"]) { result in
      guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      print("Gateway response for eth_getTransactionCount \(String(describing: hexValue))")
      XCTAssert(!hexValue.isEmpty, "Transaction count should not be empty")
      XCTAssert(hexValue.starts(with: "0x"), "Transaction count should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetUncleCountByBlockNumber() {
    let expectation = XCTestExpectation(description: "Expecting valid uncle count by block number response")

    self.performRequest(method: ETHRequestMethods.GetUncleCountByBlockNumber.rawValue, params: ["latest"]) { result in
      guard result.error == nil, let count = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!count.isEmpty, "Uncle count by block number should not be empty")
      XCTAssert(count.starts(with: "0x"), "Uncle count should be a hexadecimal")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNetVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid net version response (chain id)")

    self.performRequest(method: ETHRequestMethods.NetVersion.rawValue, params: []) { result in
      guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!version.isEmpty, "Net version (chain id) should not be empty")
      XCTAssert(version == "11155111", "Net version (chain id) should be 11155111 for Sepolia")

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNewBlockFilter() {
    let expectation = XCTestExpectation(description: "Expecting valid new block filter response")

    self.performRequest(method: ETHRequestMethods.GetNewBlockFilter.rawValue, params: []) { result in
      guard result.error == nil, let filter = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!filter.isEmpty, "New block filter should not be empty")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNewPendingTransactionFilter() {
    let expectation = XCTestExpectation(description: "Expecting valid new pending transaction filter response")

    self.performRequest(method: ETHRequestMethods.NewPendingTransactionFilter.rawValue, params: []) { result in
      guard result.error == nil, let filter = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!filter.isEmpty, "New pending transaction filter should not be empty")
      XCTAssert(filter.starts(with: "0x"), "New pending transaction filter should return a hexadecimal tx hash")

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthProtocolVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid protocol version response")

    self.performRequest(method: ETHRequestMethods.ProtocolVersion.rawValue, params: []) { result in
      guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!version.isEmpty, "Protocol version should not be empty")
      XCTAssert(version.starts(with: "0x"), "Protocl version should return a hexadecimal")

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthWeb3ClientVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid Web3 client version response")

    self.performRequest(method: ETHRequestMethods.Web3ClientVersion.rawValue, params: []) { result in
      guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!version.isEmpty, "Web3 client version should not be empty")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthWeb3Sha3() {
    let expectation = XCTestExpectation(description: "Expecting valid Web3 Sha3 response")

    self.performRequest(method: ETHRequestMethods.Web3Sha3.rawValue, params: ["0x68656c6c6f20776f726c64"]) { result in
      guard result.error == nil, let hash = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!hash.isEmpty, "Web3 sha3 should not be empty")
      XCTAssert(hash == "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad", "should return the sha3 result of 0x68656c6c6f20776f726c64")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetStorageAt() {
    let expectation = XCTestExpectation(description: "Expecting valid get storage response")

    self.performRequest(method: ETHRequestMethods.GetStorageAt.rawValue, params: [mockAddress, "0x0", "latest"]) { result in
      guard result.error == nil, let storage = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!storage.isEmpty, "Get storage at should not be empty")
      XCTAssert(storage == "0x0000000000000000000000000000000000000000000000000000000000000000", "Storage should return hex O")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthChainId() {
    let expectation = XCTestExpectation(description: "Expecting valid chainId")

    self.performRequest(method: ETHRequestMethods.ChainId.rawValue, params: []) { result in
      guard result.error == nil, let chainId = (result.data?.result as? ETHGatewayResponse)?.result else {
        XCTFail("Error testing provider request: \(String(describing: result.error))")
        return expectation.fulfill()
      }

      XCTAssert(!chainId.isEmpty, "ChainId at should not be empty")
      XCTAssert(chainId == "0x5", "ChainId should return chainId 0x5")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30)
  }

  func testSetChainId() throws {
    let _ = try provider!.setChainId(value: 5)
    XCTAssertEqual(self.provider!.chainId, 5)
  }

  func performRequest(method: String, params: [Any], completion: @escaping (Result<RequestCompletionResult>) -> Void) {
    let payload = ETHRequestPayload(method: method, params: params)

    self.provider.request(payload: payload) { result in
      completion(result)
    }
  }
}

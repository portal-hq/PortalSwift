//
//  ProviderTests.swift
//  PortalSwift_Tests
//
//  Created by Rami Shahatit on 8/7/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//
import PortalSwift
@testable import PortalSwift_Example
import XCTest

final class ProviderTests: XCTestCase {
  static var user: UserResult?
  static var username: String?
  static var PortalWrap: PortalWrapper!

  static func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let randomPart = String((0 ..< length).map { _ in letters.randomElement()! })
    let timestamp = String(Int(Date().timeIntervalSince1970))
    return randomPart + timestamp
  }

  override class func setUp() {
    super.setUp()
    self.username = self.randomString(length: 15)
    print("username: ", self.username!)
    self.PortalWrap = PortalWrapper()
  }

  // This test is a setup function. We only want it to run once.
  // After this runs each test function will only need to login.
  // This function:
  // - Signs up a user with PortalEx
  // - Generates a wallet
  // - Transfers .01 eth from PortalEx omnibus wallet
  func testARegister() {
    let expectation = XCTestExpectation(description: "Complete registration, generation, and funding")

    ProviderTests.PortalWrap.signUp(username: ProviderTests.username!) { result in
      guard let userResult = self.handleSignUp(result: result) else {
        XCTFail("Failed on sign up")
        return expectation.fulfill()
      }

      self.registerPortal(userResult: userResult) { success in
        guard success else {
          XCTFail("Failed on registering portal")
          return expectation.fulfill()
        }
        self.generateAndTransferFunds(userResult: userResult) { success in
          guard success else {
            XCTFail("Failed on generate and transfer")
            return expectation.fulfill()
          }
          XCTAssert(success, "Generate and transfer should complete successfully")
          return expectation.fulfill()
        }
      }
    }
    wait(for: [expectation], timeout: 260)
  }

  // This function waits for the wallet to be funded with eth for 200 seconds before moving on to the rest of the tests.
  func testBalanceGreaterThanZero() {
    let expectation = XCTestExpectation(description: "Wait for balance to be greater than 0")

    self.testLogin { success in
      guard success else {
        expectation.fulfill()
        return XCTFail("Failed on login")
      }

      // Runs getBalanceWithRetries in background thread so main thread can accept network requests
      DispatchQueue.global().async {
        self.getBalanceWithRetries(tryCount: 1) { result in
          guard result.error == nil else {
            XCTFail("Failed getting balance")
            expectation.fulfill()
            return
          }
          XCTAssert(result.data! > 0, "Ether balance is greater than 0")
          expectation.fulfill()
        }
      }
    }

    wait(for: [expectation], timeout: 60.0)
  }

  // ** Transaction Gateway Requests ** //
  func testZEthSendTransaction() {
    let expectation = XCTestExpectation(description: "Expecting to send eth")

    self.testLogin { success in
      guard success, let address = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      guard let portal = ProviderTests.PortalWrap.portal else {
        XCTFail("Failed to register portal object.")
        return
      }

      self.sendTransaction(using: portal, with: address, completion: expectation.fulfill)
    }

    wait(for: [expectation], timeout: 30)
  }

  func testZEthSignTransaction() {
    let expectation = XCTestExpectation(description: "Expecting to sign a transaction")

    self.testLogin { success in
      guard success, let address = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      guard let portal = ProviderTests.PortalWrap.portal else {
        XCTFail("Failed to register portal object.")
        return
      }

      self.signTransaction(using: portal, with: address, completion: expectation.fulfill)
    }

    wait(for: [expectation], timeout: 30)
  }

  func testZEthGetBlockTransactionCountByNumber() {
    let expectation = XCTestExpectation(description: "Expecting valid transaction count response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetBlockTransactionCountByNumber.rawValue, params: ["latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getBlockTransactionCountByNumber \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Transaction count should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Transaction count should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // ** Gateway Requests ** //
  func testEthEstimateGas() {
    let expectation = XCTestExpectation(description: "Expecting valid estimate of gas")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      let callData = [
        "from": fromAddress,
        "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
        "value": "0x9184e72a",
        "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
      ]

      self.performRequest(method: ETHRequestMethods.EstimateGas.rawValue, params: [callData, "latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_call \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Call result should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Call result should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthBlockNumber() {
    let expectation = XCTestExpectation(description: "Expecting valid block number response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.BlockNumber.rawValue, params: []) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_blockNumber \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Block number should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Block number should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGasPrice() {
    let expectation = XCTestExpectation(description: "Expecting valid gas price response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GasPrice.rawValue, params: []) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_gasPrice \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Gas price should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Gas price should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // https://docs.alchemy.com/reference/eth-call
  func testEthCall() {
    let expectation = XCTestExpectation(description: "Expecting valid call response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      let callData = [
        "from": fromAddress,
        "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
        "value": "0x9184e72a",
        "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
      ]

      self.performRequest(method: ETHRequestMethods.Call.rawValue, params: [callData, "latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_call \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Call result should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Call result should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // Add a check to determine if the balance is the exact eth value we expect to have
  func testEthGetBalance() {
    let expectation = XCTestExpectation(description: "Expecting valid balance response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetBalance.rawValue, params: [fromAddress, "latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getBalance \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Balance should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Balance should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetCode() {
    let expectation = XCTestExpectation(description: "Expecting valid code response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetCode.rawValue, params: [fromAddress, "latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getCode \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Code should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Code should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetTransactionCount() {
    let expectation = XCTestExpectation(description: "Expecting valid transaction count response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetTransactionCount.rawValue, params: [fromAddress, "latest"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getTransactionCount \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Transaction count should not be empty")
        XCTAssert(hexValue.starts(with: "0x"), "Transaction count should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetUncleCountByBlockNumber() {
    let expectation = XCTestExpectation(description: "Expecting valid uncle count by block number response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetUncleCountByBlockNumber.rawValue, params: ["latest"]) { result in
        guard result.error == nil, let count = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getUncleCountByBlockNumber \(String(describing: count))")
        XCTAssert(!count.isEmpty, "Uncle count by block number should not be empty")
        XCTAssert(count.starts(with: "0x"), "Uncle count should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNetVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid net version response (chain id)")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.NetVersion.rawValue, params: []) { result in
        guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_netVersion \(String(describing: version))")
        XCTAssert(!version.isEmpty, "Net version (chain id) should not be empty")
        XCTAssert(version == "5", "Net version (chain id) should be empty 5 for goerli")

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNewBlockFilter() {
    let expectation = XCTestExpectation(description: "Expecting valid new block filter response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.NewBlockFilter.rawValue, params: []) { result in
        guard result.error == nil, let filter = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_newBlockFilter \(String(describing: filter))")
        XCTAssert(!filter.isEmpty, "New block filter should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthNewPendingTransactionFilter() {
    let expectation = XCTestExpectation(description: "Expecting valid new pending transaction filter response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.NewPendingTransactionFilter.rawValue, params: []) { result in
        guard result.error == nil, let filter = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_newPendingTransactionFilter \(String(describing: filter))")
        XCTAssert(!filter.isEmpty, "New pending transaction filter should not be empty")
        XCTAssert(filter.starts(with: "0x"), "New pending transaction filter should return a hexadecimal tx hash")

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthProtocolVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid protocol version response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.ProtocolVersion.rawValue, params: []) { result in
        guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_protocolVersion \(String(describing: version))")
        XCTAssert(!version.isEmpty, "Protocol version should not be empty")
        XCTAssert(version.starts(with: "0x"), "Protocl version should return a hexadecimal")

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthWeb3ClientVersion() {
    let expectation = XCTestExpectation(description: "Expecting valid Web3 client version response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.Web3ClientVersion.rawValue, params: []) { result in
        guard result.error == nil, let version = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for web3_clientVersion \(String(describing: version))")
        XCTAssert(!version.isEmpty, "Web3 client version should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthWeb3Sha3() {
    let expectation = XCTestExpectation(description: "Expecting valid Web3 Sha3 response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.Web3Sha3.rawValue, params: ["0x68656c6c6f20776f726c64"]) { result in
        guard result.error == nil, let hash = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for web3_sha3 \(String(describing: hash))")
        XCTAssert(!hash.isEmpty, "Web3 sha3 should not be empty")
        XCTAssert(hash == "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad", "should return the sha3 result of 0x68656c6c6f20776f726c64")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetStorageAt() {
    let expectation = XCTestExpectation(description: "Expecting valid get storage response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetStorageAt.rawValue, params: [fromAddress, "0x0", "latest"]) { result in
        guard result.error == nil, let storage = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getStorageAt \(String(describing: storage))")
        XCTAssert(!storage.isEmpty, "Get storage at should not be empty")
        XCTAssert(storage == "0x0000000000000000000000000000000000000000000000000000000000000000", "Storage should return hex O")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthRequestAccounts() {
    let expectation = XCTestExpectation(description: "Expecting valid eth_requestAccounts response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.RequestAccounts.rawValue, params: []) { result in

        guard (result.data!.result as! Result<SignerResult>).error == nil, let accounts = (result.data!.result as! Result<SignerResult>).data!.accounts else {
          XCTFail("Error testing provider request: \(String(describing: (result.data!.result as! Result<SignerResult>).error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_requestAccounts \(String(describing: accounts))")
        XCTAssert(!accounts.isEmpty, "Request accounts should not be empty")
        XCTAssert(accounts[0] == fromAddress, "eth_requestAccounts should return the address of the wallet")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthAccounts() {
    let expectation = XCTestExpectation(description: "Expecting valid accounts response")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.Accounts.rawValue, params: []) { result in

        guard (result.data!.result as! Result<SignerResult>).error == nil, let accounts = (result.data!.result as! Result<SignerResult>).data!.accounts else {
          XCTFail("Error testing provider request: \(String(describing: (result.data!.result as! Result<SignerResult>).error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_accounts \(String(describing: accounts))")
        XCTAssert(!accounts.isEmpty, "Accounts should not be empty")
        XCTAssert(accounts[0] == fromAddress, "eth_accounts should return the address of the wallet")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // ** Signer Methods ** //
  func testEthSign() {
    let expectation = XCTestExpectation(description: "Expecting valid signature from eth sign")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.Sign.rawValue, params: [fromAddress, "0xdeadbeaf"]) { result in

        guard (result.data!.result as! Result<SignerResult>).error == nil, let signature = (result.data!.result as! Result<SignerResult>).data!.signature else {
          XCTFail("Error testing provider request: \(String(describing: (result.data!.result as! Result<SignerResult>).error))")
          return expectation.fulfill()
        }

        print("MPC Signer response for eth_sign \(String(describing: signature))")
        XCTAssert(!signature.isEmpty, "eth_sign should not be empty")
        XCTAssert(signature.starts(with: "0x"), "eth_sign should return a signature in hexademical")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthPersonalSign() {
    let expectation = XCTestExpectation(description: "Expecting valid signature from personal_sign")

    self.testLogin { success in
      guard success, let fromAddress = ProviderTests.PortalWrap.portal?.address else {
        XCTFail("Failed on login or address is nil")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.PersonalSign.rawValue, params: ["0xdeadbeaf", fromAddress]) { result in

        guard (result.data!.result as! Result<SignerResult>).error == nil, let signature = (result.data!.result as! Result<SignerResult>).data!.signature else {
          XCTFail("Error testing provider request: \(String(describing: (result.data!.result as! Result<SignerResult>).error))")
          return expectation.fulfill()
        }

        print("MPC Signer response for personal_sign \(String(describing: signature))")
        XCTAssert(!signature.isEmpty, "personal_sign should not be empty")
        XCTAssert(signature.starts(with: "0x"), "personal_sign should return a signature in hexademical")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthChainId() {
    let expectation = XCTestExpectation(description: "Expecting valid chainId")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.ChainId.rawValue, params: []) { result in
        guard result.error == nil, let chainId = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_chainId \(String(describing: chainId))")
        XCTAssert(!chainId.isEmpty, "ChainId at should not be empty")
        XCTAssert(chainId == "0x5", "ChainId should return chainId 0x5")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // ** UNSUPPORTED METHODS, BECAUSE THEY RETURN OBJECTS NOT STRINGS ** //

  // This method should be returning a string but it is returning nil from the provider
  func testEthGetUncleCountByBlockHash() {
    let expectation = XCTestExpectation(description: "Expecting valid uncle count by block hash response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetUncleCountByBlockHash.rawValue, params: ["0xe76d777791f48b5995d20789183514f4aa8bbf09e357383e9a44fae025c6c50a"]) { result in
        guard result.error == nil, let count = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getUncleCountByBlockHash \(String(describing: count))")
        XCTAssert(!count.isEmpty, "Uncle count by block hash should not be empty")
        XCTAssert(count.starts(with: "0x"), "Uncle count should be a hexadecimal")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  //  https://docs.alchemy.com/reference/eth-getblockbyhash
  func testEthGetBlockByHash() {
    let expectation = XCTestExpectation(description: "Expecting valid block by hash response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      let hash = "0x92fc42b9642023f2ee2e88094df80ce87e15d91afa812fef383e6e5cd96e2ed3"
      self.performRequest(method: ETHRequestMethods.GetBlockByHash.rawValue, params: [hash, false]) { result in
        guard result.error == nil, let response = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getBlockByHash \(String(describing: response))")
        // Additional assertions based on expected response
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetTransactionByHash() {
    let expectation = XCTestExpectation(description: "Expecting valid transaction by hash response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetTransactionByHash.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"]) { result in
        guard result.error == nil, let hexValue = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getTransactionByHash \(String(describing: hexValue))")
        XCTAssert(!hexValue.isEmpty, "Transaction by hash should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testEthGetTransactionReceipt() {
    let expectation = XCTestExpectation(description: "Expecting valid transaction receipt response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetTransactionReceipt.rawValue, params: ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"]) { result in
        guard result.error == nil, let receipt = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getTransactionReceipt \(String(describing: receipt))")
        XCTAssert(!receipt.isEmpty, "Transaction receipt should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // https://docs.alchemy.com/reference/eth-getunclebyblockhashandindex
  func testEthGetUncleByBlockHashIndex() {
    let expectation = XCTestExpectation(description: "Expecting valid uncle by block hash index response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.GetUncleByBlockHashIndex.rawValue, params: ["0xc6ef2fc5426d6ad6fd9e2a26abeab0aa2411b7ab17f30a99d3cb96aed1d1055b", "0x0"]) { result in
        guard result.error == nil, let uncle = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_getUncleByBlockHashIndex \(String(describing: uncle))")
        XCTAssert(!uncle.isEmpty, "Uncle by block hash index should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  func testZEthSendRawTransaction() {
    let expectation = XCTestExpectation(description: "Expecting valid send raw transaction response")

    self.testLogin { success in
      guard success else {
        XCTFail("Failed on login")
        return expectation.fulfill()
      }

      self.performRequest(method: ETHRequestMethods.SendRawTransaction.rawValue, params: ["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"]) { result in
        guard result.error == nil, let transaction = (result.data?.result as? ETHGatewayResponse)?.result else {
          XCTFail("Error testing provider request: \(String(describing: result.error))")
          return expectation.fulfill()
        }

        print("Gateway response for eth_sendRawTransaction \(String(describing: transaction))")
        XCTAssert(!transaction.isEmpty, "Send raw transaction should not be empty")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30)
  }

  // ** Helper Methods ** //

  enum ProviderTestErrors: Error {
    case ErrorGettingBalance
    case MaxRetriesForGetBalanceReached
    case portalObjectNil
  }

  func testLogin(completion: @escaping (Bool) -> Void) {
    return XCTContext.runActivity(named: "Login") { _ in
      let registerExpectation = XCTestExpectation(description: "Register")

      ProviderTests.PortalWrap?.signIn(username: ProviderTests.username!) { (result: Result<UserResult>) in
        guard result.error == nil else {
          XCTFail("Failed on sign In: \(result.error!)")
          return registerExpectation.fulfill()
        }
        let userResult = result.data!
        print("✅ handleSignIn(): API key:", userResult.clientApiKey)

        self.registerPortal(userResult: userResult) { success in
          guard success else {
            XCTFail("Failed on registering portal: \(result.error!)")
            return registerExpectation.fulfill()
          }

          registerExpectation.fulfill()
          return completion(success)
        }
      }
      wait(for: [registerExpectation], timeout: 60)
    }
  }

  func handleSignUp(result: Result<UserResult>) -> UserResult? {
    guard result.error == nil, let userResult = result.data else {
      XCTFail("Failed on sign up: \(result.error!)")
      return nil
    }
    ProviderTests.user = userResult
    return userResult
  }

  func registerPortal(userResult: UserResult, completion: @escaping (Bool) -> Void) {
    let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP_TEST")
    let backup = BackupOptions(local: backupOption)
    print("registering portal")

    ProviderTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup) { result in
      guard result.error == nil else {
        XCTFail("Unable to register Portal")
        completion(false)
        return
      }
      return completion(true)
    }
  }

  func generateAndTransferFunds(userResult: UserResult, completion: @escaping (Bool) -> Void) {
    ProviderTests.PortalWrap.generate { result in
      guard result.error == nil, let address = result.data else {
        XCTFail("Failed on generate")
        return completion(false)
      }
      XCTAssertTrue(!address.isEmpty, "The address should not be empty")
      let goerliChain = 5

      ProviderTests.PortalWrap.transferFunds(user: userResult, amount: 0.01, chainId: goerliChain, address: address) { fundResult in
        guard fundResult.error == nil else {
          XCTFail("Could not fund wallet with test eth")
          return completion(false)
        }
        print("Fund result \(String(describing: fundResult.data))")
        return completion(true)
      }
    }
  }

  func getBalanceWithRetries(tryCount: Int, completion: @escaping (Result<Decimal>) -> Void) {
    ProviderTests.PortalWrap.portal?.ethGetBalance { balanceResult in
      guard balanceResult.error == nil else {
        XCTFail("Could not check balance")
        completion(Result(error: ProviderTestErrors.ErrorGettingBalance))
        return
      }

      let hexBalance = (balanceResult.data!.result as! ETHGatewayResponse).result!
      let balanceHexWithoutPrefix = String(hexBalance.dropFirst(2))

      if let weiValue = UInt64(balanceHexWithoutPrefix, radix: 16), weiValue > 0 {
        let wei = Decimal(weiValue)
        let ether = wei / 1_000_000_000_000_000_000
        print("ether balance: \(ether)")

        completion(Result(data: ether))
        return
      } else {
        print("Wei value is 0. Rechecking balance...")
        if tryCount <= 20 {
          let newTryCount = tryCount + 1
          sleep(10)
          self.getBalanceWithRetries(tryCount: newTryCount, completion: completion)
          return
        } else {
          return completion(Result(error: ProviderTestErrors.MaxRetriesForGetBalanceReached))
        }
      }
    }
  }

  func performRequest(method: String, params: [Any], completion: @escaping (Result<RequestCompletionResult>) -> Void) {
    guard let portal = ProviderTests.PortalWrap.portal else {
      return completion(Result(error: ProviderTestErrors.portalObjectNil))
    }
    let payload = ETHRequestPayload(method: method, params: params)

    portal.provider.request(payload: payload) { result in
      completion(result)
    }
  }

  private func sendTransaction(using portal: Portal, with address: String, completion: @escaping () -> Void) {
    let fakeTransaction = ETHTransactionParam(
      from: address,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      value: "0x1",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    portal.ethSendTransaction(transaction: fakeTransaction) { result in
      defer { completion() }

      guard result.error == nil else {
        return XCTFail("Failed on eth_sendTransation: \(result.error!)")
      }

      if let resultObject = (result.data?.result as? Result<Any>) {
        if let transactionHash = resultObject.data as? String {
          print("Transaction Hash:", transactionHash)
          return XCTAssert(!transactionHash.isEmpty, "Transaction hash exists")
        } else if let error = resultObject.error {
          return XCTFail("Failed on eth_sendTransation: \(error.localizedDescription)")
        } else {
          return XCTFail("No data and no error in result")
        }
      } else {
        return XCTFail("Failed to cast result to expected type")
      }
    }
  }

  private func signTransaction(using portal: Portal, with address: String, completion: @escaping () -> Void) {
    let fakeTransaction = ETHTransactionParam(
      from: address,
      to: "0x4cd042bba0da4b3f37ea36e8a2737dce2ed70db7",
      value: "0x1",
      data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
    )

    portal.ethSignTransaction(transaction: fakeTransaction) { result in
      defer { completion() }

      guard result.error == nil else {
        return XCTFail("Failed on eth_signTransation: \(result.error!)")
      }

      if let resultObject = (result.data?.result as? Result<Any>) {
        if let signedTransaction = resultObject.data as? String {
          print("Signed transaction:", signedTransaction)
          return XCTAssert(!signedTransaction.isEmpty, "Signed transaction exists")
        } else if let error = resultObject.error {
          return XCTFail("Failed on eth_signTransaction: \(error.localizedDescription)")
        } else {
          return XCTFail("No data and no error in result")
        }
      } else {
        return XCTFail("Failed to cast result to expected type")
      }
    }
  }
}

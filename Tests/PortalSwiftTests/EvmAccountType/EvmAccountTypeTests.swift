//
//  EvmAccountTypeTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

/// Minimal portal mock for EvmAccountType tests (rawSign and request only).
private final class EvmAccountTypePortalMock: EvmAccountTypePortalDependency {
  var rawSignReturnValue: PortalProviderResult?
  var rawSignError: Error?
  var rawSignCallCount = 0
  var rawSignMessage: String?
  var rawSignChainId: String?

  var requestReturnValue: PortalProviderResult?
  var requestError: Error?
  var requestCallCount = 0
  var requestChainId: String?
  var requestMethod: PortalRequestMethod?
  var requestParams: [Any]?

  func rawSign(message: String, chainId: String, signatureApprovalMemo: String?) async throws -> PortalProviderResult {
    rawSignCallCount += 1
    rawSignMessage = message
    rawSignChainId = chainId
    if let error = rawSignError {
      throw error
    }
    return rawSignReturnValue ?? PortalProviderResult(id: "1", result: "sig_without_0x")
  }

  func request(chainId: String, method: PortalRequestMethod, params: [Any], options: RequestOptions?) async throws -> PortalProviderResult {
    requestCallCount += 1
    requestChainId = chainId
    requestMethod = method
    requestParams = params
    if let error = requestError {
      throw error
    }
    return requestReturnValue ?? PortalProviderResult(id: "1", result: "0xtxhash123")
  }
}

final class EvmAccountTypeTests: XCTestCase {
  private var mockApi: PortalEvmAccountTypeApiMock!
  private var portalMock: EvmAccountTypePortalMock!
  private var sut: EvmAccountType!

  override func setUpWithError() throws {
    try super.setUpWithError()
    mockApi = PortalEvmAccountTypeApiMock()
    portalMock = EvmAccountTypePortalMock()
    sut = EvmAccountType(api: mockApi, portal: portalMock)
  }

  override func tearDownWithError() throws {
    mockApi = nil
    portalMock = nil
    sut = nil
    try super.tearDownWithError()
  }

  // MARK: - Initialization Tests

  func testInit_createsInstance() {
    XCTAssertNotNil(sut)
  }

  // MARK: - getStatus Tests

  func testGetStatus_success_returnsResponse() async throws {
    let statusResponse = EvmAccountTypeResponse.stub()
    mockApi.getStatusReturnValue = statusResponse
    let response = try await sut.getStatus(chainId: "eip155:11155111")
    XCTAssertEqual(response.data.status, statusResponse.data.status)
    XCTAssertEqual(mockApi.getStatusCallCount, 1)
  }

  func testGetStatus_error_throwsError() async {
    mockApi.getStatusError = URLError(.badServerResponse)
    do {
      _ = try await sut.getStatus(chainId: "eip155:11155111")
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testGetStatus_verifyResponseFields() async throws {
    let metadata = EvmAccountTypeMetadata.stub(
      chainId: "eip155:1",
      eoaAddress: "0xeoa123",
      smartContractAddress: nil
    )
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(
      data: EvmAccountTypeData.stub(status: "EIP_7702_EOA"),
      metadata: metadata
    )
    let response = try await sut.getStatus(chainId: "eip155:1")
    XCTAssertEqual(response.data.status, "EIP_7702_EOA")
    XCTAssertEqual(response.metadata.chainId, "eip155:1")
    XCTAssertEqual(response.metadata.eoaAddress, "0xeoa123")
    XCTAssertNil(response.metadata.smartContractAddress)
  }

  // MARK: - upgradeTo7702 Tests

  func testUpgradeTo7702_nonEip155Chain_throwsUnsupportedNamespaceError() async {
    do {
      _ = try await sut.upgradeTo7702(chainId: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
      XCTFail("Expected EvmAccountTypeError.unsupportedChainNamespace")
    } catch let error as EvmAccountTypeError {
      if case .unsupportedChainNamespace = error { } else {
        XCTFail("Expected unsupportedChainNamespace, got \(error)")
      }
    } catch {
      XCTFail("Expected EvmAccountTypeError, got \(type(of: error))")
    }
  }

  func testUpgradeTo7702_invalidChainIdFormat_throwsError() async {
    do {
      _ = try await sut.upgradeTo7702(chainId: "invalid")
      XCTFail("Expected error for invalid chain ID")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testUpgradeTo7702_accountTypeNotEOA_throwsInvalidAccountTypeError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(
      data: EvmAccountTypeData.stub(status: "SMART_CONTRACT"),
      metadata: .stub()
    )
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected EvmAccountTypeError.invalidAccountType")
    } catch let error as EvmAccountTypeError {
      if case .invalidAccountType("SMART_CONTRACT") = error { } else {
        XCTFail("Expected invalidAccountType(SMART_CONTRACT), got \(error)")
      }
    } catch {
      XCTFail("Expected EvmAccountTypeError, got \(type(of: error))")
    }
  }

  func testUpgradeTo7702_accountTypeAlready7702_throwsInvalidAccountTypeError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(
      data: EvmAccountTypeData.stub(status: "EIP_7702_EOA"),
      metadata: .stub()
    )
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected EvmAccountTypeError.invalidAccountType")
    } catch let error as EvmAccountTypeError {
      if case .invalidAccountType("EIP_7702_EOA") = error { } else {
        XCTFail("Expected invalidAccountType(EIP_7702_EOA), got \(error)")
      }
    } catch {
      XCTFail("Expected EvmAccountTypeError, got \(type(of: error))")
    }
  }

  func testUpgradeTo7702_success_returnsTransactionHash() async throws {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    mockApi.buildAuthorizationTransactionReturnValue = BuildAuthorizationTransactionResponse.stub()
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig123")
    portalMock.requestReturnValue = PortalProviderResult(id: "1", result: "0xabc123hash")

    let txHash = try await sut.upgradeTo7702(chainId: "eip155:11155111")

    XCTAssertEqual(txHash, "0xabc123hash")
    XCTAssertEqual(mockApi.getStatusCallCount, 1)
    XCTAssertEqual(mockApi.buildAuthorizationListCallCount, 1)
    XCTAssertEqual(mockApi.buildAuthorizationTransactionCallCount, 1)
    XCTAssertEqual(portalMock.rawSignCallCount, 1)
    XCTAssertEqual(portalMock.requestCallCount, 1)
  }

  func testUpgradeTo7702_buildAuthorizationList_fails_throwsError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListError = URLError(.networkConnectionLost)
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
    XCTAssertEqual(mockApi.buildAuthorizationListCallCount, 1)
    XCTAssertEqual(portalMock.rawSignCallCount, 0)
  }

  func testUpgradeTo7702_rawSign_fails_throwsError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    portalMock.rawSignError = URLError(.userAuthenticationRequired)
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
    XCTAssertEqual(portalMock.rawSignCallCount, 1)
    XCTAssertEqual(mockApi.buildAuthorizationTransactionCallCount, 0)
  }

  func testUpgradeTo7702_buildAuthorizationTransaction_fails_throwsError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    mockApi.buildAuthorizationTransactionError = URLError(.timedOut)
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig")
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
    XCTAssertEqual(mockApi.buildAuthorizationTransactionCallCount, 1)
  }

  func testUpgradeTo7702_sendTransaction_fails_throwsError() async {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    mockApi.buildAuthorizationTransactionReturnValue = BuildAuthorizationTransactionResponse.stub()
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig")
    portalMock.requestError = URLError(.cannotConnectToHost)
    do {
      _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
    XCTAssertEqual(portalMock.requestCallCount, 1)
  }

  func testUpgradeTo7702_verifiesHashPrefixRemoved() async throws {
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub(
      data: BuildAuthorizationListData.stub(hash: "0xdeadbeef")
    )
    mockApi.buildAuthorizationTransactionReturnValue = BuildAuthorizationTransactionResponse.stub()
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig")
    portalMock.requestReturnValue = PortalProviderResult(id: "1", result: "0xhash")

    _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")

    XCTAssertEqual(portalMock.rawSignMessage, "deadbeef")
  }

  func testUpgradeTo7702_verifiesCorrectChainIdPassedToAllApis() async throws {
    let chainId = "eip155:11155111"
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    mockApi.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    mockApi.buildAuthorizationTransactionReturnValue = BuildAuthorizationTransactionResponse.stub()
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig")
    portalMock.requestReturnValue = PortalProviderResult(id: "1", result: "0xhash")

    _ = try await sut.upgradeTo7702(chainId: chainId)

    XCTAssertEqual(mockApi.getStatusChainId, chainId)
    XCTAssertEqual(mockApi.buildAuthorizationListChainId, chainId)
    XCTAssertEqual(mockApi.buildAuthorizationTransactionChainId, chainId)
    XCTAssertEqual(portalMock.rawSignChainId, chainId)
    XCTAssertEqual(portalMock.requestChainId, chainId)
  }

  func testUpgradeTo7702_nilPortal_throwsPortalNotInitialized() async {
    let sutNoPortal = EvmAccountType(api: mockApi, portal: nil)
    mockApi.getStatusReturnValue = EvmAccountTypeResponse.stub(data: EvmAccountTypeData.stub(status: "EIP_155_EOA"))
    do {
      _ = try await sutNoPortal.upgradeTo7702(chainId: "eip155:11155111")
      XCTFail("Expected EvmAccountTypeError.portalNotInitialized")
    } catch let error as EvmAccountTypeError {
      if case .portalNotInitialized = error { } else {
        XCTFail("Expected portalNotInitialized, got \(error)")
      }
    } catch {
      XCTFail("Expected EvmAccountTypeError, got \(type(of: error))")
    }
  }
}

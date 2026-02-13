//
//  DelegationsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class DelegationsTests: XCTestCase {
  private var mockApi: PortalDelegationsApiMock!
  private var sut: Delegations!

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    mockApi = PortalDelegationsApiMock()
    sut = Delegations(api: mockApi)
  }

  override func tearDownWithError() throws {
    mockApi = nil
    sut = nil
    try super.tearDownWithError()
  }

  // MARK: - Initialization Tests

  func testInit_createsInstance() {
    XCTAssertNotNil(sut)
  }

  // MARK: - approve Tests

  func testApprove_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ApproveDelegationResponse.stub()
    mockApi.approveReturnValue = expectedResponse
    let request = ApproveDelegationRequest.stub()

    // When
    let response = try await sut.approve(request: request)

    // Then
    XCTAssertNotNil(response.metadata)
    XCTAssertEqual(mockApi.approveCallCount, 1)
  }

  func testApprove_error_throwsError() async {
    // Given
    mockApi.approveError = URLError(.badServerResponse)
    let request = ApproveDelegationRequest.stub()

    // When/Then
    do {
      _ = try await sut.approve(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testApprove_evmResponse_returnsTransactions() async throws {
    // Given
    let evmResponse = ApproveDelegationResponse.stub(
      transactions: [ConstructedEipTransaction.stub()],
      encodedTransactions: nil
    )
    mockApi.approveReturnValue = evmResponse
    let request = ApproveDelegationRequest.stub()

    // When
    let response = try await sut.approve(request: request)

    // Then
    XCTAssertNotNil(response.transactions)
    XCTAssertNil(response.encodedTransactions)
    XCTAssertEqual(response.transactions?.count, 1)
  }

  func testApprove_solanaResponse_returnsEncodedTransactions() async throws {
    // Given
    let solanaResponse = ApproveDelegationResponse.stub(
      transactions: nil,
      encodedTransactions: ["encodedTx1", "encodedTx2"]
    )
    mockApi.approveReturnValue = solanaResponse
    let request = ApproveDelegationRequest.stub(chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")

    // When
    let response = try await sut.approve(request: request)

    // Then
    XCTAssertNil(response.transactions)
    XCTAssertNotNil(response.encodedTransactions)
    XCTAssertEqual(response.encodedTransactions?.count, 2)
  }

  func testApprove_verifyMetadataFields() async throws {
    // Given
    let metadata = ApproveDelegationMetadata.stub(
      chainId: "eip155:11155111",
      delegateAmount: "5.0",
      delegateAddress: "0xdelegate",
      tokenSymbol: "USDC"
    )
    mockApi.approveReturnValue = ApproveDelegationResponse.stub(metadata: metadata)
    let request = ApproveDelegationRequest.stub()

    // When
    let response = try await sut.approve(request: request)

    // Then
    XCTAssertEqual(response.metadata?.chainId, "eip155:11155111")
    XCTAssertEqual(response.metadata?.delegateAmount, "5.0")
    XCTAssertEqual(response.metadata?.delegateAddress, "0xdelegate")
    XCTAssertEqual(response.metadata?.tokenSymbol, "USDC")
  }

  // MARK: - revoke Tests

  func testRevoke_success_returnsResponse() async throws {
    // Given
    let expectedResponse = RevokeDelegationResponse.stub()
    mockApi.revokeReturnValue = expectedResponse
    let request = RevokeDelegationRequest.stub()

    // When
    let response = try await sut.revoke(request: request)

    // Then
    XCTAssertNotNil(response.metadata)
    XCTAssertEqual(mockApi.revokeCallCount, 1)
  }

  func testRevoke_error_throwsError() async {
    // Given
    mockApi.revokeError = URLError(.timedOut)
    let request = RevokeDelegationRequest.stub()

    // When/Then
    do {
      _ = try await sut.revoke(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testRevoke_verifyMetadataFields() async throws {
    // Given
    let metadata = RevokeDelegationMetadata.stub(
      chainId: "eip155:11155111",
      revokedAddress: "0xrevoked",
      tokenSymbol: "USDC"
    )
    mockApi.revokeReturnValue = RevokeDelegationResponse.stub(metadata: metadata)
    let request = RevokeDelegationRequest.stub()

    // When
    let response = try await sut.revoke(request: request)

    // Then
    XCTAssertEqual(response.metadata?.revokedAddress, "0xrevoked")
    XCTAssertEqual(response.metadata?.tokenSymbol, "USDC")
  }

  // MARK: - getStatus Tests

  func testGetStatus_success_returnsDelegations() async throws {
    // Given
    let statusResponse = DelegationStatusResponse.stub(
      delegations: [DelegationStatus.stub(), DelegationStatus.stub()]
    )
    mockApi.getStatusReturnValue = statusResponse
    let request = GetDelegationStatusRequest.stub()

    // When
    let response = try await sut.getStatus(request: request)

    // Then
    XCTAssertEqual(response.delegations.count, 2)
    XCTAssertEqual(mockApi.getStatusCallCount, 1)
  }

  func testGetStatus_error_throwsError() async {
    // Given
    mockApi.getStatusError = URLError(.networkConnectionLost)
    let request = GetDelegationStatusRequest.stub()

    // When/Then
    do {
      _ = try await sut.getStatus(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testGetStatus_emptyDelegations_returnsEmptyArray() async throws {
    // Given
    let statusResponse = DelegationStatusResponse.stub(delegations: [])
    mockApi.getStatusReturnValue = statusResponse
    let request = GetDelegationStatusRequest.stub()

    // When
    let response = try await sut.getStatus(request: request)

    // Then
    XCTAssertEqual(response.delegations.count, 0)
  }

  func testGetStatus_verifyDelegationFields() async throws {
    // Given
    let delegation = DelegationStatus.stub(
      address: "0xdel1",
      delegateAmount: "10.0",
      delegateAmountRaw: "10000000"
    )
    let statusResponse = DelegationStatusResponse.stub(delegations: [delegation])
    mockApi.getStatusReturnValue = statusResponse
    let request = GetDelegationStatusRequest.stub()

    // When
    let response = try await sut.getStatus(request: request)

    // Then
    XCTAssertEqual(response.delegations[0].address, "0xdel1")
    XCTAssertEqual(response.delegations[0].delegateAmount, "10.0")
    XCTAssertEqual(response.delegations[0].delegateAmountRaw, "10000000")
  }

  // MARK: - transferFrom Tests

  func testTransferFrom_success_returnsNonOptionalMetadata() async throws {
    // Given
    let transferResponse = TransferFromResponse.stub()
    mockApi.transferFromReturnValue = transferResponse
    let request = TransferFromRequest.stub()

    // When
    let response = try await sut.transferFrom(request: request)

    // Then
    XCTAssertNotNil(response.metadata)
    XCTAssertEqual(mockApi.transferFromCallCount, 1)
  }

  func testTransferFrom_error_throwsError() async {
    // Given
    mockApi.transferFromError = URLError(.badURL)
    let request = TransferFromRequest.stub()

    // When/Then
    do {
      _ = try await sut.transferFrom(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testTransferFrom_verifyMetadataFields() async throws {
    // Given
    let metadata = TransferAsDelegateMetadata.stub(
      amount: "2.0",
      amountRaw: "2000000",
      chainId: "eip155:11155111"
    )
    mockApi.transferFromReturnValue = TransferFromResponse.stub(metadata: metadata)
    let request = TransferFromRequest.stub()

    // When
    let response = try await sut.transferFrom(request: request)

    // Then
    XCTAssertEqual(response.metadata.amount, "2.0")
    XCTAssertEqual(response.metadata.amountRaw, "2000000")
    XCTAssertEqual(response.metadata.chainId, "eip155:11155111")
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCalls_multipleRequests_allSucceed() async throws {
    // Given
    mockApi.approveReturnValue = .stub()
    mockApi.revokeReturnValue = .stub()
    mockApi.getStatusReturnValue = .stub()

    // When
    async let approveResult = sut.approve(request: .stub())
    async let revokeResult = sut.revoke(request: .stub())
    async let statusResult = sut.getStatus(request: .stub())

    let results = try await (approveResult, revokeResult, statusResult)

    // Then
    XCTAssertNotNil(results.0)
    XCTAssertNotNil(results.1)
    XCTAssertNotNil(results.2)
  }
}

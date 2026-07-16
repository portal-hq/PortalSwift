//
//  TraceIdTests.swift
//  PortalSwiftTests
//
//  Tests for the X-Portal-Trace-Id header and MPC reqId propagation.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class TraceIdTests: XCTestCase {
  // MARK: - generateTraceId

  func test_generateTraceId_returnsLowercasedUUID() {
    let traceId = generateTraceId()
    XCTAssertNotNil(UUID(uuidString: traceId), "Trace ID should be a valid UUID")
    XCTAssertEqual(traceId, traceId.lowercased(), "Trace ID should be lowercased")
  }

  func test_generateTraceId_isUnique() {
    let first = generateTraceId()
    let second = generateTraceId()
    XCTAssertNotEqual(first, second)
  }

  // MARK: - PortalAPIRequest header injection

  func test_portalAPIRequest_autoGeneratesTraceIdHeader() throws {
    let url = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me"))
    let request = PortalAPIRequest(url: url, bearerToken: "test-key")

    let header = try XCTUnwrap(request.headers[PORTAL_TRACE_ID_HEADER])
    XCTAssertNotNil(UUID(uuidString: header), "Auto-generated trace ID should be a valid UUID")
  }

  func test_portalAPIRequest_honorsExplicitTraceId() throws {
    let url = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me"))
    let request = PortalAPIRequest(url: url, bearerToken: "test-key", traceId: "explicit-trace-id")

    XCTAssertEqual(request.headers[PORTAL_TRACE_ID_HEADER], "explicit-trace-id")
  }

  // MARK: - PortalApi forwards the header

  func test_portalApi_buildEip155Transaction_forwardsExplicitTraceIdHeader() async throws {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(BuildEip115TransactionResponse.stub())
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: spy)

    _ = try await api.buildEip155Transaction(
      chainId: "eip155:11155111",
      params: BuildTransactionParam(to: "0xto", token: "NATIVE", amount: "1.0"),
      traceId: "trace-build-123"
    )

    let executedRequest = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertEqual(executedRequest.headers[PORTAL_TRACE_ID_HEADER], "trace-build-123")
  }

  func test_portalApi_getClient_includesTraceIdHeader() async throws {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(ClientResponse.stub())
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: spy)

    _ = try await api.getClient()

    let executedRequest = try XCTUnwrap(spy.executeRequestParam)
    let header = try XCTUnwrap(executedRequest.headers[PORTAL_TRACE_ID_HEADER])
    XCTAssertNotNil(UUID(uuidString: header), "getClient should attach a valid trace ID header")
  }

  func test_portalApi_getWalletCapabilities_forwardsExplicitTraceIdHeader() async throws {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(WalletCapabilitiesResponse.stub())
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: spy)

    _ = try await api.getWalletCapabilities(traceId: "trace-capabilities-789")

    let executedRequest = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertEqual(executedRequest.headers[PORTAL_TRACE_ID_HEADER], "trace-capabilities-789")
  }

  // MARK: - MPC reqId mapping

  func test_portalMpcSigner_mapsReqIdIntoMpcMetadata() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      binary: mobileSpy
    )
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")
    let signRequest = PortalSignRequest(method: .eth_sign, params: "test-message")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: "trace-sign-456"
    )

    let metadata = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertTrue(metadata.contains("trace-sign-456"), "MPC metadata should contain the reqId. Got: \(metadata)")
  }

  // MARK: - MPC lifecycle operation-scoped trace ID

  func test_portalMpc_generate_sharesTraceIdAcrossMpcMetadataAndApiCalls() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    let apiSpy = PortalApiSpy()
    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: apiSpy,
      keychain: MockPortalKeychain(),
      mobile: mobileSpy
    )

    _ = try await mpc.generate()

    assertSharedTraceId(
      try reqId(fromMetadata: mobileSpy.mobileGenerateEd25519MetadataParam),
      try reqId(fromMetadata: mobileSpy.mobileGenerateSecp256k1MetadataParam),
      try XCTUnwrap(apiSpy.updateShareStatusTraceIdParam),
      try XCTUnwrap(apiSpy.refreshClientTraceIdParam)
    )
  }

  func test_portalMpc_backup_sharesTraceIdAcrossMpcMetadataAndApiCalls() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileBackupSecp256k1ReturnValue = try MockConstants.mockRotateResult
    mobileSpy.mobileBackupEd25519ReturnValue = try MockConstants.mockRotateResult
    let apiSpy = PortalApiSpy()
    apiSpy.mockClient = ClientResponse.stub(
      environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true)
    )
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getSharesReturnValue = try MockConstants.mockGenerateResponse
    let storageSpy = PortalStorageSpy()
    storageSpy.encryptReturnValue = EncryptData(key: "encryption-key", cipherText: MockConstants.mockCiphertext)
    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: apiSpy,
      keychain: keychainSpy,
      mobile: mobileSpy
    )
    mpc.registerBackupMethod(.iCloud, withStorage: storageSpy)

    let response = try await mpc.backup(.iCloud)

    XCTAssertEqual(mobileSpy.mobileBackupEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileBackupSecp256k1CallsCount, 1)

    assertSharedTraceId(
      response.traceId,
      try reqId(fromMetadata: mobileSpy.mobileBackupEd25519MetadataParam),
      try reqId(fromMetadata: mobileSpy.mobileBackupSecp256k1MetadataParam),
      try XCTUnwrap(apiSpy.updateShareStatusTraceIdParam),
      try XCTUnwrap(apiSpy.storeClientCipherTextTraceIdParam),
      try XCTUnwrap(apiSpy.refreshClientTraceIdParam)
    )
  }

  func test_portalMpc_recover_sharesTraceIdAcrossMpcMetadataAndApiCalls() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileRecoverSigningSecp256k1ReturnValue = try MockConstants.mockRotateResult
    mobileSpy.mobileRecoverSigningEd25519ReturnValue = try MockConstants.mockRotateResult
    let apiSpy = PortalApiSpy()
    apiSpy.mockClient = ClientResponse.stub(
      environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true)
    )
    let storageSpy = PortalStorageSpy()
    storageSpy.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString
    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: apiSpy,
      keychain: MockPortalKeychain(),
      mobile: mobileSpy
    )
    mpc.registerBackupMethod(.iCloud, withStorage: storageSpy)

    _ = try await mpc.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    XCTAssertEqual(mobileSpy.mobileRecoverSigningEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileRecoverSigningSecp256k1CallsCount, 1)

    assertSharedTraceId(
      try reqId(fromMetadata: mobileSpy.mobileRecoverSigningEd25519MetadataParam),
      try reqId(fromMetadata: mobileSpy.mobileRecoverSigningSecp256k1MetadataParam),
      try XCTUnwrap(apiSpy.getClientCipherTextTraceIdParam),
      try XCTUnwrap(apiSpy.updateShareStatusTraceIdParam),
      try XCTUnwrap(apiSpy.refreshClientTraceIdParam)
    )
  }

  func test_portalMpc_eject_sharesTraceIdAcrossApiCalls() async throws {
    let apiSpy = PortalApiSpy()
    apiSpy.mockClient = ClientResponse.stub(
      environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true)
    )
    let storageSpy = PortalStorageSpy()
    storageSpy.decryptReturnValue = UnitTestMockConstants.decodedShare
    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: apiSpy,
      keychain: MockPortalKeychain(),
      mobile: MobileSpy()
    )
    mpc.registerBackupMethod(.iCloud, withStorage: storageSpy)

    _ = try await mpc.eject(.iCloud)

    assertSharedTraceId(
      try XCTUnwrap(apiSpy.getClientCipherTextTraceIdParam),
      try XCTUnwrap(apiSpy.prepareEjectTraceIdParam),
      try XCTUnwrap(apiSpy.ejectTraceIdParam)
    )
  }

  func test_portalMpc_generateSolanaWallet_sharesTraceIdAcrossMpcMetadataAndApiCalls() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    let apiSpy = PortalApiSpy()
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: MockConstants.mockEip155Address
    ]
    keychainSpy.getSharesReturnValue = try MockConstants.mockGenerateResponse
    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: apiSpy,
      keychain: keychainSpy,
      mobile: mobileSpy
    )

    // Public wrapper may fail looking up the new Solana address from the spy keychain;
    // the shared operation trace ID is set before that point.
    _ = try? await mpc.generateSolanaWallet()

    assertSharedTraceId(
      try reqId(fromMetadata: mobileSpy.mobileGenerateEd25519MetadataParam),
      try XCTUnwrap(apiSpy.updateShareStatusTraceIdParam),
      try XCTUnwrap(apiSpy.refreshClientTraceIdParam)
    )
  }

  // MARK: - upgradeTo7702 operation-scoped trace ID

  func test_upgradeTo7702_sharesTraceIdAcrossApiAndRawSignCalls() async throws {
    let apiMock = PortalEvmAccountTypeApiMock()
    apiMock.getStatusReturnValue = EvmAccountTypeResponse.stub(
      data: EvmAccountTypeData.stub(status: "EIP_155_EOA")
    )
    apiMock.buildAuthorizationListReturnValue = BuildAuthorizationListResponse.stub()
    apiMock.buildAuthorizationTransactionReturnValue = BuildAuthorizationTransactionResponse.stub()

    let portalMock = TraceIdEvmAccountTypePortalMock()
    portalMock.rawSignReturnValue = PortalProviderResult(id: "1", result: "sig")
    let sut = EvmAccountType(api: apiMock, portal: portalMock)

    _ = try await sut.upgradeTo7702(chainId: "eip155:11155111")

    assertSharedTraceId(
      try XCTUnwrap(apiMock.getStatusTraceId),
      try XCTUnwrap(apiMock.buildAuthorizationListTraceId),
      try XCTUnwrap(portalMock.rawSignTraceId),
      try XCTUnwrap(apiMock.buildAuthorizationTransactionTraceId)
    )
  }

  // MARK: - wallet_getCapabilities request trace ID

  func test_portalProvider_walletGetCapabilities_forwardsRequestTraceId() async throws {
    let apiSpy = PortalApiSpy()
    let provider = try PortalProvider(
      apiKey: MockConstants.mockApiKey,
      rpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      requests: MockPortalRequests(),
      signer: MockPortalMpcSigner(apiKey: MockConstants.mockApiKey, keychain: MockPortalKeychain())
    )
    provider.api = apiSpy

    _ = try await provider.request(
      chainId: "eip155:11155111",
      method: .wallet_getCapabilities,
      params: nil,
      options: RequestOptions(traceId: "capabilities-trace-123")
    )

    XCTAssertEqual(apiSpy.getWalletCapabilitiesTraceIdParam, "capabilities-trace-123")
  }

  // MARK: - Helpers

  private func reqId(fromMetadata metadata: String?) throws -> String {
    let metadata = try XCTUnwrap(metadata)
    let data = try XCTUnwrap(metadata.data(using: .utf8))
    let decoded = try JSONDecoder().decode(MpcMetadata.self, from: data)
    return try XCTUnwrap(decoded.reqId, "MPC metadata should include reqId. Got: \(metadata)")
  }

  private func assertSharedTraceId(
    _ ids: String...,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let first = ids.first else {
      XCTFail("Expected at least one trace ID", file: file, line: line)
      return
    }
    for id in ids {
      XCTAssertEqual(id, first, "Expected a single shared operation trace ID", file: file, line: line)
    }
    XCTAssertNotNil(UUID(uuidString: first), "Operation trace ID should be a valid UUID", file: file, line: line)
  }
}

/// Minimal portal dependency mock for upgradeTo7702 trace ID assertions.
private final class TraceIdEvmAccountTypePortalMock: EvmAccountTypePortalDependency {
  var rawSignReturnValue: PortalProviderResult?
  var rawSignTraceId: String?

  func rawSign(
    message _: String,
    chainId _: String,
    signatureApprovalMemo _: String?,
    traceId: String?
  ) async throws -> PortalProviderResult {
    rawSignTraceId = traceId
    return rawSignReturnValue ?? PortalProviderResult(id: "1", result: "sig")
  }

  func request(
    chainId _: String,
    method _: PortalRequestMethod,
    params _: [Any],
    options _: RequestOptions?
  ) async throws -> PortalProviderResult {
    PortalProviderResult(id: "1", result: "0xtxhash")
  }
}

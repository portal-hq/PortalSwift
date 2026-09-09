//
//  PortalProviderCredentialTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Covers the credential half of `PortalProvider`: which gateways ever see the bearer, when the
/// token is resolved relative to user approval, and who reports a rejected credential.
///
/// Three rules are pinned here because breaking any of them is a security bug rather than a
/// behaviour change. First, the bearer is attached only to hosts `isPortalOwnedUrl` accepts, and
/// for any other host the credential is not even resolved — a look-alike gateway must not be able
/// to harvest a session token, and a broken session must not break RPC traffic that never needed
/// it. Second, the token for a signature is resolved *after* the approval wait, so a declined
/// request never touches the session and a long-pending approval cannot sign with a token that
/// went stale while the user was deciding. Third, there is exactly one reporter per rejection:
/// the transport's 401 hook for HTTP, and `handleSignRequest` for the MPC service's `AUTH_FAILED`
/// (which the transport never sees), and neither reports a 401 that came from a third party.
///
/// The registry behind `PortalCredentialSupport.reportUnauthorized(_:)` is process-wide and its "reported" flags are
/// once-ever, so it is reset around every case; the logger sink is recorded so the "never logs a
/// token" cases assert against what the SDK actually emitted rather than against nothing.
final class PortalProviderCredentialTests: XCTestCase {
  // MARK: - Fixtures

  /// The one chain every case configures; the RPC URL under test is bound to it.
  private static let chainId = "eip155:11155111"

  /// The token the default credential hands out. A distinctive value so a "never logged" or
  /// "never sent" assertion cannot pass by accident against some other mock constant.
  private static let sessionToken = "session-token-1"

  /// The RPC URLs the bearer gate is exercised with. The withheld ones are the attacker shapes
  /// `isPortalOwnedUrl` exists to reject; the attached ones include the local-loopback and
  /// non-`api.` Portal hosts the pre-7.5 string-prefix check got wrong in both directions.
  private enum Gateway {
    static let portalApi = "https://api.portalhq.io/rpc/v1/eip155/11155111"
    static let nonApiPortal = "https://web.portalhq.io/rpc/v1/eip155/11155111"
    static let portalDev = "https://api.portalhq.dev/rpc/v1/eip155/11155111"
    static let localhost = "http://localhost:8545"
    static let loopbackIp = "http://127.0.0.1:8545"
    static let uppercaseHost = "https://API.PORTALHQ.IO/rpc"
    static let trailingDotHost = "https://api.portalhq.io./rpc"

    static let lookalike = "https://api.portalhq.attacker.com/rpc"
    static let thirdParty = "https://mainnet.infura.io/v3/project-id"
    static let suffixLookalike = "https://api.portalhq.io.attacker.com/rpc"
    static let percentEncodedHost = "https://attacker.com%2f.portalhq.io/rpc"
    static let userinfoHost = "https://api.portalhq.io@attacker.com/rpc"
    static let portalHostInPath = "https://attacker.com/api.portalhq.io/rpc"
    static let notPortalHost = "https://notportalhq.io/rpc"
    static let customProxy = "https://api.custodian.example/rpc"
    static let customProxySubdomain = "https://rpc.api.custodian.example/rpc"
    static let customProxyLookalike = "https://api.custodian.example.attacker.com/rpc"
  }

  private var credentials = MockCredentials(tokenValue: PortalProviderCredentialTests.sessionToken)
  private var requestsSpy = PortalRequestsSpy()
  private var mobileSpy = MobileSpy()
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    self.credentials = MockCredentials(tokenValue: Self.sessionToken)
    self.requestsSpy = PortalRequestsSpy()
    self.requestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockRpcResponse)
    self.mobileSpy = MobileSpy()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// A lock-guarded slot for a value produced inside an SDK callback (a listener, a completion
  /// handler) and read from the test thread.
  private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value?

    var value: Value? {
      get {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self._value
      }
      set {
        self.lock.lock()
        defer { self.lock.unlock() }
        self._value = newValue
      }
    }
  }

  /// Builds the provider under test. `signer: nil` leaves the real `PortalMpcSigner` in place,
  /// wired to `mobileSpy`, which is how the "token reaches the native boundary" cases assert on
  /// the value the binary was handed rather than on an intermediate double.
  private func makeProvider(
    rpcUrl: String = Gateway.portalApi,
    credentials: PortalCredentials? = nil,
    autoApprove: Bool = true,
    requests: PortalRequestsProtocol? = nil,
    signer: PortalSignerProtocol? = nil,
    configuredHosts: [String] = []
  ) throws -> PortalProvider {
    try PortalProvider(
      credentials: credentials ?? self.credentials,
      rpcConfig: [Self.chainId: rpcUrl],
      keychain: MockPortalKeychain(),
      autoApprove: autoApprove,
      requests: requests ?? self.requestsSpy,
      signer: signer,
      binary: self.mobileSpy,
      configuredHosts: configuredHosts
    )
  }

  /// Builds the provider through the deprecated Client-API-Key initializer, which is the surface
  /// existing hosts still use and which must keep authenticating exactly as before.
  private func makeApiKeyProvider(
    apiKey: String,
    rpcUrl: String = Gateway.portalApi
  ) throws -> PortalProvider {
    try PortalProvider(
      apiKey: apiKey,
      rpcConfig: [Self.chainId: rpcUrl],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      requests: self.requestsSpy,
      binary: self.mobileSpy
    )
  }

  /// A plain RPC request (never signed), which is the path the bearer gate lives on.
  @discardableResult
  private func rpc(_ provider: PortalProvider) async throws -> PortalProviderResult {
    try await provider.request(
      chainId: Self.chainId,
      method: .eth_blockNumber,
      params: [],
      connect: nil,
      options: nil
    )
  }

  /// A signing request, which is the path that waits for approval and then resolves the token.
  @discardableResult
  private func sign(_ provider: PortalProvider) async throws -> PortalProviderResult {
    try await provider.request(
      chainId: Self.chainId,
      method: .eth_sign,
      params: [AnyCodable(MockConstants.mockEip155Address), AnyCodable("test")],
      connect: nil,
      options: nil
    )
  }

  /// Runs `operation`, failing the test if it does not throw, and returns the error it threw.
  private func captureError<T>(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> T
  ) async -> Error? {
    do {
      _ = try await operation()
      XCTFail("Expected the call to throw, but it returned a value.", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  /// Asserts the last executed request carried exactly `token` as its bearer.
  private func assertBearerSent(
    _ token: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      self.requestsSpy.executeRequestParam?.headers["Authorization"],
      "Bearer \(token)",
      "The Portal-owned gateway should have received the resolved credential.",
      file: file,
      line: line
    )
  }

  /// Asserts no request made by the provider carried any bearer at all — the assertion the
  /// look-alike-host cases need, since a leak on any one of several calls is still a leak.
  private func assertNoBearerSent(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      self.requestsSpy.bearerTokensSent.allSatisfy { $0 == nil },
      "A credential was sent to a host that is not Portal-owned: \(self.requestsSpy.bearerTokensSent)",
      file: file,
      line: line
    )
    XCTAssertNil(
      self.requestsSpy.executeRequestParam?.headers["Authorization"],
      "An Authorization header reached a host that is not Portal-owned.",
      file: file,
      line: line
    )
  }

  /// Gives an unexpected invalidation notification a bounded chance to arrive before a case
  /// asserts that none did; deliveries hop to the main actor, so reading the counter immediately
  /// would pass even if one were queued.
  private func assertNoInvalidationDelivered(
    _ recorder: InvalidationListenerRecorder,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    let delivered = await waitUntil(timeout: 0.2) { recorder.count > 0 }
    XCTAssertFalse(delivered, "The host was told the session ended when it had not.", file: file, line: line)
  }

  /// Waits for exactly one invalidation notification and fails with a readable message otherwise.
  private func assertInvalidationDeliveredOnce(
    _ recorder: InvalidationListenerRecorder,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    let delivered = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(delivered, "The host was never told the session ended (count: \(recorder.count)).", file: file, line: line)
    XCTAssertEqual(recorder.count, 1, "The host was told more than once.", file: file, line: line)
  }

  // MARK: - init: unauthorized hook installation

  func test_init_willInstallUnauthorizedHook_whenTransportHasNone() async throws {
    XCTAssertNil(self.requestsSpy.onUnauthorized)

    let provider = try makeProvider()
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)

    XCTAssertNotNil(self.requestsSpy.onUnauthorized)
    XCTAssertEqual(self.requestsSpy.onUnauthorizedSetCount, 1)

    self.requestsSpy.onUnauthorized?(nil)

    XCTAssertEqual(self.credentials.invalidateCalls, 1)
    await self.assertInvalidationDeliveredOnce(recorder)
    withExtendedLifetime(provider) {}
  }

  func test_init_willLeaveExistingUnauthorizedHookAlone() throws {
    let marker = LockedBox<Bool>()
    self.requestsSpy.onUnauthorized = { _ in marker.value = true }

    let provider = try makeProvider()

    XCTAssertEqual(self.requestsSpy.onUnauthorizedSetCount, 1, "The preset hook must not be replaced.")

    self.requestsSpy.onUnauthorized?(nil)

    XCTAssertEqual(marker.value, true, "The host's own hook should still be the one that runs.")
    XCTAssertEqual(self.credentials.invalidateCalls, 0)
    withExtendedLifetime(provider) {}
  }

  func test_init_willNotCrash_whenTransportIsNotReporting() async throws {
    let nonReporting = NonReportingPortalRequestsSpy()
    nonReporting.returnData = try JSONEncoder().encode(MockConstants.mockRpcResponse)

    let provider = try makeProvider(requests: nonReporting)
    try await self.rpc(provider)

    XCTAssertEqual(nonReporting.executeCallsCount, 1)
  }

  // MARK: - init(apiKey:)

  func test_init_apiKey_willWrapKeyInStaticCredentials() async throws {
    let provider = try makeApiKeyProvider(apiKey: MockConstants.mockApiKey)

    try await self.rpc(provider)

    self.assertBearerSent(MockConstants.mockApiKey)
  }

  func test_init_apiKey_willThrowInvalidApiKey_whenKeyBlank() throws {
    XCTAssertThrowsError(try self.makeApiKeyProvider(apiKey: "   ")) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  // MARK: - request(): the RPC bearer gate

  func test_request_rpc_willAttachBearer_onPortalOwnedGateway() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.portalApi)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
    XCTAssertEqual(self.credentials.getTokenCalls, 1)
  }

  func test_request_rpc_willWithholdBearer_onThirdPartyGateway() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.thirdParty)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_request_rpc_willAttachBearer_onPortalhqDevGateway() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.portalDev)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willAttachBearer_whenHostHasTrailingDot() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.trailingDotHost)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willWithholdBearer_onPercentEncodedHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.percentEncodedHost)

    // Whether Foundation can build a `URL` from this at all is beside the point: the credential
    // must not be resolved for it either way, so the call is allowed to throw.
    _ = try? await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_request_rpc_willWithholdBearer_whenPortalHostOnlyInPath() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.portalHostInPath)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_request_rpc_willWithholdBearer_onNotportalhqHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.notPortalHost)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  // MARK: - request(): resolving the credential per call

  // The four shapes the pre-7.5 string-prefix gate got wrong in the *withholding* direction: each
  // starts with `https://api.portalhq.` and therefore received the credential.

  func test_request_rpc_willWithholdBearer_onLookalikeHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.lookalike)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "The token must not even be resolved for a look-alike host")
  }

  func test_request_rpc_willWithholdBearer_onSuffixLookalikeHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.suffixLookalike)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_request_rpc_willWithholdBearer_onUserinfoSpoofedHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.userinfoHost)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  // And the shapes it got wrong in the *attaching* direction: legitimate Portal hosts that do not
  // spell `api.portalhq.` and so silently went out without a bearer.

  func test_request_rpc_willAttachBearer_onNonApiPortalHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.nonApiPortal)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willAttachBearer_onUppercasePortalHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.uppercaseHost)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  // MARK: - request(): configured-host trust is per instance

  func test_request_rpc_willAttachBearer_onTheOwningInstancesConfiguredHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.customProxy, configuredHosts: ["api.custodian.example"])

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willAttachBearer_onASubdomainOfTheOwningInstancesHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.customProxySubdomain, configuredHosts: ["api.custodian.example"])

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willAttachBearer_onTheMpcHost() async throws {
    let provider = try PortalProvider(
      credentials: self.credentials,
      rpcConfig: [Self.chainId: "https://mpc.custodian.example/rpc"],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      mpcHost: "mpc.custodian.example",
      requests: self.requestsSpy,
      binary: self.mobileSpy
    )

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willWithholdBearer_onALookalikeOfTheOwningInstancesHost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.customProxyLookalike, configuredHosts: ["api.custodian.example"])

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_request_rpc_willWithholdBearer_onAHostRegisteredByAnotherInstance() async throws {
    // Another `Portal` / `PortalApi` / `PortalAuth` / `PortalConnect` in the process was built with
    // this host, so the 401 and trace gates trust it — but this provider's `Portal` was not, and a
    // credential must never cross that instance boundary through an `rpcConfig` URL.
    PortalOwnedHosts.register("api.custodian.example")
    XCTAssertTrue(isPortalOwnedUrl(Gateway.customProxySubdomain), "Precondition: the registry does trust the host")
    let provider = try makeProvider(rpcUrl: Gateway.customProxySubdomain)

    try await self.rpc(provider)

    self.assertNoBearerSent()
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "The credential is not even resolved for a host this instance was not configured with")
  }

  func test_request_rpc_willAttachBearer_onLocalhost() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.localhost)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willAttachBearer_onLoopbackIp() async throws {
    let provider = try makeProvider(rpcUrl: Gateway.loopbackIp)

    try await self.rpc(provider)

    self.assertBearerSent(Self.sessionToken)
  }

  func test_request_rpc_willResolveTokenPerRequest() async throws {
    let provider = try makeProvider()

    try await self.rpc(provider)
    try await self.rpc(provider)

    XCTAssertEqual(self.credentials.getTokenCalls, 2, "The token must not be cached across requests.")
  }

  func test_request_rpc_willSendRotatedToken_withoutRebuildingProvider() async throws {
    let provider = try makeProvider()

    try await self.rpc(provider)
    self.credentials.tokenValue = "session-token-2"
    try await self.rpc(provider)

    XCTAssertEqual(self.requestsSpy.bearerTokensSent, [Self.sessionToken, "session-token-2"])
    XCTAssertEqual(
      self.requestsSpy.executeRequestHistory.last?.headers["Authorization"],
      "Bearer session-token-2"
    )
  }

  // MARK: - request(): credential failures on the RPC path

  func test_request_rpc_willThrowProviderFailure_withoutRequest_whenGetTokenThrows() async throws {
    self.credentials.onGetToken = { throw URLError(.badURL) }
    let provider = try makeProvider()

    let error = await self.captureError { try await self.rpc(provider) }

    let credentialError = try XCTUnwrap(error as? PortalCredentialError)
    XCTAssertEqual(credentialError, .providerFailure(underlying: URLError(.badURL)))
    XCTAssertEqual(credentialError.reason, .providerFailure)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0, "A request must not go out without its credential.")
  }

  func test_request_rpc_willThrowUnavailable_withoutRequest_whenTokenBlank() async throws {
    self.credentials.tokenValue = ""
    let provider = try makeProvider()

    let error = await self.captureError { try await self.rpc(provider) }

    XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_request_rpc_willThrowUnavailable_whenTokenWhitespace() async throws {
    self.credentials.tokenValue = "  \t\n"
    let provider = try makeProvider()

    let error = await self.captureError { try await self.rpc(provider) }

    XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_request_rpc_willPassThroughSessionInvalidated() async throws {
    let session = MockPortalSession(tokenValue: Self.sessionToken)
    try session.invalidate()
    let provider = try makeProvider(credentials: session)

    let error = await self.captureError { try await self.rpc(provider) }

    let credentialError = try XCTUnwrap(error as? PortalCredentialError)
    XCTAssertEqual(credentialError, .sessionInvalidated)
    XCTAssertTrue(credentialError.requiresReauthentication)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_request_rpc_willNotResolveToken_forThirdPartyGateway_evenIfCredentialBroken() async throws {
    self.credentials.onGetToken = { throw URLError(.badURL) }
    let provider = try makeProvider(rpcUrl: Gateway.thirdParty)

    try await self.rpc(provider)

    XCTAssertEqual(self.credentials.getTokenCalls, 0, "A broken session must not break third-party RPC.")
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
  }

  // MARK: - request(): who reports a 401

  func test_request_rpc_willRethrowUnauthorized_withoutInvalidating_onThirdPartyGateway() async throws {
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)
    self.requestsSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let provider = try makeProvider(rpcUrl: Gateway.thirdParty)

    let error = await self.captureError { try await self.rpc(provider) }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(self.credentials.invalidateCalls, 0, "A third party cannot end the Portal session.")
    await self.assertNoInvalidationDelivered(recorder)
  }

  func test_request_rpc_willRethrowUnauthorized_andLeaveReportingToTransport_onPortalGateway() async throws {
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)
    self.requestsSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let provider = try makeProvider(rpcUrl: Gateway.portalApi)

    let error = await self.captureError { try await self.rpc(provider) }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    // The spy throws without invoking the hook, which is precisely how a provider that reported
    // 401s itself would be caught: the transport is the single reporter for HTTP rejections.
    XCTAssertEqual(self.credentials.invalidateCalls, 0)
    await self.assertNoInvalidationDelivered(recorder)
  }

  // MARK: - request(): signing and approval ordering

  func test_request_sign_willResolveTokenOnlyAfterApproval() async throws {
    let signerSpy = SignerSpy()
    let provider = try makeProvider(autoApprove: false, signer: signerSpy)
    let callsAtRequestTime = LockedBox<Int>()

    _ = provider.on(event: Events.PortalSigningRequested.rawValue) { [weak provider] data in
      callsAtRequestTime.value = self.credentials.getTokenCalls
      _ = provider?.emit(event: Events.PortalSigningApproved.rawValue, data: data)
    }

    let result = try await self.sign(provider)

    XCTAssertEqual(callsAtRequestTime.value, 0, "The session must not be touched before the user approves.")
    XCTAssertEqual(self.credentials.getTokenCalls, 1)
    XCTAssertEqual(signerSpy.signTokenParams, [Self.sessionToken])
    XCTAssertEqual(signerSpy.legacySignCallsCount, 0)
    XCTAssertEqual(result.result as? String, MockConstants.mockSignature)
  }

  func test_request_sign_willNotResolveToken_whenUserDeclines() async throws {
    let signerSpy = SignerSpy()
    let provider = try makeProvider(autoApprove: false, signer: signerSpy)

    _ = provider.on(event: Events.PortalSigningRequested.rawValue) { [weak provider] data in
      guard let payload = data as? PortalProviderRequestWithId else {
        return
      }
      // The rejection listener matches on `ETHRequestPayload`, so a decline has to be emitted in
      // that shape with the same request id.
      let rejection = ETHRequestPayload(
        method: ETHRequestMethods.Sign.rawValue,
        params: [],
        id: payload.id
      )
      _ = provider?.emit(event: Events.PortalSigningRejected.rawValue, data: rejection)
    }

    let error = await self.captureError { try await self.sign(provider) }

    XCTAssertEqual(error as? ProviderSigningError, .userDeclinedApproval)
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "A declined request must never touch the session.")
    XCTAssertEqual(signerSpy.signTokenCallsCount, 0)
  }

  func test_request_sign_willPassResolvedTokenToBinary() async throws {
    let provider = try makeProvider()

    let result = try await self.sign(provider)

    XCTAssertEqual(self.mobileSpy.mobileSignApiKeyParam, Self.sessionToken)
    XCTAssertEqual(self.mobileSpy.mobileSignCallsCount, 1)
    XCTAssertEqual(result.result as? String, MockConstants.mockSignature)
  }

  func test_request_sign_willPassRotatedTokenToBinary() async throws {
    let provider = try makeProvider()

    try await self.sign(provider)
    self.credentials.tokenValue = "session-token-2"
    try await self.sign(provider)

    XCTAssertEqual(self.mobileSpy.mobileSignApiKeyParam, "session-token-2")
    XCTAssertEqual(self.mobileSpy.mobileSignCallsCount, 2)
  }

  func test_request_sign_willThrowProviderFailure_withoutSigning_whenGetTokenThrows() async throws {
    self.credentials.onGetToken = { throw URLError(.badURL) }
    let provider = try makeProvider()

    let error = await self.captureError { try await self.sign(provider) }

    XCTAssertEqual(error as? PortalCredentialError, .providerFailure(underlying: URLError(.badURL)))
    XCTAssertEqual(self.mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_request_sign_willThrowUnavailable_whenTokenBlank() async throws {
    self.credentials.tokenValue = ""
    let provider = try makeProvider()

    let error = await self.captureError { try await self.sign(provider) }

    XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    XCTAssertEqual(self.mobileSpy.mobileSignCallsCount, 0)
  }

  // MARK: - request(): reporting the MPC service's AUTH_FAILED

  func test_request_sign_willReportUnauthorizedOnce_whenSignerReturnsAuthFailed() async throws {
    let session = MockPortalSession(tokenValue: Self.sessionToken)
    let recorder = InvalidationListenerRecorder(credentials: session)
    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let provider = try makeProvider(credentials: session)

    let error = await self.captureError { try await self.sign(provider) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertEqual(mpcError.id, MpcJSON.authFailedId)
    XCTAssertTrue(mpcError.isAuthFailure)
    XCTAssertEqual(session.invalidateCalls, 1)
    await self.assertInvalidationDeliveredOnce(recorder)
  }

  func test_request_sign_willNotReport_whenTheCredentialRotatedWhileSigning() async throws {
    // A host credential that rotates in place once the binary has been handed the old token: the
    // AUTH_FAILED is for that token, and the replacement was never rejected.
    let credentials = MockCredentials(tokenValue: "sign-tok-1")
    let spy = self.mobileSpy
    credentials.onGetToken = { [weak credentials] in
      guard let credentials, spy.mobileSignCallsCount >= 1 else { return }
      credentials.tokenValue = "sign-tok-2"
    }
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let provider = try makeProvider(credentials: credentials)

    let error = await self.captureError { try await self.sign(provider) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isAuthFailure, "The rejection still surfaces to the caller")
    XCTAssertEqual(self.mobileSpy.mobileSignApiKeyParam, "sign-tok-1", "The binary was handed the pre-rotation token")
    XCTAssertEqual(credentials.invalidateCalls, 0, "The replacement token was never rejected")
    let notified = await waitUntil(timeout: 0.3) { recorder.count > 0 }
    XCTAssertFalse(notified, "A rotated credential must not be reported for a stale AUTH_FAILED.")
  }

  func test_request_sign_willThrowSessionInvalidated_withoutBinaryCall_afterAuthFailed() async throws {
    let session = MockPortalSession(tokenValue: Self.sessionToken)
    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let provider = try makeProvider(credentials: session)

    _ = await self.captureError { try await self.sign(provider) }
    let secondError = await self.captureError { try await self.sign(provider) }

    XCTAssertEqual(secondError as? PortalCredentialError, .sessionInvalidated)
    XCTAssertEqual(self.mobileSpy.mobileSignCallsCount, 1, "A spent session must not reach the binary again.")
  }

  func test_request_sign_willNotReport_whenSignerReturnsOtherError() async throws {
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)
    self.mobileSpy.mobileSignReturnValue = MpcJSON.error(id: "SIGN_FAIL")
    let provider = try makeProvider()

    let error = await self.captureError { try await self.sign(provider) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertEqual(mpcError.id, "SIGN_FAIL")
    XCTAssertFalse(mpcError.isAuthFailure)
    XCTAssertEqual(self.credentials.invalidateCalls, 0)
    await self.assertNoInvalidationDelivered(recorder)
  }

  func test_request_sign_willReportOnce_whenTwoConcurrentSignsFailAuth() async throws {
    // A session-shaped credential is used rather than `MockPortalSession` because the guarantee
    // under test is "one clear however many requesters 401 together": `invalidate()` may be
    // entered by both reporters, and what must happen exactly once is the storage delete (and
    // the host notification). `SessionLikeCredentials` counts those separately.
    let session = SessionLikeCredentials(token: Self.sessionToken, throwsWhenInvalidated: true)
    let recorder = InvalidationListenerRecorder(credentials: session)
    let signerSpy = SignerSpy()
    signerSpy.errorToThrow = PortalMpcError(PortalError(id: MpcJSON.authFailedId, message: "401 - Unauthorized"))
    let provider = try makeProvider(credentials: session, signer: signerSpy)

    async let first: PortalProviderResult = self.sign(provider)
    async let second: PortalProviderResult = self.sign(provider)

    var errors: [Error] = []
    do {
      _ = try await first
      XCTFail("The first signature should have failed.")
    } catch {
      errors.append(error)
    }
    do {
      _ = try await second
      XCTFail("The second signature should have failed.")
    } catch {
      errors.append(error)
    }

    for error in errors {
      if let mpcError = error as? PortalMpcError {
        XCTAssertTrue(mpcError.isAuthFailure)
      } else {
        XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
      }
    }
    XCTAssertEqual(session.storageDeletes, 1, "Overlapping reporters must produce one clear.")
    XCTAssertEqual(session.maxConcurrentCallers, 1, "Invalidation must be serialised per credential.")
    await self.assertInvalidationDeliveredOnce(recorder)
  }

  func test_request_sign_willStillThrowAuthFailed_whenInvalidateThrows() async throws {
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)
    self.credentials.onInvalidate = { throw NSError(domain: "TestKeychain", code: -25300) }
    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let provider = try makeProvider()

    let error = await self.captureError { try await self.sign(provider) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isAuthFailure, "The bookkeeping failure must not replace the original error.")
    XCTAssertEqual(self.credentials.invalidateCalls, 1)
    await self.assertInvalidationDeliveredOnce(recorder)
    XCTAssertTrue(
      self.logger.contains("PortalProvider.handleSignRequest - reportUnauthorized()"),
      "The swallowed invalidation failure should still be logged."
    )
  }

  // MARK: - request(): secrets never leak

  func test_request_sign_errorDescription_willNotContainToken() async throws {
    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let authProvider = try makeProvider()

    let thrownAuthError = await self.captureError { try await self.sign(authProvider) }
    let authError = try XCTUnwrap(thrownAuthError)
    XCTAssertFalse("\(authError)".contains(Self.sessionToken))
    XCTAssertFalse(authError.localizedDescription.contains(Self.sessionToken))

    // A provider failure whose own cause is token-free: neither rendering may leak.
    self.credentials.onGetToken = { throw URLError(.badURL) }
    let failingProvider = try makeProvider()
    let thrownProviderError = await self.captureError { try await self.sign(failingProvider) }
    let providerError = try XCTUnwrap(thrownProviderError)
    XCTAssertFalse("\(providerError)".contains(Self.sessionToken))
    XCTAssertFalse(providerError.localizedDescription.contains(Self.sessionToken))

    // And a provider failure whose cause does embed the token: `errorDescription` is the string
    // that reaches logs and crash reports, and it must never carry the cause through.
    let leaky = MockCredentials(tokenValue: Self.sessionToken)
    leaky.onGetToken = {
      throw NSError(
        domain: "TestProvider",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "keystore rejected \(Self.sessionToken)"]
      )
    }
    let leakyProvider = try makeProvider(credentials: leaky)
    let thrownLeakyError = await self.captureError { try await self.sign(leakyProvider) }
    let leakyError = try XCTUnwrap(thrownLeakyError as? PortalCredentialError)
    XCTAssertEqual(leakyError.reason, .providerFailure)
    XCTAssertFalse(leakyError.localizedDescription.contains(Self.sessionToken))
    let description = try XCTUnwrap(leakyError.errorDescription)
    XCTAssertFalse(description.contains(Self.sessionToken))
  }

  func test_request_sign_willNotLogToken() async throws {
    // The recorder is installed on the logger's sink, which sees every level regardless of the
    // configured `logLevel`, so this cannot pass because the SDK was quiet.
    let successProvider = try makeProvider()
    try await self.sign(successProvider)

    self.mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let failingProvider = try makeProvider()
    _ = await self.captureError { try await self.sign(failingProvider) }

    XCTAssertFalse(self.logger.messages.isEmpty, "Nothing was logged; the assertion would be vacuous.")
    self.logger.assertNoSecret(Self.sessionToken)
  }

  // MARK: - Deprecated completion-handler surface

  func test_request_deprecatedPayloadApi_willPassTokenToBinary() async throws {
    let provider = try makeProvider()
    let payload = ETHRequestPayload(
      method: ETHRequestMethods.Sign.rawValue,
      params: [MockConstants.mockEip155Address, "test"]
    )
    let signature = LockedBox<String>()
    let failure = LockedBox<Error>()
    let completed = expectation(description: "deprecated request(payload:completion:)")

    provider.request(payload: payload) { result in
      if let error = result.error {
        failure.value = error
      }
      signature.value = result.data?.result as? String
      completed.fulfill()
    }

    await fulfillment(of: [completed], timeout: 2)

    XCTAssertNil(failure.value)
    XCTAssertEqual(signature.value, MockConstants.mockSignature)
    XCTAssertEqual(self.mobileSpy.mobileSignApiKeyParam, Self.sessionToken)
  }
}

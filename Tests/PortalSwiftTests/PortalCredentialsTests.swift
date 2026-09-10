//
//  PortalCredentialsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
@testable import PortalSwift
import UIKit
import XCTest

/// `Portal`'s credential surface: which credential it is built from, which instance it hands to
/// its subsystems, what the deprecated `apiKey` bridge reports, and the two session-lifecycle
/// entry points (`clearSession()` and `onSessionInvalidated(_:)`).
///
/// Every case runs against injected mocks, so nothing here touches the network, the Keychain or
/// the MPC binary. Two shared pieces of global state are reset around each case: the
/// `CredentialInvalidationRegistry`, whose "reported once ever" flags would otherwise leak from
/// one case into the next, and the `PortalLogger` sink, which every "never logs a secret"
/// assertion reads.
final class PortalCredentialsTests: XCTestCase {
  private var logger: RecordingLogger!

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger?.uninstall()
    self.logger = nil
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalLogger.shared.setLogLevel(.none)
    try super.tearDownWithError()
  }
}

// MARK: - Fixtures

private extension PortalCredentialsTests {
  /// A single non-Portal RPC entry, so nothing the provider does can reach a real host.
  static var rpcConfig: [String: String] {
    ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"]
  }

  /// A transport double primed with an encodable `ClientResponse`, which is what the eager
  /// `GET /clients/me` the initializer fires needs in order to reach the analytics calls.
  func makeSpy() throws -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(MockConstants.mockClient)
    return spy
  }

  /// The `PortalApi` every case injects: real API, real credential resolution, spied transport.
  func makeApi(_ credentials: PortalCredentials, spy: PortalRequestsSpy) -> PortalApi {
    PortalApi(credentials: credentials, apiHost: MockConstants.mockHost, requests: spy)
  }

  /// Builds the `Portal` under test from `credentials`.
  ///
  /// Pass `mpc: nil` to make `Portal` build the real `PortalMpc` — the only way to observe what
  /// the MPC layer was handed, since an injected mock is never given the credential at all.
  func buildPortal(
    credentials: PortalCredentials,
    spy: PortalRequestsSpy,
    api: PortalApiProtocol? = nil,
    mpc: PortalMpcProtocol? = MockPortalMpc(),
    keychain: PortalKeychainProtocol = MockPortalKeychain()
  ) throws -> Portal {
    try Portal(
      credentials: credentials,
      withRpcConfig: Self.rpcConfig,
      apiHost: MockConstants.mockHost,
      api: api ?? self.makeApi(credentials, spy: spy),
      binary: MockMobileWrapper(),
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: mpc,
      passwords: MockPasswordStorage()
    )
  }

  /// Builds the `Portal` under test from a Client API Key. The injected `PortalApi` wraps its own
  /// `StaticCredentials` because the key-taking initializer wraps the key itself.
  func buildPortal(
    apiKey: String,
    spy: PortalRequestsSpy,
    mpc: PortalMpcProtocol? = MockPortalMpc(),
    keychain: PortalKeychainProtocol = MockPortalKeychain()
  ) throws -> Portal {
    try Portal(
      apiKey,
      withRpcConfig: Self.rpcConfig,
      apiHost: MockConstants.mockHost,
      api: PortalApi(credentials: StaticCredentials(apiKey), apiHost: MockConstants.mockHost, requests: spy),
      binary: MockMobileWrapper(),
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: mpc,
      passwords: MockPasswordStorage()
    )
  }

  /// The backup options the deprecated initializer requires, all mocked.
  func makeBackupOptions() -> BackupOptions {
    BackupOptions(
      gdrive: MockGDriveStorage(),
      icloud: MockICloudStorage(),
      passwordStorage: MockPasswordStorage()
    )
  }

  /// Subscribes `portal` and returns the recorder together with its handle.
  func subscribe(_ portal: Portal) -> (recorder: SessionInvalidationRecorder, handle: PortalSessionInvalidationHandle) {
    let recorder = SessionInvalidationRecorder()
    let handle = portal.onSessionInvalidated { [weak recorder] in
      recorder?.record()
    }
    return (recorder, handle)
  }

  /// Waits for the eager `GET /clients/me` + identify + track the initializer fires, so a later
  /// assertion on request counts cannot race with work the constructor started.
  func waitForEagerInitRequests(_ spy: PortalRequestsSpy) async -> Bool {
    await waitUntil { spy.executeCallsCount >= 3 }
  }
}

// MARK: - Test doubles local to this file

/// Records deliveries of a `Portal.onSessionInvalidated(_:)` subscription.
///
/// The listener contract is "at most once, on the main actor", so both facts are counted here and
/// asserted from the same object. `onDeliver` runs after the counters are updated, which is how a
/// case makes the listener cancel its own handle from inside the callback.
private final class SessionInvalidationRecorder {
  private let lock = NSLock()
  private var _deliveries = 0
  private var _mainThreadDeliveries = 0
  private var _onDeliver: (() -> Void)?

  /// How many times the listener ran.
  var deliveries: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deliveries
  }

  /// How many deliveries observed `Thread.isMainThread`.
  var mainThreadDeliveries: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._mainThreadDeliveries
  }

  /// Runs inside the listener, after the delivery has been counted.
  var onDeliver: (() -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onDeliver
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onDeliver = newValue
    }
  }

  func record() {
    self.lock.lock()
    self._deliveries += 1
    if Thread.isMainThread {
      self._mainThreadDeliveries += 1
    }
    let hook = self._onDeliver
    self.lock.unlock()

    hook?()
  }
}

/// Observes when, and on which thread, the SDK resolved a credential.
///
/// A synchronous resolution inside `Portal.init` would show up as a `getToken()` on the
/// constructing thread before the initializer returned; anything the eager `Task` does happens
/// later and on a different thread. Recording the pair is what makes the distinction assertable
/// without a fixed sleep or a racy "count is still zero" read.
private final class TokenResolutionObserver {
  private let lock = NSLock()
  private let constructionThread: Thread
  private var _constructionFinished = false
  private var _resolvedDuringConstruction = false

  init(constructionThread: Thread) {
    self.constructionThread = constructionThread
  }

  /// `true` when a resolution happened on the constructing thread before it returned.
  var resolvedDuringConstruction: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._resolvedDuringConstruction
  }

  /// Called from the credential's `getToken()` hook.
  func record(thread: Thread) {
    self.lock.lock()
    if !self._constructionFinished, thread === self.constructionThread {
      self._resolvedDuringConstruction = true
    }
    self.lock.unlock()
  }

  /// Called immediately after the initializer returns.
  func constructionDidFinish() {
    self.lock.lock()
    self._constructionFinished = true
    self.lock.unlock()
  }
}

/// A one-shot failure switch for a storage hook that must fail the first call and succeed after.
private final class FailOnce {
  private let lock = NSLock()
  private var used = false

  /// `true` exactly once, for the first caller.
  func shouldFail() -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    if self.used {
      return false
    }
    self.used = true
    return true
  }
}

/// The error a stub `PortalProtocol` conformer throws from every operation it does not implement.
private enum StubPortalError: Error {
  case notImplemented
}

/// The smallest possible `PortalProtocol` conformer: it implements every requirement except
/// `clearSession()` and `onSessionInvalidated(_:)`, which is exactly what puts the protocol's
/// default implementations under test. A host that wrote its own wrapper before sessions existed
/// must still compile and must get the documented no-op / spent-handle behaviour.
private final class StubPortal: PortalProtocol {
  let api: PortalApiProtocol
  let provider: PortalProviderProtocol
  let autoApprove = false
  var gatewayConfig: [Int: String] = [:]
  var rpcConfig: [String: String] = [:]
  let apiKey = ""
  let chainId: Int? = nil
  let address: String? = nil

  lazy var yield: Yield = .init(api: self.api)
  lazy var ramps: Ramps = .init(api: self.api)
  lazy var trading: Trading = .init(api: self.api)
  lazy var security: Security = .init(api: self.api)
  lazy var delegations: DelegationsProtocol = Delegations(api: self.api.delegations)
  lazy var evmAccountType: EvmAccountTypeProtocol = EvmAccountType(api: self.api.evmAccountType, portal: nil)

  var addresses: [PortalNamespace: String?] {
    get async throws { throw StubPortalError.notImplemented }
  }

  var client: ClientResponse? {
    get async throws { throw StubPortalError.notImplemented }
  }

  init() throws {
    let credentials = MockCredentials()
    let keychain = MockPortalKeychain()
    self.api = MockPortalApi(credentials: credentials, requests: MockPortalRequests())
    self.provider = try PortalProvider(
      credentials: credentials,
      rpcConfig: [:],
      keychain: keychain,
      autoApprove: false,
      requests: MockPortalRequests()
    )
  }

  convenience init(
    _: String,
    withRpcConfig _: [String: String],
    autoApprove _: Bool,
    featureFlags _: FeatureFlags?,
    version _: String,
    apiHost _: String,
    mpcHost _: String,
    enclaveMPCHost _: String,
    api _: PortalApiProtocol?,
    binary _: Mobile?,
    gDrive _: GDriveStorage?,
    iCloud _: ICloudStorage?,
    keychain _: PortalKeychainProtocol?,
    mpc _: PortalMpcProtocol?,
    passwords _: PasswordStorage?,
    maxPresignaturesPerCurve _: [PresignatureSupportedCurve: Int]
  ) throws {
    try self.init()
  }

  convenience init(
    apiKey _: String,
    backup _: BackupOptions,
    chainId _: Int,
    keychain _: PortalKeychainProtocol,
    gatewayConfig _: [Int: String],
    isSimulator _: Bool,
    version _: String,
    autoApprove _: Bool,
    apiHost _: String,
    mpcHost _: String,
    featureFlags _: FeatureFlags?
  ) throws {
    try self.init()
  }

  func setLogLevel(_: PortalLogLevel) {}
  func registerBackupMethod(_: BackupMethods, withStorage _: PortalStorage) {}
  func setGDriveConfiguration(clientId _: String, backupOption _: GDriveBackupOption) throws { throw StubPortalError.notImplemented }
  func setGDriveView(_: UIViewController) throws { throw StubPortalError.notImplemented }
  @available(iOS 16, *)
  func setPasskeyAuthenticationAnchor(_: ASPresentationAnchor) throws { throw StubPortalError.notImplemented }
  @available(iOS 16, *)
  func setPasskeyConfiguration(relyingParty _: String, webAuthnHost _: String) throws { throw StubPortalError.notImplemented }
  func setPassword(_: String) throws { throw StubPortalError.notImplemented }
  func backupWallet(_: BackupMethods, usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> (cipherText: String, storageCallback: () async throws -> Void) { throw StubPortalError.notImplemented }
  func createWallet(usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> PortalCreateWalletResponse { throw StubPortalError.notImplemented }
  func createSolanaWallet(usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> String { throw StubPortalError.notImplemented }
  func eject(_: BackupMethods, withCipherText _: String?, andOrganizationBackupShare _: String?) async throws -> String { throw StubPortalError.notImplemented }
  func ejectPrivateKeys(_: BackupMethods, withCipherText _: String?, andOrganizationBackupShare _: String?, andOrganizationSolanaBackupShare _: String?) async throws -> [PortalNamespace: String] { throw StubPortalError.notImplemented }
  func recoverWallet(_: BackupMethods, withCipherText _: String?, usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> PortalRecoverWalletResponse { throw StubPortalError.notImplemented }
  func generateSolanaWalletAndBackupShares(_: BackupMethods, usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> (solanaAddress: String, cipherText: String, storageCallback: () async throws -> Void) { throw StubPortalError.notImplemented }
  func deleteShares() async throws { throw StubPortalError.notImplemented }
  func getAddress(_: String) async -> String? { nil }
  func getAddresses() async throws -> [PortalNamespace: String?] { throw StubPortalError.notImplemented }
  func emit(_: Events, data _: Any) {}
  func on(event _: Events, callback _: @escaping (Any) -> Void) {}
  func once(event _: Events, callback _: @escaping (Any) -> Void) {}
  func request(chainId _: String, method _: PortalRequestMethod, params _: [Any], options _: RequestOptions?) async throws -> PortalProviderResult { throw StubPortalError.notImplemented }
  func getRpcUrl(forChainId _: String) async -> String? { nil }
  func availableRecoveryMethods(_: String?) async throws -> [BackupMethods] { throw StubPortalError.notImplemented }
  func doesWalletExist(_: String?) async throws -> Bool { throw StubPortalError.notImplemented }
  func isWalletBackedUp(_: String?) async throws -> Bool { throw StubPortalError.notImplemented }
  func isWalletOnDevice(_: String?) async throws -> Bool { throw StubPortalError.notImplemented }
  func isWalletRecoverable(_: String?) async throws -> Bool { throw StubPortalError.notImplemented }
  func getBalances(_: String) async throws -> [FetchedBalance] { throw StubPortalError.notImplemented }
  func getAssets(_: String) async throws -> AssetsResponse { throw StubPortalError.notImplemented }
  func getBackupShares(_: String?) async throws -> [FetchedSharePair] { throw StubPortalError.notImplemented }
  func getNftAssets(_: String) async throws -> [NftAsset] { throw StubPortalError.notImplemented }
  func getSigningShares(_: String?) async throws -> [FetchedSharePair] { throw StubPortalError.notImplemented }
  func getTransactions(_: String, limit _: Int?, offset _: Int?, order _: TransactionOrder?) async throws -> [FetchedTransaction] { throw StubPortalError.notImplemented }
  func getTransactionDetails(chain _: String, signature _: String) async throws -> GetTransactionDetailsResponse { throw StubPortalError.notImplemented }
  func evaluateTransaction(chainId _: String, transaction _: EvaluateTransactionParam, operationType _: EvaluateTransactionOperationType?) async throws -> BlockaidValidateTrxRes { throw StubPortalError.notImplemented }
  func buildEip155Transaction(chainId _: String, params _: BuildTransactionParam) async throws -> BuildEip115TransactionResponse { throw StubPortalError.notImplemented }
  func buildSolanaTransaction(chainId _: String, params _: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse { throw StubPortalError.notImplemented }
  func buildBitcoinP2wpkhTransaction(chainId _: String, params _: BuildTransactionParam) async throws -> BuildBitcoinP2wpkhTransactionResponse { throw StubPortalError.notImplemented }
  func broadcastBitcoinP2wpkhTransaction(chainId _: String, params _: BroadcastParam) async throws -> BroadcastBitcoinP2wpkhTransactionResponse { throw StubPortalError.notImplemented }
  func getWalletCapabilities() async throws -> WalletCapabilitiesResponse { throw StubPortalError.notImplemented }
  func provisionWallet(cipherText _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, completion _: @escaping (PortalSwift.Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}
  func rawSign(message _: String, chainId _: String, signatureApprovalMemo _: String?, traceId _: String?) async throws -> PortalProviderResult { throw StubPortalError.notImplemented }
  func createPortalConnectInstance(webSocketServer _: String) throws -> PortalConnect { throw StubPortalError.notImplemented }
  func receiveTestnetAsset(chainId _: String, params _: FundParams) async throws -> FundResponse { throw StubPortalError.notImplemented }
  func sendAsset(chainId _: String, params _: SendAssetParams) async throws -> SendAssetResponse { throw StubPortalError.notImplemented }
  func updateChain(newChainId _: String) {}
  func gDriveSignOut() throws { throw StubPortalError.notImplemented }
  func request(method _: ETHRequestMethods.RawValue, params _: [Any], completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func setGDriveConfiguration(clientId _: String, folderName _: String) throws { throw StubPortalError.notImplemented }
  func simulateTransaction(_: String, from _: Any) async throws -> SimulatedTransaction { throw StubPortalError.notImplemented }
  func backupWallet(method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, completion _: @escaping (PortalSwift.Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}
  func createWallet(completion _: @escaping (PortalSwift.Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}
  func recoverWallet(cipherText _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, completion _: @escaping (PortalSwift.Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}
  func ejectPrivateKey(clientBackupCiphertext _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, orgBackupShare _: String, completion _: @escaping (PortalSwift.Result<String>) -> Void) {}
  func request(_: String, withMethod _: PortalRequestMethod, andParams _: [Any]?) async throws -> PortalProviderResult { throw StubPortalError.notImplemented }
  func request(_: String, withMethod _: String, andParams _: [Any]) async throws -> PortalProviderResult { throw StubPortalError.notImplemented }
  func setChainId(to _: Int) throws { throw StubPortalError.notImplemented }
  func deleteAddress() throws { throw StubPortalError.notImplemented }
  func deleteSigningShare() throws { throw StubPortalError.notImplemented }
  func sendSol(_: UInt64, to _: String, withChainId _: String) async throws -> String { throw StubPortalError.notImplemented }
  func emit(_: Events.RawValue, data _: Any) {}
  func on(event _: Events.RawValue, callback _: @escaping (Any) -> Void) {}
  func once(event _: Events.RawValue, callback _: @escaping (Any) -> Void) {}
  func ethEstimateGas(transaction _: ETHTransactionParam, completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func ethGasPrice(completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func ethGetBalance(completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func ethSendTransaction(transaction _: ETHTransactionParam, completion _: @escaping (PortalSwift.Result<TransactionCompletionResult>) -> Void) {}
  func ethSign(message _: String, completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func ethSignTransaction(transaction _: ETHTransactionParam, completion _: @escaping (PortalSwift.Result<TransactionCompletionResult>) -> Void) {}
  func ethSignTypedDataV3(message _: String, completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func ethSignTypedData(message _: String, completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func personalSign(message _: String, completion _: @escaping (PortalSwift.Result<RequestCompletionResult>) -> Void) {}
  func request(_: String, withMethod _: PortalRequestMethod, andParams _: [Any], signatureApprovalMemo _: String?) async throws -> PortalProviderResult { throw StubPortalError.notImplemented }
}

// MARK: - init: credential resolution

extension PortalCredentialsTests {
  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_init_willExposeApiKeyUnchanged_whenBuiltWithApiKey() throws {
    let spy = try makeSpy()

    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)

    XCTAssertEqual(portal.apiKey, MockConstants.mockApiKey)
    let credentials = try XCTUnwrap(portal.credentials as? StaticCredentials, "A Client API Key must be wrapped in StaticCredentials.")
    XCTAssertEqual(credentials.value, MockConstants.mockApiKey)
  }

  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_initCredentials_willReportEmptyApiKey() throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()

    let portal = try buildPortal(credentials: credentials, spy: spy)

    XCTAssertEqual(portal.apiKey, "", "The bridge must report the absence of a static key, never a session token.")
    XCTAssertNotEqual(portal.apiKey, "session-token")
  }

  func test_initCredentials_willShareSuppliedInstance() throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()

    let portal = try buildPortal(credentials: credentials, spy: spy)

    XCTAssertTrue(portal.credentials === credentials, "Portal must share the host's credential, not copy its token.")
  }

  func test_initCredentials_willHandSameInstanceToApiProviderAndMpc() async throws {
    let credentials = MockCredentials(tokenValue: "shared-token")
    let spy = try makeSpy()
    let api = makeApi(credentials, spy: spy)
    // `mpc: nil` builds the real `PortalMpc`; an injected mock is never handed the credential at all.
    let portal = try buildPortal(credentials: credentials, spy: spy, api: api, mpc: nil)

    _ = try await portal.api.getClient()
    XCTAssertTrue(api.credentials === credentials)

    let provider = try XCTUnwrap(portal.provider as? PortalProvider)
    XCTAssertTrue(provider.credentials === credentials)
    _ = try PortalCredentialSupport.resolveToken(provider.credentials)

    // Registering a storage is the one public route into the private `PortalMpc`, and the MPC layer
    // stamps its own credential onto every storage that calls Portal itself.
    let firebase = MockFirebaseStorage()
    portal.registerBackupMethod(.Firebase, withStorage: firebase)
    let mpcCredentials = try XCTUnwrap(firebase.credentials, "PortalMpc must hand its credential to a Firebase storage.")
    XCTAssertTrue(mpcCredentials === credentials)
    _ = try PortalCredentialSupport.resolveToken(mpcCredentials)

    XCTAssertGreaterThanOrEqual(credentials.getTokenCalls, 3)
    XCTAssertFalse(spy.bearerTokensSent.isEmpty)
    for bearer in spy.bearerTokensSent {
      XCTAssertEqual(bearer, "shared-token")
    }
  }

  func test_init_willThrowInvalidApiKey_whenApiKeyIsEmpty() throws {
    let spy = try makeSpy()

    XCTAssertThrowsError(try buildPortal(apiKey: "", spy: spy)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
  }

  func test_init_willThrowInvalidApiKey_whenApiKeyIsWhitespace() throws {
    let spy = try makeSpy()

    XCTAssertThrowsError(try buildPortal(apiKey: "  \n", spy: spy)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
  }

  func test_init_willRejectInvalidCredentialsBeforeAnyConstructionWork() async throws {
    let spy = try makeSpy()
    let keychain = MockPortalKeychain()
    let api = makeApi(StaticCredentials(MockConstants.mockApiKey), spy: spy)

    XCTAssertThrowsError(
      try Portal(
        "",
        withRpcConfig: Self.rpcConfig,
        apiHost: MockConstants.mockHost,
        api: api,
        binary: MockMobileWrapper(),
        gDrive: MockGDriveStorage(),
        iCloud: MockICloudStorage(),
        keychain: keychain,
        mpc: MockPortalMpc(),
        passwords: MockPasswordStorage()
      )
    ) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }

    let sentARequest = await waitUntil(timeout: 0.2) { spy.executeCallsCount > 0 }
    XCTAssertFalse(sentARequest, "A rejected credential must not start the eager client fetch.")
    XCTAssertNil(keychain.api, "A rejected credential must leave the object graph unbuilt.")
  }

  func test_init_willStillThrowVersionError_whenVersionUnsupported() throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let api = makeApi(credentials, spy: spy)

    XCTAssertThrowsError(
      try Portal(
        credentials: credentials,
        withRpcConfig: Self.rpcConfig,
        version: "v5",
        apiHost: MockConstants.mockHost,
        api: api,
        binary: MockMobileWrapper(),
        gDrive: MockGDriveStorage(),
        iCloud: MockICloudStorage(),
        keychain: MockPortalKeychain(),
        mpc: MockPortalMpc(),
        passwords: MockPasswordStorage()
      )
    ) { error in
      guard let argumentError = error as? PortalArgumentError, case .versionNoLongerSupported = argumentError else {
        XCTFail("Expected versionNoLongerSupported but a \(type(of: error)) was thrown.")
        return
      }
    }
  }

  func test_initCredentials_willAcceptAllDefaultArguments() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let api = makeApi(credentials, spy: spy)

    let portal = try Portal(
      credentials: credentials,
      api: api,
      keychain: MockPortalKeychain(),
      mpc: MockPortalMpc()
    )

    XCTAssertFalse(portal.rpcConfig.isEmpty, "An omitted rpcConfig must fall back to the default set.")
    XCTAssertEqual(portal.rpcConfig["eip155:1"], "https://api.portalhq.io/rpc/v1/eip155/1")
    XCTAssertEqual(portal.rpcConfig["eip155:11155111"], "https://api.portalhq.io/rpc/v1/eip155/11155111")
    XCTAssertTrue(portal.credentials === credentials)
    _ = await waitUntil { spy.executeCallsCount >= 1 }
  }

  func test_initCredentials_willWireUnauthorizedHookOntoDefaultTransport() throws {
    let credentials = MockCredentials(tokenValue: "session-token")

    // `api` is left nil so Portal builds a real PortalApi over a real PortalRequests. The host is a
    // closed local port, so the eager fetch fails immediately instead of reaching the network.
    let portal = try Portal(
      credentials: credentials,
      withRpcConfig: Self.rpcConfig,
      apiHost: "localhost:9",
      binary: MockMobileWrapper(),
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: MockPortalKeychain(),
      mpc: MockPortalMpc(),
      passwords: MockPasswordStorage()
    )

    let api = try XCTUnwrap(portal.api as? PortalApi)
    let reporting = try XCTUnwrap(api.requests as? PortalUnauthorizedReporting, "PortalRequests must report 401s.")
    XCTAssertNotNil(reporting.onUnauthorized, "The default transport must carry a 401 hook.")

    reporting.onUnauthorized?(nil)

    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_initCredentials_willWireUnauthorizedHookOntoCallerSuppliedTransport() throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let api = makeApi(credentials, spy: spy)

    let portal = try buildPortal(credentials: credentials, spy: spy, api: api)

    XCTAssertNotNil(spy.onUnauthorized)
    XCTAssertEqual(spy.onUnauthorizedSetCount, 1, "Portal must not replace a hook the API already installed.")

    spy.onUnauthorized?(nil)

    XCTAssertEqual(credentials.invalidateCalls, 1)
    XCTAssertTrue(portal.credentials === credentials)
  }

  func test_init_willNotResolveTokenSynchronouslyDuringConstruction() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let observer = TokenResolutionObserver(constructionThread: Thread.current)
    credentials.onGetToken = { [weak observer] in
      observer?.record(thread: Thread.current)
    }

    let portal = try buildPortal(credentials: credentials, spy: spy)
    observer.constructionDidFinish()

    // A "getTokenCalls == 0 right after init" read would race the eager Task, which may already
    // have run on another thread; the thread-and-phase observation is the non-racy form of the
    // same claim.
    XCTAssertFalse(observer.resolvedDuringConstruction, "Construction must not resolve the credential inline.")
    let resolvedLater = await waitUntil { credentials.getTokenCalls >= 1 }
    XCTAssertTrue(resolvedLater, "The eager Task must resolve the credential after construction returned.")
    XCTAssertFalse(observer.resolvedDuringConstruction)
    XCTAssertTrue(portal.credentials === credentials)
  }

  func test_init_willSendCredentialTokenOnEagerClientFetch() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()

    let portal = try buildPortal(credentials: credentials, spy: spy)

    let fetched = await waitUntil { spy.executeCallsCount >= 1 }
    XCTAssertTrue(fetched, "Construction must eagerly fetch the client.")
    let first = try XCTUnwrap(spy.executeRequestHistory.first)
    XCTAssertEqual(first.url.path, "/api/v3/clients/me")
    XCTAssertEqual(first.headers["Authorization"], "Bearer session-token")
    XCTAssertTrue(portal.credentials === credentials)
  }

  func test_init_willSendApiKeyOnAnalyticsIdentifyAndTrack() async throws {
    let spy = try makeSpy()

    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)

    let reported = await waitForEagerInitRequests(spy)
    XCTAssertTrue(reported, "Construction must identify and track after the client fetch.")
    let identify = try XCTUnwrap(spy.executeRequestHistory.first { $0.url.path == "/api/v1/analytics/identify" })
    XCTAssertEqual(identify.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
    let track = try XCTUnwrap(spy.executeRequestHistory.first { $0.url.path == "/api/v1/analytics/track" })
    XCTAssertEqual(track.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
    XCTAssertNotNil(portal.rpcConfig["eip155:11155111"])
  }

  func test_init_willFireOnSessionInvalidated_whenEagerClientFetchReturns401() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    spy.simulatePortalUnauthorizedOnce = true

    // Hold the eager fetch at the credential boundary until the subscription is in place, so
    // this case pins the live delivery; the late-subscriber replay is pinned separately below.
    let gate = DispatchSemaphore(value: 0)
    credentials.onGetToken = { [weak credentials] in
      guard credentials?.getTokenCalls == 1 else {
        return
      }
      _ = gate.wait(timeout: .now() + 2)
    }

    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, handle) = subscribe(portal)
    gate.signal()

    let fired = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(fired, "A 401 on the eager fetch must reach the host.")
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1)
    XCTAssertFalse(handle === PortalSessionInvalidationHandle.spent)
  }

  func test_init_willNotFireOnSessionInvalidated_whenEagerClientFetchReturns500() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.internalServerError("500 - Internal Server Error", url: "https://\(MockConstants.mockHost)/api/v3/clients/me")
    ]

    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, _) = subscribe(portal)

    let requested = await waitUntil { spy.executeCallsCount >= 1 }
    XCTAssertTrue(requested)
    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired, "A 500 is not a rejected credential.")
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_init_willNotInvalidateApiKeyPortal_whenEagerClientFetchReturns401() async throws {
    let spy = try makeSpy()
    spy.simulatePortalUnauthorizedOnce = true

    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)
    let (recorder, handle) = subscribe(portal)

    XCTAssertTrue(handle === PortalSessionInvalidationHandle.spent, "A Client API Key has no session to end.")
    let requested = await waitUntil { spy.executeCallsCount >= 1 }
    XCTAssertTrue(requested)
    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired)
    XCTAssertEqual(portal.apiKey, MockConstants.mockApiKey)
    XCTAssertEqual(try portal.credentials.getToken(), MockConstants.mockApiKey)
  }

  @available(*, deprecated, message: "Exercises the deprecated initializer and apiKey bridge on purpose.")
  func test_deprecatedInit_willWrapApiKeyInStaticCredentials() throws {
    let portal = try Portal(
      apiKey: MockConstants.mockApiKey,
      backup: makeBackupOptions(),
      chainId: 11_155_111,
      keychain: MockPortalKeychain(),
      gatewayConfig: [11_155_111: "https://\(MockConstants.mockHost)/test-rpc"],
      apiHost: "localhost:9",
      mpcHost: "localhost:9"
    )

    let credentials = try XCTUnwrap(portal.credentials as? StaticCredentials)
    XCTAssertEqual(credentials.value, MockConstants.mockApiKey)
    XCTAssertEqual(portal.apiKey, MockConstants.mockApiKey)
  }

  @available(*, deprecated, message: "Exercises the deprecated initializer on purpose.")
  func test_deprecatedInit_willThrowInvalidApiKey_whenApiKeyBlank() throws {
    XCTAssertThrowsError(
      try Portal(
        apiKey: "",
        backup: makeBackupOptions(),
        chainId: 11_155_111,
        keychain: MockPortalKeychain(),
        gatewayConfig: [11_155_111: "https://\(MockConstants.mockHost)/test-rpc"],
        apiHost: "localhost:9",
        mpcHost: "localhost:9"
      )
    ) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
  }
}

// MARK: - clearSession()

extension PortalCredentialsTests {
  func test_clearSession_willEndSessionAndDropPersistedCopy() async throws {
    let storage = MockAuthSessionStorage(stored: AuthTestFixtures.persistedSession(token: "session-token", endUserId: "user-1"))
    let session = KeychainPortalSession(clientSessionToken: "session-token", endUserId: "user-1", storage: storage)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: session, spy: spy)

    try await portal.clearSession()

    XCTAssertNil(storage.stored, "Signing out must drop the persisted copy.")
    XCTAssertEqual(storage.deleteIfCurrentCalls, 1)
    XCTAssertThrowsError(try session.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
  }

  func test_clearSession_willLeaveEveryLaterCallReportingReauthentication() async throws {
    let storage = MockAuthSessionStorage(stored: AuthTestFixtures.persistedSession(token: "session-token", endUserId: "user-1"))
    let session = KeychainPortalSession(clientSessionToken: "session-token", endUserId: "user-1", storage: storage)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: session, spy: spy)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")

    try await portal.clearSession()
    let before = spy.executeCallsCount

    await XCTAssertThrowsAsync(try await portal.api.getClient()) { error in
      guard let credentialError = error as? PortalCredentialError else {
        XCTFail("Expected a PortalCredentialError but a \(type(of: error)) was thrown.")
        return
      }
      XCTAssertEqual(credentialError, .sessionInvalidated)
      XCTAssertTrue(credentialError.requiresReauthentication)
    }

    XCTAssertEqual(spy.executeCallsCount, before, "A spent credential must fail before anything reaches the wire.")
  }

  func test_clearSession_willRouteThroughCredentialInvalidate() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)

    try await portal.clearSession()

    XCTAssertEqual(credentials.invalidateCalls, 1, "clearSession must delegate to the credential, not reimplement it.")
  }

  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_clearSession_willBeNoOp_onApiKeyPortal() async throws {
    let spy = try makeSpy()
    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")

    try await portal.clearSession()

    XCTAssertEqual(portal.apiKey, MockConstants.mockApiKey)
    XCTAssertEqual(try portal.credentials.getToken(), MockConstants.mockApiKey)

    let before = spy.executeCallsCount
    _ = try await portal.api.getClient()
    XCTAssertEqual(spy.executeCallsCount, before + 1)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_clearSession_willBeIdempotent() async throws {
    let storage = MockAuthSessionStorage(stored: AuthTestFixtures.persistedSession(token: "session-token", endUserId: "user-1"))
    let session = KeychainPortalSession(clientSessionToken: "session-token", endUserId: "user-1", storage: storage)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: session, spy: spy)

    try await portal.clearSession()
    try await portal.clearSession()
    try await portal.clearSession()

    XCTAssertEqual(storage.deleteIfCurrentCalls, 1, "Only the first sign-out has anything to delete.")
    XCTAssertNil(storage.stored)
  }

  func test_clearSession_willCoalesceConcurrentCallersIntoOneInvalidation() async throws {
    let credentials = SessionLikeCredentials(onInvalidate: {
      // Widen the check-then-act window so two unserialised callers would both delete.
      Thread.sleep(forTimeInterval: 0.02)
    })
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)

    async let first: Void = portal.clearSession()
    async let second: Void = portal.clearSession()
    _ = try await (first, second)

    XCTAssertEqual(credentials.storageDeletes, 1, "Overlapping sign-outs must produce one storage delete.")
    XCTAssertEqual(credentials.invalidateCalls, 2)
    XCTAssertEqual(credentials.maxConcurrentCallers, 1, "Invalidation must be serialised per credential.")
  }

  func test_clearSession_willThrow_whenPersistedCopyCannotBeDeleted() async throws {
    let raw = AuthTestFixtures.persistedSession(token: "session-token", endUserId: "user-1")
    let storage = MockAuthSessionStorage(stored: raw)
    let failure = FailOnce()
    storage.onDeleteIfCurrent = { _ in
      guard failure.shouldFail() else {
        return
      }
      throw NSError(domain: "PortalCredentialsTests.keychain", code: -25300)
    }
    let session = KeychainPortalSession(clientSessionToken: "session-token", endUserId: "user-1", storage: storage)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: session, spy: spy)

    await XCTAssertThrowsAsync(try await portal.clearSession()) { error in
      guard let authError = error as? PortalAuthError, case .sessionStorageFailure = authError else {
        XCTFail("Expected sessionStorageFailure but a \(type(of: error)) was thrown.")
        return
      }
    }

    XCTAssertEqual(storage.stored, raw, "A failed delete must leave the persisted copy in place.")
    XCTAssertThrowsError(try session.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "The in-memory token is dropped before the delete is attempted.")
    }
  }

  func test_clearSession_willSpareSessionPersistedByNewerLogin() async throws {
    let storage = MockAuthSessionStorage(stored: AuthTestFixtures.persistedSession(token: "old", endUserId: "user-1"))
    let session = KeychainPortalSession(clientSessionToken: "old", endUserId: "user-1", storage: storage)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: session, spy: spy)
    // A newer login re-keys the slot behind the stale session's back.
    try storage.set(AuthTestFixtures.persistedSession(token: "new", endUserId: "user-2"))

    try await portal.clearSession()

    XCTAssertEqual(storage.storedSession, PersistedSession(clientSessionToken: "new", endUserId: "user-2"))
  }

  func test_clearSession_willNotFireOnSessionInvalidated() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, _) = subscribe(portal)

    try await portal.clearSession()

    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired, "A host-initiated sign-out is not news to the host.")
    XCTAssertEqual(recorder.deliveries, 0)
  }

  func test_clearSession_willNotSendAnyRequest() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")
    let before = spy.executeCallsCount

    try await portal.clearSession()

    let sent = await waitUntil(timeout: 0.3) { spy.executeCallsCount > before }
    XCTAssertFalse(sent, "Sign-out is local; there is no logout endpoint.")
  }
}

// MARK: - onSessionInvalidated(_:)

extension PortalCredentialsTests {
  func test_onSessionInvalidated_willFire_whenBackendRejectsCredential() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, _) = subscribe(portal)

    spy.onUnauthorized?(nil)

    let fired = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(fired, "A rejected credential must reach the host.")
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_onSessionInvalidated_willFireOnce_whenManyRequests401() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, _) = subscribe(portal)

    spy.onUnauthorized?(nil)
    spy.onUnauthorized?(nil)

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be notified exactly once.")
    let firedTwice = await waitUntil(timeout: 0.3) { recorder.deliveries > 1 }
    XCTAssertFalse(firedTwice, "The host is told once, however many requests are rejected.")
  }

  func test_onSessionInvalidated_willFireOnce_whenTwoTransportsReportConcurrently() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let apiSpy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: apiSpy)
    // A second SDK object on the same credential (in production, the provider's transport) wires its
    // own hook, so both can report the same rejection at the same moment.
    let providerSpy = try makeSpy()
    _ = makeApi(credentials, spy: providerSpy)
    let (recorder, _) = subscribe(portal)

    try runConcurrently(2) { index in
      if index == 0 {
        apiSpy.onUnauthorized?(nil)
      } else {
        providerSpy.onUnauthorized?(nil)
      }
    }

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be notified exactly once.")
    let firedTwice = await waitUntil(timeout: 0.3) { recorder.deliveries > 1 }
    XCTAssertFalse(firedTwice)
    XCTAssertGreaterThanOrEqual(credentials.invalidateCalls, 1)
  }

  func test_onSessionInvalidated_willStop_afterCancel() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, handle) = subscribe(portal)

    handle.cancel()
    spy.onUnauthorized?(nil)

    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired, "A cancelled subscription must not deliver.")
    XCTAssertEqual(recorder.deliveries, 0)
  }

  func test_onSessionInvalidated_willNotifyEverySubscriber() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (first, _) = subscribe(portal)
    let (second, _) = subscribe(portal)

    spy.onUnauthorized?(nil)

    let delivered = await waitUntil { first.deliveries == 1 && second.deliveries == 1 }
    XCTAssertTrue(delivered, "Every subscriber must be notified.")
    XCTAssertEqual(first.deliveries, 1)
    XCTAssertEqual(second.deliveries, 1)
  }

  func test_onSessionInvalidated_willNeverFire_onApiKeyPortal() async throws {
    let spy = try makeSpy()
    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)
    let (recorder, handle) = subscribe(portal)

    XCTAssertTrue(handle === PortalSessionInvalidationHandle.spent, "A Client API Key can never be reported.")
    spy.onUnauthorized?(nil)

    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired)
  }

  func test_onSessionInvalidated_willReplayRejection_forLateSubscriber() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)

    // The rejection is reported before anyone subscribes — the eager client fetch in `init` can
    // come back 401 before the host's next line runs. The late subscriber is told once anyway.
    spy.onUnauthorized?(nil)
    let (recorder, handle) = subscribe(portal)

    let fired = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(fired, "A subscriber that arrives after the rejection must still learn the session ended")
    XCTAssertEqual(recorder.mainThreadDeliveries, 1, "Replayed on the main actor like a live delivery")
    XCTAssertFalse(handle === PortalSessionInvalidationHandle.spent, "The replay is cancellable, so it hands back a live handle")
    let firedAgain = await waitUntil(timeout: 0.3) { recorder.deliveries > 1 }
    XCTAssertFalse(firedAgain, "Replayed at most once")
  }

  func test_onSessionInvalidated_willLeavePortalOnDifferentSessionUnaffected() async throws {
    let spentCredentials = MockCredentials(tokenValue: "spent-token")
    let freshCredentials = MockCredentials(tokenValue: "fresh-token")
    let spentSpy = try makeSpy()
    let freshSpy = try makeSpy()
    let spentPortal = try buildPortal(credentials: spentCredentials, spy: spentSpy)
    let freshPortal = try buildPortal(credentials: freshCredentials, spy: freshSpy)
    let (onSpent, _) = subscribe(spentPortal)
    let (onFresh, _) = subscribe(freshPortal)

    spentSpy.onUnauthorized?(nil)

    let delivered = await waitUntil { onSpent.deliveries == 1 }
    XCTAssertTrue(delivered, "The Portal whose session was rejected must be notified.")
    let freshFired = await waitUntil(timeout: 0.3) { onFresh.deliveries > 0 }
    XCTAssertFalse(freshFired, "Invalidation is per credential, not per process.")
    XCTAssertEqual(freshCredentials.invalidateCalls, 0)
  }

  func test_onSessionInvalidated_willDeliverOnMainActor() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, _) = subscribe(portal)

    DispatchQueue.global(qos: .userInitiated).async {
      spy.onUnauthorized?(nil)
    }

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be notified exactly once.")
    XCTAssertEqual(recorder.mainThreadDeliveries, 1, "The listener is @MainActor however the 401 arrived.")
  }

  func test_onSessionInvalidated_willAllowCancelFromInsideListener() async throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let (recorder, handle) = subscribe(portal)
    recorder.onDeliver = { handle.cancel() }

    spy.onUnauthorized?(nil)

    let fired = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(fired, "Cancelling from inside the listener must not deadlock it.")
    XCTAssertEqual(recorder.deliveries, 1)
  }

  func test_onSessionInvalidated_willFire_whenLiveRequestReturns401ThroughSpy() async throws {
    let credentials = SessionLikeCredentials(token: "session-token", throwsWhenInvalidated: true)
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")

    let (recorder, _) = subscribe(portal)
    spy.simulatePortalUnauthorizedOnce = true

    await XCTAssertThrowsAsync(try await portal.api.getClient()) { error in
      XCTAssertEqual(error as? PortalRequestsError, .unauthorized, "The rejected call still rethrows the raw transport error.")
    }

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be notified exactly once.")

    let before = spy.executeCallsCount
    await XCTAssertThrowsAsync(try await portal.api.getClient()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "Later calls fail at the credential boundary.")
    }
    XCTAssertEqual(spy.executeCallsCount, before, "A spent session sends nothing.")
  }
}

// MARK: - apiKey bridge, Portal Connect and the PortalProtocol defaults

extension PortalCredentialsTests {
  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_apiKey_willNotExposeSessionToken_evenAfterRequests() async throws {
    let credentials = MockCredentials(tokenValue: "SECRET-SESSION-TOKEN")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")

    _ = try await portal.api.getClient()
    _ = try await portal.api.getClient()

    XCTAssertEqual(portal.apiKey, "", "The bridge must never start reporting the session token.")
  }

  func test_createPortalConnectInstance_willShareCredentials() throws {
    let credentials = MockCredentials(tokenValue: "session-token")
    let spy = try makeSpy()
    let portal = try buildPortal(credentials: credentials, spy: spy)

    let connect = try portal.createPortalConnectInstance(webSocketServer: "localhost:9")

    XCTAssertTrue(connect.credentials === credentials, "Portal Connect must share the Portal's credential instance.")
  }

  func test_PortalProtocol_clearSession_defaultImplementation_willNotThrow() async throws {
    let conformer: PortalProtocol = try StubPortal()

    try await conformer.clearSession()
  }

  func test_PortalProtocol_onSessionInvalidated_defaultImplementation_willReturnSpent() async throws {
    let conformer: PortalProtocol = try StubPortal()
    let recorder = SessionInvalidationRecorder()

    let handle = conformer.onSessionInvalidated { [weak recorder] in
      recorder?.record()
    }

    XCTAssertTrue(handle === PortalSessionInvalidationHandle.spent)
    handle.cancel()
    let fired = await waitUntil(timeout: 0.3) { recorder.deliveries > 0 }
    XCTAssertFalse(fired, "A conformer without a session has nothing to report.")
  }

  @available(*, deprecated, message: "Reads the deprecated apiKey bridge on purpose.")
  func test_PortalProtocol_apiKey_willRemainRequirement() throws {
    let spy = try makeSpy()
    let portal = try buildPortal(apiKey: MockConstants.mockApiKey, spy: spy)

    let asProtocol: PortalProtocol = portal
    XCTAssertEqual(asProtocol.apiKey, MockConstants.mockApiKey)

    let stub: PortalProtocol = try StubPortal()
    XCTAssertEqual(stub.apiKey, "")
  }

  func test_init_willNeverLogCredential() async throws {
    PortalLogger.shared.setLogLevel(.debug)
    let credentials = MockCredentials(tokenValue: "SECRET-CST")
    let spy = try makeSpy()

    let portal = try buildPortal(credentials: credentials, spy: spy)
    portal.setLogLevel(.debug)
    let eagerRequestsFinished = await waitForEagerInitRequests(spy)
    XCTAssertTrue(eagerRequestsFinished, "The eager init requests must finish before the assertion below.")
    _ = try? await portal.api.getClient()

    logger.assertNoSecret("SECRET-CST")
    logger.assertNoSecret(MockConstants.mockApiKey)
  }
}

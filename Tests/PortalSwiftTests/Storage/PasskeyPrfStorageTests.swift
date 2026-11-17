//
//  PasskeyPrfStorageTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import CryptoKit
@testable import PortalSwift
import XCTest

// MARK: - Fixtures

enum PasskeyPrfFixtures {
  static let createdOutput = Data(repeating: 0xAB, count: 32)
  static let assertedOutput = Data((0 ..< 32).map { UInt8($0) })
  static let createdCredentialId = Data([0x01, 0x02, 0x03, 0xFB, 0xFF])
  static let serverCredentialId = Data([0x09, 0x08, 0x07])
}

// MARK: - Doubles

/// Records the ceremonies `PasskeyPrfStorage` asks for and answers them from queued results.
final class PasskeyPrfWebAuthnClientFake: PasskeyPrfWebAuthnClient {
  var anchor: ASPresentationAnchor?

  var createRequests: [PasskeyPrfCreateRequest] = []
  var createResults: [Swift.Result<PasskeyPrfCreateResult, Error>] = []
  var getRequests: [PasskeyPrfGetRequest] = []
  var getResults: [Swift.Result<PasskeyPrfGetResult, Error>] = []

  func createCredential(_ request: PasskeyPrfCreateRequest) async throws -> PasskeyPrfCreateResult {
    createRequests.append(request)
    return try createResults.removeFirst().get()
  }

  func getCredential(_ request: PasskeyPrfGetRequest) async throws -> PasskeyPrfGetResult {
    getRequests.append(request)
    guard !getResults.isEmpty else {
      // Answer with the requested credential by default.
      return PasskeyPrfGetResult(credentialId: request.allowCredentialId, prfOutput: PasskeyPrfFixtures.assertedOutput)
    }
    return try getResults.removeFirst().get()
  }
}

/// A password cipher that records how it was keyed and can fail decryption like the binary.
final class PasskeyPrfEncryptionFake: PortalEncryptionProtocol {
  var encryptWithPasswordParams: [(value: String, password: String)] = []
  var decryptWithPasswordParams: [(value: String, password: String)] = []
  var decryptWithPasswordError: Error?
  var privateKeyCallsCount = 0

  func decrypt(_: String, withPrivateKey _: String) async throws -> String {
    privateKeyCallsCount += 1
    return ""
  }

  func decrypt(_ value: String, withPassword: String) async throws -> String {
    decryptWithPasswordParams.append((value, withPassword))
    if let error = decryptWithPasswordError {
      throw error
    }
    return "plaintext"
  }

  func encrypt(_: String) async throws -> EncryptData {
    privateKeyCallsCount += 1
    return EncryptData(key: "random-key", cipherText: "random-cipher-text")
  }

  func encrypt(_ value: String, withPassword: String) async throws -> String {
    encryptWithPasswordParams.append((value, withPassword))
    return "password-cipher-text"
  }
}

// MARK: - Tests

@available(iOS 18.0, *)
final class PasskeyPrfStorageTests: XCTestCase {
  static let createdOutput = PasskeyPrfFixtures.createdOutput
  static let assertedOutput = PasskeyPrfFixtures.assertedOutput
  static let createdCredentialId = PasskeyPrfFixtures.createdCredentialId
  static let serverCredentialId = PasskeyPrfFixtures.serverCredentialId

  var api: PortalApiMock!
  var client: PasskeyPrfWebAuthnClientFake!
  var encryption: PasskeyPrfEncryptionFake!
  var storage: PasskeyPrfStorage!

  override func setUpWithError() throws {
    api = PortalApiMock(client: ClientResponse.stub(custodian: .stub(name: "Acme")))
    client = PasskeyPrfWebAuthnClientFake()
    encryption = PasskeyPrfEncryptionFake()
    storage = makeStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
    client = nil
    encryption = nil
    api = nil
  }

  private func makeStorage(
    relyingParty: String? = nil,
    relyingPartyName: String? = nil,
    user: PasskeyPrfUser? = nil,
    isPlatformSupported: Bool = true
  ) -> PasskeyPrfStorage {
    let storage = PasskeyPrfStorage(
      relyingParty: relyingParty,
      relyingPartyName: relyingPartyName,
      user: user,
      encryption: encryption,
      webAuthnClient: client,
      isPlatformSupported: { isPlatformSupported }
    )
    storage.api = api
    return storage
  }

  private func record(_ id: Data, rpId: String = "portalhq.io", transports: [String]? = nil) -> PasskeyPrfCredential {
    PasskeyPrfCredential(credentialId: PasskeyPrfEncoding.base64Url(id), rpId: rpId, transports: transports)
  }

  private func queueCreation(prfEnabled: Bool = true, prfOutput: Data? = PasskeyPrfStorageTests.createdOutput) {
    client.createResults.append(.success(PasskeyPrfCreateResult(
      credentialId: Self.createdCredentialId,
      transports: nil,
      prfEnabled: prfEnabled,
      prfOutput: prfOutput
    )))
  }

  private func assertPasskeyPrfError(
    _ reason: PortalPasskeyPrfError.Reason,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> some Any
  ) async {
    do {
      _ = try await body()
      XCTFail("Expected \(reason.rawValue)", file: file, line: line)
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error.reason, reason, file: file, line: line)
    } catch {
      XCTFail("Expected PortalPasskeyPrfError, got \(error)", file: file, line: line)
    }
  }

  // MARK: - Contract constants

  func test_salt_isSha256OfPortalLabel() {
    let expected = Data(SHA256.hash(data: Data("portal.backup.prf.v1".utf8)))
    XCTAssertEqual(PasskeyPrfConstants.salt, expected)
    XCTAssertEqual(PasskeyPrfConstants.saltHex, "e8cdf823f6ba01756590c8a09d9da3777b2ade5e40129a2f8ad8097d2945ce0f")
    XCTAssertEqual(PasskeyPrfConstants.salt.count, 32)
  }

  func test_backupMethod_wireValue() {
    XCTAssertEqual(BackupMethods.PasskeyPrf.rawValue, "PASSKEY_PRF")
  }

  func test_errorReasons_matchTheOtherSdks() {
    XCTAssertEqual(
      PortalPasskeyPrfError.Reason.allCases.map(\.rawValue),
      [
        "PRF_CEREMONY_FAILED",
        "PRF_USER_CANCELLED",
        "PRF_PASSKEY_UNAVAILABLE",
        "PRF_CREDENTIAL_NOT_FOUND",
        "PRF_DECRYPT_FAILED",
        "PRF_NOT_SUPPORTED",
        "PRF_RP_ID_MISMATCH"
      ]
    )
    XCTAssertTrue(PortalPasskeyPrfError(.userCancelled).isUserCancelled)
    XCTAssertEqual(
      PortalPasskeyPrfError(.rpIdMismatch, context: "ctx").errorDescription,
      "[Portal] The passkey was enrolled under a different relying party. ctx"
    )
    XCTAssertEqual(
      PortalPasskeyPrfError(.decryptFailed).errorDescription,
      "[Portal] The backup could not be decrypted with the secret from this passkey (wrong passkey or wrong ciphertext)."
    )
  }

  func test_relyingParty_isTrimmedAndLowercased_withDefaults() {
    XCTAssertEqual(makeStorage(relyingParty: "  Example.COM \n").relyingParty, "example.com")
    XCTAssertEqual(makeStorage(relyingParty: "   ").relyingParty, "portalhq.io")
    XCTAssertEqual(makeStorage().relyingParty, "portalhq.io")
    XCTAssertEqual(makeStorage().relyingPartyName, "Portal")
  }

  func test_encoding_hexIsLowercase_andBase64UrlIsCanonical() {
    XCTAssertEqual(PasskeyPrfEncoding.hex([0x00, 0xAB, 0xFF]), "00abff")
    XCTAssertEqual(PasskeyPrfEncoding.base64Url(Data([0xFB, 0xFF])), "-_8")
    XCTAssertEqual(PasskeyPrfEncoding.data(fromBase64Url: "-_8"), Data([0xFB, 0xFF]))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "-_8="))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "+/8"))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: ""))
    // Non-canonical trailing bits alias another ID.
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "-_9"))
  }

  // MARK: - enroll() with an existing record

  func test_enroll_withExistingRecord_assertsWithIt_andReturnsHexOfPrfOutput() async throws {
    let existing = record(Self.serverCredentialId)
    api.getPasskeyPrfCredentialResults = [.success(existing)]

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
    XCTAssertEqual(secret.count, 64)
    XCTAssertEqual(client.createRequests.count, 0)
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 0)
    XCTAssertEqual(client.getRequests.count, 1)
    XCTAssertEqual(client.getRequests.first?.allowCredentialId, Self.serverCredentialId)
    XCTAssertEqual(client.getRequests.first?.rpId, "portalhq.io")
    XCTAssertEqual(client.getRequests.first?.prfSalt, PasskeyPrfConstants.salt)
    XCTAssertEqual(client.getRequests.first?.challenge.count, 32)
  }

  func test_enroll_withExistingRecord_whenAnotherPasskeyAnswers_throwsPasskeyUnavailable() async {
    // A re-backup must fail rather than encrypt with the wrong passkey.
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Data([0xEE]), prfOutput: Self.assertedOutput))]

    await assertPasskeyPrfError(.passkeyUnavailable) { try await self.storage.enroll() }
    XCTAssertTrue(client.createRequests.isEmpty)
    XCTAssertTrue(encryption.encryptWithPasswordParams.isEmpty)
  }

  func test_enroll_withExistingRecordUnderAnotherRelyingParty_throwsRpIdMismatch_withoutACeremony() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.enroll() }
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  // MARK: - enroll() without a record

  func test_enroll_withoutRecord_createsPasskey_storesRecord_andReusesCreationOutput() async throws {
    queueCreation()

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertEqual(client.createRequests.count, 1)
    let request = try XCTUnwrap(client.createRequests.first)
    XCTAssertEqual(request.rpId, "portalhq.io")
    XCTAssertEqual(request.userName, "Acme Backup (PRF)")
    XCTAssertEqual(request.userDisplayName, "Acme Backup (PRF)")
    XCTAssertEqual(request.prfSalt, PasskeyPrfConstants.salt)
    XCTAssertEqual(request.userId.count, 32)
    XCTAssertEqual(request.challenge.count, 32)
    XCTAssertEqual(api.storePasskeyPrfCredentialParams, [
      PasskeyPrfCredential(credentialId: "AQID-_8", rpId: "portalhq.io", transports: nil)
    ])
    // No second prompt when creation returned the output.
    XCTAssertEqual(client.getRequests.count, 0)
  }

  func test_enroll_userName_fallsBackToRelyingPartyName_whenCustodianHasNoName() async throws {
    api.client = ClientResponse.stub(custodian: .stub(name: ""))
    storage = makeStorage(relyingPartyName: "Wallet Co")
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.userName, "Wallet Co Backup (PRF)")
  }

  func test_enroll_usesConfiguredUser() async throws {
    storage = makeStorage(user: PasskeyPrfUser(name: "alice", displayName: "Alice"))
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.userName, "alice")
    XCTAssertEqual(client.createRequests.first?.userDisplayName, "Alice")
  }

  func test_enroll_createsUnderConfiguredRelyingParty() async throws {
    storage = makeStorage(relyingParty: "Wallet.Example")
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.rpId, "wallet.example")
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.first?.rpId, "wallet.example")
  }

  func test_enroll_whenCreationEnablesPrfWithoutOutput_assertsWithTheNewCredential() async throws {
    queueCreation(prfEnabled: true, prfOutput: nil)

    let secret = try await storage.enroll()

    XCTAssertEqual(client.getRequests.count, 1)
    XCTAssertEqual(client.getRequests.first?.allowCredentialId, Self.createdCredentialId)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_enroll_whenAnotherPasskeyAnswersTheAssertionAfterCreation_throwsPasskeyUnavailable_beforeStoring() async {
    queueCreation(prfEnabled: true, prfOutput: nil)
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Self.serverCredentialId, prfOutput: Self.assertedOutput))]

    await assertPasskeyPrfError(.passkeyUnavailable) { try await self.storage.enroll() }
    XCTAssertTrue(api.storePasskeyPrfCredentialParams.isEmpty)
  }

  func test_enroll_whenCreationReportsNoPrf_throwsNotSupported_beforeStoring() async {
    queueCreation(prfEnabled: false, prfOutput: nil)

    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
    XCTAssertTrue(api.storePasskeyPrfCredentialParams.isEmpty)
  }

  func test_enroll_whenCreationOutputIsNot32Bytes_throwsNotSupported() async {
    queueCreation(prfOutput: Data(repeating: 1, count: 16))

    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
  }

  func test_enroll_on409_discardsCreationOutput_andReadsTheWinningRecord() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.clientError("409 - conflict", url: "u"))]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.serverCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
    XCTAssertNotEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertEqual(client.getRequests.map(\.allowCredentialId), [Self.serverCredentialId])
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1)
  }

  func test_enroll_on409_withNoRecordToRead_throwsCredentialNotFound() async {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.clientError("409 - conflict", url: "u"))]

    await assertPasskeyPrfError(.credentialNotFound) { try await self.storage.enroll() }
  }

  func test_enroll_whenServerReturnsAnotherCredential_assertsWithTheServersOne() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(client.getRequests.map(\.allowCredentialId), [Self.serverCredentialId])
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_enroll_whenServerReturnsAnotherRelyingParty_throwsRpIdMismatch() async {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.success(record(Self.createdCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.enroll() }
  }

  // MARK: - enroll() store retries

  func test_enroll_retriesTransientStoreFailures_upToThreeTimes() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [
      .failure(PortalRequestsError.internalServerError("503 - unavailable", url: "u")),
      .failure(PortalRequestsError.clientError("429 - slow down", url: "u")),
      .success(record(Self.createdCredentialId))
    ]

    let secret = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
  }

  func test_enroll_retriesNetworkFailures() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(URLError(.networkConnectionLost)), .success(record(Self.createdCredentialId))]

    _ = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 2)
  }

  func test_enroll_whenEveryStoreAttemptFails_readsOnceAndUsesARecordThatLanded() async throws {
    queueCreation()
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure), .failure(failure), .failure(failure)]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.createdCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 2)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_enroll_whenEveryStoreAttemptFails_andNothingLanded_throwsTheLastError() async {
    queueCreation()
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure), .failure(failure), .failure(failure)]

    do {
      _ = try await storage.enroll()
      XCTFail("Expected the store failure")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
    }
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 2)
  }

  func test_enroll_doesNotRetryOtherClientErrors() async {
    queueCreation()
    let failure = PortalRequestsError.clientError("400 - bad request", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure)]

    do {
      _ = try await storage.enroll()
      XCTFail("Expected the store failure")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
    }
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1)
  }

  func test_enroll_doesNotRetryAnUnauthorizedOrInvalidatedSession() async {
    for failure: Error in [PortalRequestsError.unauthorized, PortalCredentialError.sessionInvalidated] {
      try? setUpWithError()
      queueCreation()
      api.storePasskeyPrfCredentialResults = [.failure(failure)]

      do {
        _ = try await storage.enroll()
        XCTFail("Expected the store failure")
      } catch {}
      XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1, "\(failure)")
    }
  }

  func test_isTransient() {
    XCTAssertTrue(PasskeyPrfStorage.isTransient(PortalRequestsError.internalServerError("500 - x", url: "")))
    XCTAssertTrue(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("429 - x", url: "")))
    XCTAssertTrue(PasskeyPrfStorage.isTransient(URLError(.timedOut)))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("409 - x", url: "")))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("404 - x", url: "")))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.unauthorized))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalCredentialError.unavailable))
  }

  // MARK: - read()

  func test_read_withoutRecord_throwsCredentialNotFound_andNeverCreatesAPasskey() async {
    await assertPasskeyPrfError(.credentialNotFound) { try await self.storage.read() }
    XCTAssertTrue(client.createRequests.isEmpty)
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_read_withRecord_returnsTheSecret() async throws {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let secret = try await storage.read()

    XCTAssertEqual(secret, "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  func test_read_withRecordUnderAnotherRelyingParty_throwsRpIdMismatch() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.read() }
  }

  func test_read_whenThePlatformAnswersWithAnotherPasskey_throwsPasskeyUnavailable() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Data([0xEE]), prfOutput: Self.assertedOutput))]

    do {
      _ = try await storage.read()
      XCTFail("Expected an error")
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error, PortalPasskeyPrfError(.passkeyUnavailable, context: "A passkey other than this client's enrolled passkey answered."))
      XCTAssertEqual(
        error.errorDescription,
        "[Portal] The enrolled passkey is not available on this device. A passkey other than this client's enrolled passkey answered."
      )
    } catch {
      XCTFail("Expected PortalPasskeyPrfError, got \(error)")
    }
  }

  func test_read_whenAssertionHasNoPrfOutput_throwsNotSupported() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Self.serverCredentialId, prfOutput: nil))]

    await assertPasskeyPrfError(.notSupported) { try await self.storage.read() }
  }

  func test_read_withNonCanonicalStoredCredentialId_throwsCeremonyFailed() async {
    api.getPasskeyPrfCredentialResults = [.success(PasskeyPrfCredential(credentialId: "AQID+/8=", rpId: "portalhq.io"))]

    await assertPasskeyPrfError(.ceremonyFailed) { try await self.storage.read() }
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_read_whenNotAttachedToPortal_throws() async {
    storage.api = nil
    do {
      _ = try await storage.read()
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .notAttachedToPortal)
    }
  }

  func test_unsupportedPlatform_throwsNotSupported() async {
    storage = makeStorage(isPlatformSupported: false)
    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
    await assertPasskeyPrfError(.notSupported) { try await self.storage.read() }
    await assertPasskeyPrfError(.notSupported) { try await self.storage.validateOperations() }
  }

  // MARK: - Ceremony error mapping

  func test_ceremonyErrors_mapToReasons() async {
    let cases: [(PasskeyPrfCeremonyError, PortalPasskeyPrfError.Reason)] = [
      (.cancelled(nil), .userCancelled),
      (.noCredentials(nil), .passkeyUnavailable),
      (.noPresentationAnchor, .ceremonyFailed),
      (.failed(NSError(domain: "x", code: 1)), .ceremonyFailed)
    ]
    for (ceremonyError, reason) in cases {
      api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
      client.getResults = [.failure(ceremonyError)]
      await assertPasskeyPrfError(reason) { try await self.storage.read() }
    }

    queueCreation()
    client.createResults = [.failure(PasskeyPrfCeremonyError.cancelled(nil))]
    await assertPasskeyPrfError(.userCancelled) { try await self.storage.enroll() }
  }

  func test_failedCeremony_reportsAStableCode_andKeepsThePlatformMessageInTheCause() {
    let platformError = NSError(domain: "x", code: 7, userInfo: [NSLocalizedDescriptionKey: "internal detail"])
    let error = PasskeyPrfStorage.portalError(from: .failed(platformError))

    XCTAssertEqual(error.reason, .ceremonyFailed)
    XCTAssertEqual(error.context, "The passkey ceremony failed (x 7).")
    XCTAssertFalse(error.errorDescription?.contains("internal detail") ?? true)
    XCTAssertEqual((error.cause as? NSError)?.code, 7)

    XCTAssertEqual(
      PasskeyPrfStorage.portalError(from: .failed(ASAuthorizationError(.failed))).context,
      "The passkey ceremony failed (ASAuthorizationError 1004)."
    )
    XCTAssertEqual(
      PasskeyPrfStorage.portalError(from: .failed(nil)).context,
      "The passkey ceremony failed (UNEXPECTED_CREDENTIAL)."
    )
  }

  func test_authorizationErrors_mapToCeremonyErrors() {
    func map(_ error: Error) -> String {
      switch PasskeyPrfAuthorizationClient.ceremonyError(from: error) {
      case .cancelled: return "cancelled"
      case .noCredentials: return "noCredentials"
      case .noPresentationAnchor: return "noPresentationAnchor"
      case .failed: return "failed"
      }
    }
    XCTAssertEqual(map(ASAuthorizationError(.canceled)), "cancelled")
    XCTAssertEqual(map(ASAuthorizationError(.notInteractive)), "noCredentials")
    XCTAssertEqual(map(ASAuthorizationError(.failed)), "failed")
    XCTAssertEqual(map(ASAuthorizationError(.invalidResponse)), "failed")
    XCTAssertEqual(map(NSError(domain: "other", code: 1001)), "failed")
  }

  func test_authorizationClient_withoutAnchor_failsBeforePresenting() async {
    let client = PasskeyPrfAuthorizationClient()
    do {
      _ = try await client.getCredential(PasskeyPrfGetRequest(rpId: "portalhq.io", challenge: Data(count: 32), allowCredentialId: Data([1]), prfSalt: PasskeyPrfConstants.salt))
      XCTFail("Expected an error")
    } catch PasskeyPrfCeremonyError.noPresentationAnchor {
      // expected
    } catch {
      XCTFail("Unexpected error \(error)")
    }
  }

  // MARK: - Cipher

  func test_encryptWithSecret_usesThePasswordCipher() async throws {
    let cipherText = try await storage.encrypt("shares", withSecret: "abcd")

    XCTAssertEqual(cipherText, "password-cipher-text")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.value, "shares")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, "abcd")
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
  }

  func test_encrypt_enrollsAndUsesThePasswordCipher() async throws {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let result = try await storage.encrypt("shares")

    XCTAssertEqual(result.cipherText, "password-cipher-text")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_decrypt_usesThePasswordCipher() async throws {
    let plaintext = try await storage.decrypt("cipher", withKey: "abcd")

    XCTAssertEqual(plaintext, "plaintext")
    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.password, "abcd")
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
  }

  func test_decrypt_withTheWrongPasskey_throwsDecryptFailed() async {
    encryption.decryptWithPasswordError = PortalMpcError(PortalError(id: "DECRYPT_FAILED", message: "Failed to decrypt"))

    await assertPasskeyPrfError(.decryptFailed) { try await self.storage.decrypt("cipher", withKey: "wrong") }
  }

  func test_write_isANoOp_andDeleteIsUnsupported() async throws {
    let written = try await storage.write("anything")
    XCTAssertTrue(written)
    do {
      _ = try await storage.delete()
      XCTFail("Expected delete to throw")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .deleteNotSupported)
    }
  }

  func test_zero_clearsTheBuffer() {
    var data: Data? = Data(repeating: 0xFF, count: 32)
    PasskeyPrfStorage.zero(&data)
    XCTAssertNil(data)
  }
}

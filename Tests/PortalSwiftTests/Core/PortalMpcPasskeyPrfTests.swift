//
//  PortalMpcPasskeyPrfTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
@testable import PortalSwift
import XCTest

/// How `PortalMpc` routes `BackupMethods.PasskeyPrf` through the password cipher.
@available(iOS 18.4, *)
final class PortalMpcPasskeyPrfTests: XCTestCase {
  private var api: PortalApiMock!
  private var client: PasskeyPrfWebAuthnClientFake!
  private var encryption: PasskeyPrfEncryptionFake!
  private var storage: PasskeyPrfStorage!
  /// `PortalMpc` holds its keychain weakly.
  private var keychain: MockPortalKeychain!

  private let enrolled = PasskeyPrfCredential(
    credentialId: PasskeyPrfEncoding.base64Url(PasskeyPrfFixtures.serverCredentialId),
    rpId: "portalhq.io"
  )

  override func setUpWithError() throws {
    CredentialInvalidationRegistry.shared.resetForTesting()
    api = PortalApiMock(client: ClientResponse.stub(environment: .stub(backupWithPortalEnabled: false)))
    api.storeClientCipherTextReturnValue = true
    client = PasskeyPrfWebAuthnClientFake()
    encryption = PasskeyPrfEncryptionFake()
    storage = PasskeyPrfStorage(encryption: encryption, webAuthnClient: client, isPlatformSupported: { true })
    keychain = MockPortalKeychain()
  }

  override func tearDownWithError() throws {
    CredentialInvalidationRegistry.shared.resetForTesting()
  }

  private func makeMpc(mobile: Mobile = MockMobileWrapper(), storage: PortalStorage? = nil) -> PortalMpc {
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: mobile)
    mpc.registerBackupMethod(.PasskeyPrf, withStorage: storage ?? self.storage)
    return mpc
  }

  // MARK: - backup

  func test_backup_encryptsWithThePrfSecret_throughThePasswordCipher() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    let response = try await mpc.backup(.PasskeyPrf)

    XCTAssertEqual(response.cipherText, "password-cipher-text")
    XCTAssertFalse(response.shareIds.isEmpty)
    XCTAssertEqual(encryption.encryptWithPasswordParams.count, 1)
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(PasskeyPrfFixtures.assertedOutput))
    // The random-key cipher is never used for this method.
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
    XCTAssertEqual(client.getRequests.count, 1)
  }

  func test_setPasskeyPrfUser_labelsThePasskeyTheNextBackupCreates() async throws {
    client.createResults = [.success(PasskeyPrfCreateResult(
      credentialId: PasskeyPrfFixtures.createdCredentialId,
      transports: nil,
      prfEnabled: true,
      prfOutput: PasskeyPrfFixtures.createdOutput
    ))]
    let mpc = makeMpc()
    let user = PasskeyPrfUser(name: "jane@example.com", displayName: "Jane, Acme wallet backup")

    try mpc.setPasskeyPrfUser(user)
    _ = try await mpc.backup(.PasskeyPrf)

    XCTAssertEqual(storage.user, user)
    XCTAssertEqual(client.createRequests.count, 1)
    XCTAssertEqual(client.createRequests.first?.userName, user.name)
    XCTAssertEqual(client.createRequests.first?.userDisplayName, user.displayName)
  }

  func test_setPasskeyPrfUser_throws_whenNoPasskeyPrfStorageIsRegistered() throws {
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())

    XCTAssertThrowsError(try mpc.setPasskeyPrfUser(PasskeyPrfUser(name: "jane", displayName: "Jane"))) { error in
      guard case MpcError.backupMethodNotRegistered = error else {
        return XCTFail("Expected backupMethodNotRegistered, got \(error)")
      }
    }
  }

  func test_backup_storesThePasswordCipherText_whenBackupWithPortalIsEnabled() async throws {
    api.client = ClientResponse.stub(environment: .stub(backupWithPortalEnabled: true))
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    let response = try await mpc.backup(.PasskeyPrf)

    // Every backup share pair gets the cipher text the password cipher produced from the PRF
    // secret, the same one the backup returns.
    XCTAssertFalse(response.shareIds.isEmpty)
    XCTAssertEqual(api.storeClientCipherTextParams.map(\.backupSharePairId).sorted(), response.shareIds.sorted())
    XCTAssertEqual(Set(api.storeClientCipherTextParams.map(\.cipherText)), ["password-cipher-text"])
    XCTAssertEqual(response.cipherText, "password-cipher-text")
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
  }

  func test_backup_whenThePromptIsCancelled_failsBeforeTheMpcBackupRuns() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    client.getResults = [.failure(PasskeyPrfCeremonyError.cancelled(nil))]
    let mobile = MobileSpy()
    let mpc = makeMpc(mobile: mobile)

    do {
      _ = try await mpc.backup(.PasskeyPrf)
      XCTFail("Expected the cancellation")
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error.reason, .userCancelled)
    }
    XCTAssertEqual(mobile.mobileBackupCallsCount, 0)
    XCTAssertEqual(mobile.mobileBackupEd25519CallsCount, 0)
  }

  func test_backup_reportsGeneratingShare_onlyAfterThePasskeyAnswered() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()
    var statuses: [MpcStatuses] = []
    var promptsWhenGenerating: Int?

    _ = try await mpc.backup(.PasskeyPrf) { status in
      statuses.append(status.status)
      if status.status == .generatingShare {
        promptsWhenGenerating = self.client.getRequests.count
      }
    }

    XCTAssertTrue(statuses.contains(.generatingShare))
    XCTAssertEqual(promptsWhenGenerating, 1)
  }

  func test_backup_whenThePromptIsCancelled_neverReportsGeneratingShare() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    client.getResults = [.failure(PasskeyPrfCeremonyError.cancelled(nil))]
    let mpc = makeMpc()
    var statuses: [MpcStatuses] = []

    _ = try? await mpc.backup(.PasskeyPrf) { status in
      statuses.append(status.status)
    }

    XCTAssertFalse(statuses.isEmpty)
    XCTAssertFalse(statuses.contains(.generatingShare))
  }

  func test_backup_withAStorageThatDerivesNoSecret_throwsUnsupportedStorageMethod() async throws {
    let mpc = makeMpc(storage: PortalStorageSpy())

    do {
      _ = try await mpc.backup(.PasskeyPrf)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
  }

  func test_backup_withPasskeyPrfStorageRegisteredForAnotherMethod_throwsUnsupportedStorageMethod() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Password, withStorage: storage)

    do {
      _ = try await mpc.backup(.Password)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
    // No passkey prompt and no cipher ran for the mislabeled backup.
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertTrue(encryption.encryptWithPasswordParams.isEmpty)
  }

  // MARK: - recover / eject

  func test_recover_readsTheSecret_andDecryptsWithThePasswordCipher() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    _ = try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text")

    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.value, "cipher-text")
    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(PasskeyPrfFixtures.assertedOutput))
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  func test_backup_sendsItsTraceId_toTheCredentialCalls() async throws {
    client.createResults = [.success(PasskeyPrfCreateResult(
      credentialId: PasskeyPrfFixtures.createdCredentialId,
      transports: nil,
      prfEnabled: true,
      prfOutput: PasskeyPrfFixtures.createdOutput
    ))]
    let mpc = makeMpc()

    let response = try await mpc.backup(.PasskeyPrf)

    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, [response.traceId])
    XCTAssertEqual(api.storePasskeyPrfCredentialTraceIds, [response.traceId])
  }

  func test_recover_sendsItsTraceId_toTheCredentialRead() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    _ = try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text")

    XCTAssertNotNil(api.refreshClientTraceIdParam)
    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, [api.refreshClientTraceIdParam])
  }

  func test_recover_withoutAnEnrolledPasskey_throwsCredentialNotFound() async throws {
    let mpc = makeMpc()

    do {
      _ = try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text")
      XCTFail("Expected an error")
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error.reason, .credentialNotFound)
    }
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  func test_recover_withTheWrongPasskey_throwsDecryptFailed() async throws {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    encryption.decryptWithPasswordError = PortalMpcError(PortalError(id: "DECRYPT_FAILED", message: "Failed to decrypt"))
    let mpc = makeMpc()

    do {
      _ = try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text")
      XCTFail("Expected an error")
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error.reason, .decryptFailed)
    }
  }

  func test_eject_readsTheSecret_andDecryptsWithThePasswordCipher() async throws {
    api.client = ClientResponse.stub(
      environment: .stub(backupWithPortalEnabled: true),
      wallets: [
        .stub(backupSharePairs: [.stub(backupMethod: .PasskeyPrf)], curve: .ED25519),
        .stub(backupSharePairs: [.stub(backupMethod: .PasskeyPrf)], curve: .SECP256K1)
      ]
    )
    api.getClientCipherTextReturnValue = "cipher-text"
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    encryption.decryptWithPasswordResult = UnitTestMockConstants.decodedShare
    let mobile = MobileSpy()
    let mpc = makeMpc(mobile: mobile)

    let privateKeys = try await mpc.eject(.PasskeyPrf)

    XCTAssertEqual(encryption.decryptWithPasswordParams.count, 1)
    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.value, "cipher-text")
    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(PasskeyPrfFixtures.assertedOutput))
    // One prompt for the enrolled passkey, and never a new passkey.
    XCTAssertEqual(client.getRequests.map(\.allowCredentialId), [PasskeyPrfFixtures.serverCredentialId])
    XCTAssertTrue(client.createRequests.isEmpty)
    XCTAssertEqual(mobile.mobileEjectWalletAndDiscontinueMPCCallsCount, 1)
    XCTAssertNotNil(privateKeys[.eip155])
    // The credential read is traced with the rest of the eject.
    XCTAssertNotNil(api.prepareEjectTraceIdParam)
    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, [api.prepareEjectTraceIdParam])
  }

  func test_eject_withoutAPasskeyPrfBackup_throwsBeforeAnyPrompt() async {
    // The stub client's wallets are backed up with iCloud only.
    api.client = ClientResponse.stub(environment: .stub(backupWithPortalEnabled: true))
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    do {
      _ = try await mpc.eject(.PasskeyPrf)
      XCTFail("Expected an error")
    } catch {
      guard case MpcError.unableToEjectWallet = error else {
        return XCTFail("Expected unableToEjectWallet, got \(error)")
      }
    }
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 0)
  }

  func test_recover_withPasskeyPrfStorageRegisteredForAnotherMethod_throwsUnsupportedStorageMethod_withoutAPrompt() async {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Password, withStorage: storage)

    do {
      _ = try await mpc.recover(.Password, withCipherText: "cipher-text")
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 0)
  }

  func test_recover_withAStorageThatDerivesNoSecret_throwsUnsupportedStorageMethod() async {
    let otherStorage = PortalStorageSpy()
    let mpc = makeMpc(storage: otherStorage)

    do {
      _ = try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text")
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
    XCTAssertEqual(otherStorage.readCallsCount, 0)
  }

  func test_eject_withPasskeyPrfStorageRegisteredForAnotherMethod_throwsUnsupportedStorageMethod_withoutAPrompt() async {
    api.client = ClientResponse.stub(
      environment: .stub(backupWithPortalEnabled: true),
      wallets: [
        .stub(backupSharePairs: [.stub(backupMethod: .Password)], curve: .ED25519),
        .stub(backupSharePairs: [.stub(backupMethod: .Password)], curve: .SECP256K1)
      ]
    )
    api.getClientCipherTextReturnValue = "cipher-text"
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Password, withStorage: storage)

    do {
      _ = try await mpc.eject(.Password)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertTrue(encryption.decryptWithPasswordParams.isEmpty)
  }

  // MARK: - Cancellation

  func test_backup_whenTheTaskIsCancelledDuringThePrompt_cancelsThePrompt_beforeTheMpcBackupRuns() async {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let prompt = PasskeyPrfPendingPromptClient()
    let mobile = MobileSpy()
    let mpc = makeMpc(
      mobile: mobile,
      storage: PasskeyPrfStorage(encryption: encryption, webAuthnClient: prompt, isPlatformSupported: { true })
    )

    let task = Task { try await mpc.backup(.PasskeyPrf) }
    await fulfillment(of: [prompt.shown], timeout: 5)
    task.cancel()
    await fulfillment(of: [prompt.cancelled], timeout: 5)
    // Unblocks the task if the cancellation never arrived, so a regression fails instead of hanging.
    prompt.answer()

    await assertPasskeyPrfCancelled(task)
    XCTAssertEqual(mobile.mobileBackupCallsCount, 0)
    XCTAssertEqual(mobile.mobileBackupEd25519CallsCount, 0)
  }

  func test_recover_whenTheTaskIsCancelledDuringThePrompt_cancelsThePrompt_andRecoversNothing() async {
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let prompt = PasskeyPrfPendingPromptClient()
    let mobile = MobileSpy()
    let mpc = makeMpc(
      mobile: mobile,
      storage: PasskeyPrfStorage(encryption: encryption, webAuthnClient: prompt, isPlatformSupported: { true })
    )

    let task = Task { try await mpc.recover(.PasskeyPrf, withCipherText: "cipher-text") }
    await fulfillment(of: [prompt.shown], timeout: 5)
    task.cancel()
    await fulfillment(of: [prompt.cancelled], timeout: 5)
    // Unblocks the task if the cancellation never arrived, so a regression fails instead of hanging.
    prompt.answer()

    await assertPasskeyPrfCancelled(task)
    XCTAssertTrue(encryption.decryptWithPasswordParams.isEmpty)
    XCTAssertEqual(mobile.mobileRecoverSigningSecp256k1CallsCount, 0)
    XCTAssertEqual(mobile.mobileRecoverSigningEd25519CallsCount, 0)
  }

  // MARK: - Anchor

  func test_setPasskeyAuthenticationAnchor_setsThePasskeyPrfStorageAnchor() throws {
    let mpc = makeMpc()
    let window = UIWindow()

    try mpc.setPasskeyAuthenticationAnchor(window)

    XCTAssertTrue(storage.anchor === window)
  }

  func test_registeringAfterTheAnchorIsSet_takesThePasskeyStorageAnchor() throws {
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Passkey, withStorage: PasskeyStorage())
    let window = UIWindow()
    try mpc.setPasskeyAuthenticationAnchor(window)

    mpc.registerBackupMethod(.PasskeyPrf, withStorage: storage)

    XCTAssertTrue(storage.anchor === window)
  }

  func test_registering_keepsAnAnchorTheStorageAlreadyHas() throws {
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Passkey, withStorage: PasskeyStorage())
    try mpc.setPasskeyAuthenticationAnchor(UIWindow())
    let ownWindow = UIWindow()
    storage.anchor = ownWindow

    mpc.registerBackupMethod(.PasskeyPrf, withStorage: storage)

    XCTAssertTrue(storage.anchor === ownWindow)
  }

  func test_registering_withoutAnAnchorAnywhere_leavesNone() {
    let mpc = PortalMpc(credentials: MockConstants.mockCredentials, api: api, keychain: keychain, mobile: MockMobileWrapper())
    mpc.registerBackupMethod(.Passkey, withStorage: PasskeyStorage())

    mpc.registerBackupMethod(.PasskeyPrf, withStorage: storage)

    XCTAssertNil(storage.anchor)
  }
}

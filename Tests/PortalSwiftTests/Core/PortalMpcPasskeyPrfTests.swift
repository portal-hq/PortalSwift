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
@available(iOS 18.0, *)
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

  func test_backup_passesThePasskeyLabelsGivenWithTheBackup_toTheStorage() async throws {
    client.createResults = [.success(PasskeyPrfCreateResult(
      credentialId: PasskeyPrfFixtures.createdCredentialId,
      transports: nil,
      prfEnabled: true,
      prfOutput: PasskeyPrfFixtures.createdOutput
    ))]
    let mpc = makeMpc()
    let user = PasskeyPrfUser(name: "jane@example.com", displayName: "Jane, Acme wallet backup")

    _ = try await mpc.backup(.PasskeyPrf, backupConfigs: BackupConfigs(passkeyPrfStorage: PasskeyPrfStorageConfig(user: user)))

    XCTAssertEqual(client.createRequests.count, 1)
    XCTAssertEqual(client.createRequests.first?.userName, user.name)
    XCTAssertEqual(client.createRequests.first?.userDisplayName, user.displayName)
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(PasskeyPrfFixtures.createdOutput))
  }

  @available(*, deprecated)
  func test_deprecatedBackup_passesThePasskeyLabelsGivenWithTheBackup_toTheStorage() async throws {
    client.createResults = [.success(PasskeyPrfCreateResult(
      credentialId: PasskeyPrfFixtures.createdCredentialId,
      transports: nil,
      prfEnabled: true,
      prfOutput: PasskeyPrfFixtures.createdOutput
    ))]
    let mpc = makeMpc()
    let user = PasskeyPrfUser(name: "jane@example.com", displayName: "Jane")
    let done = expectation(description: "backup completes")

    mpc.backup(
      method: BackupMethods.PasskeyPrf.rawValue,
      backupConfigs: BackupConfigs(passkeyPrfStorage: PasskeyPrfStorageConfig(user: user)),
      completion: { result in
        XCTAssertNil(result.error)
        done.fulfill()
      }
    )
    await fulfillment(of: [done], timeout: 5)

    XCTAssertEqual(client.createRequests.first?.userName, user.name)
  }

  func test_backup_storesThePasswordCipherText_whenBackupWithPortalIsEnabled() async throws {
    api.client = ClientResponse.stub(environment: .stub(backupWithPortalEnabled: true))
    api.getPasskeyPrfCredentialResults = [.success(enrolled)]
    let mpc = makeMpc()

    let response = try await mpc.backup(.PasskeyPrf)

    XCTAssertGreaterThanOrEqual(api.storeClientCipherTextCallsCount, 1)
    XCTAssertEqual(api.storeClientCipherTextCallsCount, response.shareIds.count)
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

  func test_backup_withAStorageThatDerivesNoSecret_throwsUnsupportedStorageMethod() async throws {
    let mpc = makeMpc(storage: PortalStorageSpy())

    do {
      _ = try await mpc.backup(.PasskeyPrf)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
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

  // MARK: - Anchor

  func test_setPasskeyAuthenticationAnchor_setsThePasskeyPrfStorageAnchor() throws {
    let mpc = makeMpc()
    let window = UIWindow()

    try mpc.setPasskeyAuthenticationAnchor(window)

    XCTAssertTrue(storage.anchor === window)
  }
}

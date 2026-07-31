//
//  PortalMpcTests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

@testable import PortalSwift
import XCTest

final class PortalMpcTests: XCTestCase {
  private var mpc: PortalMpc?
  private var portalApi: PortalApiProtocol!
  private var keychain: PortalKeychainProtocol!

  override func setUpWithError() throws {
    portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
    keychain = MockPortalKeychain()
    self.mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: portalApi,
      keychain: keychain,
      mobile: MockMobileWrapper()
    )

    self.mpc?.registerBackupMethod(.GoogleDrive, withStorage: MockGDriveStorage())
    self.mpc?.registerBackupMethod(.Password, withStorage: MockPasswordStorage())
    self.mpc?.registerBackupMethod(.iCloud, withStorage: MockICloudStorage())
    if #available(iOS 16, *) {
      mpc?.registerBackupMethod(.Passkey, withStorage: MockPasskeyStorage())
    }
  }

  override func tearDownWithError() throws {
    mpc = nil
  }
}

// MARK: - Test Helpers

extension PortalMpcTests {
  func initPortalMpcWith(
    portalApi: PortalApiProtocol = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests()),
    keychain: PortalKeychainProtocol = MockPortalKeychain(),
    mobile: Mobile = MockMobileWrapper(),
    featureFlags: FeatureFlags? = nil,
    gDriveStorage: PortalStorage? = nil,
    passwordStorage: PortalStorage? = nil,
    iCloudStorage: PortalStorage? = nil,
    passKeyStorage: PortalStorage? = nil
  ) {
    self.portalApi = portalApi
    self.keychain = keychain

    self.mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: self.portalApi,
      keychain: self.keychain,
      mobile: mobile,
      featureFlags: featureFlags
    )

    if let gDriveStorage {
      self.mpc?.registerBackupMethod(.GoogleDrive, withStorage: gDriveStorage)
    }

    if let passwordStorage {
      self.mpc?.registerBackupMethod(.Password, withStorage: passwordStorage)
    }

    if let iCloudStorage {
      self.mpc?.registerBackupMethod(.iCloud, withStorage: iCloudStorage)
    }

    if let passKeyStorage {
      self.mpc?.registerBackupMethod(.Passkey, withStorage: passKeyStorage)
    }
  }

  @available(iOS 16, *)
  func initPortalMpcWithDefaultStorageAnd(
    portalApi: PortalApiProtocol = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests()),
    keychain: PortalKeychainProtocol = MockPortalKeychain(),
    mobile: Mobile = MockMobileWrapper()
  ) {
    initPortalMpcWith(
      portalApi: portalApi,
      keychain: keychain,
      mobile: mobile,
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )
  }
}

// MARK: - backup Tests

extension PortalMpcTests {
  func testBackup() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.backup()")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    let backupResponse = try await mpc?.backup(.Password)
    XCTAssert(backupResponse != nil)
    XCTAssert(backupResponse?.shareIds.count ?? 0 > 0)
    XCTAssertEqual(backupResponse?.cipherText, MockConstants.mockCiphertext)
    for shareId in backupResponse?.shareIds ?? [] {
      XCTAssertEqual(shareId, MockConstants.mockMpcShareId)
    }
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  @available(iOS 16, *)
  func test_backup_willCall_keychainGetShares_onlyOnce() async throws {
    // given
    let portalKeychainSpy = PortalKeychainSpy()
    initPortalMpcWithDefaultStorageAnd(keychain: portalKeychainSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalKeychainSpy.getSharesCallCount, 1)
  }

  @available(iOS 16, *)
  func test_backupWithGDrive_willThrowCorrectError_WhenThereIsNoGDriveStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: nil,
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.backup(.GoogleDrive)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
  }

  @available(iOS 16, *)
  func test_backupWithPassword_willThrowCorrectError_WhenThereIsNoPasswordStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: nil,
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.backup(.Password)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
  }

  @available(iOS 16, *)
  func test_backupWithICloud_willThrowCorrectError_WhenThereIsNoICloudStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: nil,
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.backup(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
  }

  @available(iOS 16, *)
  func test_backupWithPasskey_willThrowCorrectError_WhenThereIsNoPasskeyStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: nil
    )

    do {
      // and given
      _ = try await mpc?.backup(.Passkey)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unsupportedStorageMethod)
    }
  }

  func test_backup_willCall_storageValidateOperations_onlyOnce() async throws {
    // given
    let portalStorageSpy = PortalStorageSpy()
    initPortalMpcWith(iCloudStorage: portalStorageSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalStorageSpy.validateOperationsCallsCount, 1)
  }

  func test_backup_willCall_storageEncrypt_onlyOnce() async throws {
    // given
    let portalStorageSpy = PortalStorageSpy()
    initPortalMpcWith(iCloudStorage: portalStorageSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalStorageSpy.encryptCallsCount, 1)
  }

  func test_backup_willCall_storageWrite_onlyOnce() async throws {
    // given
    let portalStorageSpy = PortalStorageSpy()
    initPortalMpcWith(iCloudStorage: portalStorageSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalStorageSpy.writeCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_backup_willCall_apiStoreClientCipherText_twice() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.storeClientCipherTextReturnValue = true
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertTrue(portalApiMock.storeClientCipherTextCallsCount >= 1)
  }

  @available(iOS 16, *)
  func test_backup_willThrowCorrectError_whenApiStoreClientCipherText_returnFalse() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.storeClientCipherTextReturnValue = false
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    do {
      // and given
      _ = try await mpc?.backup(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when api storeClientCipherText return false.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unableToStoreClientCipherText)
    }
  }

  @available(iOS 16, *)
  func test_backup_willThrowCorrectError_WhenStorageValidateOperationReturnFalse() async throws {
    let mockICloudStorage = PortalStorageMock()
    mockICloudStorage.validateOperationsReturnValue = false
    // given
    initPortalMpcWith(
      gDriveStorage: nil,
      passwordStorage: nil,
      iCloudStorage: mockICloudStorage,
      passKeyStorage: nil
    )

    do {
      // and given
      _ = try await mpc?.backup(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.backup when storage validate operation return false.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnBackup("Could not validate operations."))
    }
  }

  @available(iOS 16, *)
  func test_backup_willCall_keychainLoadMetadata_onlyOnce() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    portalApiSpy.mockClient = ClientResponse.stub()
    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalApiSpy.refreshClientCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_backup_willCall_keyChainLoadMetadata_onlyOnce() async throws {
    // given
    let portalKeychainSpy = PortalKeychainSpy()
    initPortalMpcWithDefaultStorageAnd(keychain: portalKeychainSpy)

    // and given
    _ = try await mpc?.backup(.iCloud)

    // then
    XCTAssertEqual(portalKeychainSpy.loadMetadataCallCount, 1)
  }

  func testBackupCompletion() throws {
    let expectation = XCTestExpectation(description: "Backup")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    var encounteredStatuses: Set<MpcStatuses> = []
    self.mpc?.backup(method: BackupMethods.Password.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }
      guard let cipherText = result.data else {
        XCTFail("Unable to parse cipherText")
        expectation.fulfill()
        return
      }
      XCTAssertEqual(cipherText, MockConstants.mockCiphertext)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.backupProgressCallbacks)
  }
}

// MARK: - eject Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_ejectWithGDrive_willThrowCorrectError_WhenThereIsNoGDriveStorage() async throws {
    // given\
    let method: BackupMethods = .GoogleDrive
    initPortalMpcWith(
      gDriveStorage: nil,
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.eject(method)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnEject("Backup method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_ejectWithPassword_willThrowCorrectError_WhenThereIsNoPasswordStorage() async throws {
    // given\
    let method: BackupMethods = .Password
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: nil,
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.eject(method)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnEject("Backup method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_ejectWithICloud_willThrowCorrectError_WhenThereIsNoICloudStorage() async throws {
    // given\
    let method: BackupMethods = .iCloud
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: nil,
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.eject(method)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnEject("Backup method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_ejectPasskey_willThrowCorrectError_WhenThereIsNoPasskeyStorage() async throws {
    // given\
    let method: BackupMethods = .Passkey
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: nil
    )

    do {
      // and given
      _ = try await mpc?.eject(method)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnEject("Backup method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_eject_willThrowCorrectError_whenApiClientNotAvailable() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = nil
    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    do {
      // and given
      _ = try await mpc?.eject(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when the portalApi.client not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.clientInformationUnavailable)
    }
  }

  @available(iOS 16, *)
  func test_eject_willCall_apiGetClientCipherText_onlyOnce() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    // and given
    _ = try await mpc?.eject(.iCloud)

    // then
    XCTAssertEqual(portalApiMock.getClientCipherTextCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_eject_willCall_apiPrepareEject_twice() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    // and given
    _ = try await mpc?.eject(.iCloud)

    // then
    XCTAssertEqual(portalApiMock.prepareEjectCallsCount, 2)
  }

  @available(iOS 16, *)
  func test_eject_willThrowCorrectError_whenEthereumBackupShareIdNotExists() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(wallets: [.stub(curve: .ED25519), .stub(backupSharePairs: [], curve: .SECP256K1)])
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare

    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    do {
      // and given
      _ = try await mpc?.eject(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when ETH backup share not found.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unableToEjectWallet("No backed up wallet found for curve SECP256K1."))
    }
  }

  @available(iOS 16, *)
  func test_eject_willThrowCorrectError_whenThereIsNoCipherText() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: false))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    do {
      // and given
      _ = try await mpc?.eject(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when there is no cipher text passed and backup with portal disabled.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.noBackupCipherTextFound)
    }
  }

  @available(iOS 16, *)
  func test_eject_willThrowCorrectError_whenThereIsNoOrganizationShare() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: false))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    do {
      // and given
      _ = try await mpc?.eject(.iCloud, withCipherText: "dummy-cipher-text")
      XCTFail("Expected error not thrown when calling PortalMpc.eject when there is no organization share passed and backup with portal disabled.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.noOrganizationShareFound("No organization share found for Ethereum wallet."))
    }
  }

  @available(iOS 16, *)
  func test_eject_willCall_mobileMobileEjectWalletAndDiscontinueMPC_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      mobile: mobileSpy,
      iCloudStorage: mockICloudMock
    )

    // and given
    _ = try await mpc?.eject(.iCloud)

    // then
    XCTAssertEqual(mobileSpy.mobileEjectWalletAndDiscontinueMPCCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_eject_willCall_mobileMobileEjectWalletAndDiscontinueMPCEd25519_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      mobile: mobileSpy,
      iCloudStorage: mockICloudMock
    )

    // and given
    _ = try await mpc?.eject(.iCloud, andOrganizationSolanaBackupShare: "backup share value")

    // then
    XCTAssertEqual(mobileSpy.mobileEjectWalletAndDiscontinueMPCEd25519CallsCount, 1)
  }

  @available(iOS 16, *)
  func test_eject_willCall_apiEject_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.storeClientCipherTextReturnValue = true
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let mockICloudMock = PortalStorageMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: mockICloudMock
    )

    // and given
    _ = try await mpc?.eject(.iCloud)

    // then
    XCTAssertEqual(portalApiMock.ejectCallsCount, 1)
  }

  @available(iOS 16, *)

  func test_eject_willThrowCorrectError_whenEthereumWalletNotExists() async throws {
    // given
    let mockICloudMock = PortalStorageMock()
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(wallets: [.stub(curve: .ED25519)])
    mockICloudMock.decryptReturnValue = UnitTestMockConstants.decodedShare
    initPortalMpcWith(
      portalApi: portalApiMock,

      iCloudStorage: mockICloudMock
    )

    do {
      // and given
      _ = try await mpc?.eject(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.eject when ETH wallet not found.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unableToEjectWallet("No backed up wallet found for curve SECP256K1."))
    }
  }
}

// MARK: - generate Tests

extension PortalMpcTests {
  func testGenerate() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.generate()")
    let generateResponse = try await mpc?.generate()
    XCTAssert(generateResponse != nil)
    XCTAssertEqual(generateResponse?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(generateResponse?[.solana], MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGenerateCompletion() throws {
    let expectation = XCTestExpectation(description: "Generate")
    var encounteredStatuses: Set<MpcStatuses> = []
    self.mpc?.generate { addressResult in
      guard addressResult.error == nil else {
        XCTFail("Failure: \(String(describing: addressResult.error))")
        expectation.fulfill()
        return
      }
      guard let address = addressResult.data else {
        XCTFail("Unable to parse address")
        return
      }
      XCTAssertEqual(address, MockConstants.mockEip155Address)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.generateProgressCallbacks)
  }

  @available(iOS 16, *)
  func test_generate_willCall_mobileMobileGenerateEd25519_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    // and given
    _ = try await mpc?.generate()

    // then
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willCall_mobileMobileGenerateSecp256k1_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    // and given
    _ = try await mpc?.generate()

    // then
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willThrowCorrectError_WhenMpcMobileGenerateEd25519_returnError() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.inValidED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    do {
      // and given
      _ = try await mpc?.generate()
      XCTFail("Expected error not thrown when calling PortalMpc.generate when MPC MobileGenerateEd25519 return error.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, id: "error-id", message: "error message")))
    }
  }

  @available(iOS 16, *)
  func test_generate_willThrowCorrectError_WhenMpcMobileGenerateSecp256k1_returnError() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.inValidSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    do {
      // and given
      _ = try await mpc?.generate()
      XCTFail("Expected error not thrown when calling PortalMpc.generate when MPC MobileGenerateSecp256k1 return error.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, id: "error-id", message: "error message")))
    }
  }

  @available(iOS 16, *)
  func test_generate_willThrowCorrectError_WhenMpcMobileGenerateSecp256k1_returnError_andMpcMobileGenerateEd25519_returnError() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.inValidSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.inValidED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    do {
      // and given
      _ = try await mpc?.generate()
      XCTFail("Expected error not thrown when calling PortalMpc.generate when MPC MobileGenerateSecp256k1 & MobileGenerateEd25519 return error.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, id: "error-id", message: "error message")))
    }
  }

  @available(iOS 16, *)
  func test_generate_willThrowError_WhenMpcMobileGenerateSecp256k1_returnInValidJSON() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = ""
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      mobile: mobileSpy
    )

    do {
      // and given
      _ = try await mpc?.generate()
      XCTFail("Expected error not thrown when calling PortalMpc.generate when MPC MobileGenerateSecp256k1 return error.")
    } catch {
      // then
      XCTAssertNotNil(error)
    }
  }

  @available(iOS 16, *)
  func test_generate_willThrowError_WhenMpcMobileGenerateEd25519_returnInValidJSON() async throws {
    // given
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = ""
    initPortalMpcWith(
      mobile: mobileSpy
    )

    do {
      // and given
      _ = try await mpc?.generate()
      XCTFail("Expected error not thrown when calling PortalMpc.generate when MPC MobileGenerateEd25519 return error.")
    } catch {
      // then
      XCTAssertNotNil(error)
    }
  }

  @available(iOS 16, *)
  func test_generate_willCall_keychainSetShares_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()

    initPortalMpcWith(
      keychain: keychainSpy
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(keychainSpy.setSharesCallCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willCall_keychainLoadMetadata_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()

    initPortalMpcWith(
      keychain: keychainSpy
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(keychainSpy.loadMetadataCallCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willCall_keychainGetAddresses_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()

    initPortalMpcWith(
      keychain: keychainSpy
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(keychainSpy.getAddressesCallCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willCall_apiUpdateShareStatus_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()

    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    initPortalMpcWith(
      portalApi: portalApiMock
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(portalApiMock.updateShareStatusCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_willCall_apiUpdateShareStatus_passingCorrectParams() async throws {
    // given
    let portalApiMock = PortalApiMock()

    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    initPortalMpcWith(
      portalApi: portalApiMock
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(portalApiMock.updateShareStatusSharePareTypeParam, .signing)
    XCTAssertEqual(portalApiMock.updateShareStatusStatusParam, .STORED_CLIENT)
  }

  @available(iOS 16, *)
  func test_generate_willCall_apiRefreshClient_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()

    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    initPortalMpcWith(
      portalApi: portalApiMock
    )

    // and given
    _ = try await mpc?.generate()

    XCTAssertEqual(portalApiMock.refreshClientCallsCount, 1)
  }

  // MARK: - Pre-generated wallet (usePreGeneratedWallet) Tests

  func test_featureFlags_usePreGeneratedWallet_defaultsToOff() {
    // given a FeatureFlags created without specifying usePreGeneratedWallet
    let featureFlags = FeatureFlags()

    // then it defaults to nil (off) and is not treated as enabled
    XCTAssertNil(featureFlags.usePreGeneratedWallet)
    XCTAssertNotEqual(featureFlags.usePreGeneratedWallet, true)
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_usesApiAndNotBinary() async throws {
    // given
    let mockRequests = MockPortalRequests()
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: mockRequests)
    let mobileSpy = MobileSpy()
    initPortalMpcWith(
      portalApi: api,
      mobile: mobileSpy,
      featureFlags: FeatureFlags(usePreGeneratedWallet: true)
    )

    // and given
    let addresses = try await mpc?.generate()

    // then: the API path was used (single /v1/generate call) and the binary was not invoked
    let generateCallsCount = await mockRequests.generateCallsCount
    XCTAssertEqual(generateCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0)
    XCTAssertEqual(addresses?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(addresses?[.solana], MockConstants.mockSolanaAddress)
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_andApiFails_fallsBackToBinary() async throws {
    // given
    let mockRequests = MockPortalRequests(failEnclaveGenerate: true)
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: mockRequests)
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      portalApi: api,
      mobile: mobileSpy,
      featureFlags: FeatureFlags(usePreGeneratedWallet: true)
    )

    // and given
    let addresses = try await mpc?.generate()

    // then: API was attempted, then the binary fallback ran and the wallet was created
    let generateCallsCount = await mockRequests.generateCallsCount
    XCTAssertEqual(generateCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
    XCTAssertEqual(addresses?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(addresses?[.solana], MockConstants.mockSolanaAddress)
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletDisabled_usesBinaryAndNotApi() async throws {
    // given
    let mockRequests = MockPortalRequests()
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: mockRequests)
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(
      portalApi: api,
      mobile: mobileSpy,
      featureFlags: FeatureFlags(usePreGeneratedWallet: false)
    )

    // and given
    _ = try await mpc?.generate()

    // then: the binary path was used and the API was never called
    let generateCallsCount = await mockRequests.generateCallsCount
    XCTAssertEqual(generateCallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
  }

  func test_decodeStandardBase64_roundTripsMpcShare() throws {
    // given a base64 (no padding) of an MpcShare, as the Enclave MPC API returns
    let shareData = try JSONEncoder().encode(MockConstants.mockMpcShare)
    let base64NoPadding = shareData.base64EncodedString().replacingOccurrences(of: "=", with: "")

    // when
    let decoded = PortalMpc.decodeStandardBase64(base64NoPadding)

    // then it decodes back into an equivalent MpcShare
    XCTAssertNotNil(decoded)
    let mpcShare = try JSONDecoder().decode(MpcShare.self, from: decoded!)
    XCTAssertEqual(mpcShare.signingSharePairId, MockConstants.mockMpcShareId)
  }

  func test_decodeStandardBase64_handlesAllPaddingRemainders() {
    // Standard-alphabet base64 with the `=` padding stripped, as the API returns.
    XCTAssertEqual(PortalMpc.decodeStandardBase64("YWJj").flatMap { String(data: $0, encoding: .utf8) }, "abc") // len 4, no padding needed
    XCTAssertEqual(PortalMpc.decodeStandardBase64("YQ").flatMap { String(data: $0, encoding: .utf8) }, "a") // remainder 2
    XCTAssertEqual(PortalMpc.decodeStandardBase64("YWI").flatMap { String(data: $0, encoding: .utf8) }, "ab") // remainder 3
    XCTAssertEqual(PortalMpc.decodeStandardBase64("YWJjZA").flatMap { String(data: $0, encoding: .utf8) }, "abcd") // remainder 2
  }

  func test_decodeStandardBase64_returnsNil_forInvalidInput() {
    XCTAssertNil(PortalMpc.decodeStandardBase64("@@@@"))
    XCTAssertNil(PortalMpc.decodeStandardBase64("not base64!"))
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_stillUpdatesShareStatusAndRefreshesClient() async throws {
    // given
    let apiSpy = PortalApiSpy()
    apiSpy.generatePreGeneratedSharesReturnValue = try Self.makePreGeneratedApiResponse()
    initPortalMpcWith(portalApi: apiSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    _ = try await mpc?.generate()

    // then: the post-generate lifecycle steps still run exactly as with the binary path
    XCTAssertEqual(apiSpy.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(apiSpy.updateShareStatusCallsCount, 1)
    XCTAssertEqual(apiSpy.updateShareStatusTypeParam, .signing)
    XCTAssertEqual(apiSpy.updateShareStatusStatusParam, .STORED_CLIENT)
    XCTAssertEqual(apiSpy.updateShareStatusSharePairIdsParam, [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId])
    XCTAssertEqual(apiSpy.refreshClientCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_passesIosMetadataToApi() async throws {
    // given
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesReturnValue = try Self.makePreGeneratedApiResponse()
    initPortalMpcWith(portalApi: apiMock, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    _ = try await mpc?.generate()

    // then: the same metadata we send to the binary is forwarded to the API
    let metadataStr = apiMock.generatePreGeneratedSharesMetadataParam ?? ""
    XCTAssertFalse(metadataStr.isEmpty)
    let metadata = try JSONDecoder().decode(MpcMetadata.self, from: Data(metadataStr.utf8))
    XCTAssertEqual(metadata.clientPlatform, "NATIVE_IOS")
    XCTAssertEqual(metadata.mpcServerVersion, "v6")
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_storesTransformedShares() async throws {
    // given
    let mockRequests = MockPortalRequests()
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: mockRequests)
    let keychainSpy = PortalKeychainSpy()
    initPortalMpcWith(portalApi: api, keychain: keychainSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    _ = try await mpc?.generate()

    // then: the base64 API shares are transformed into the same stored format as the binary path
    XCTAssertEqual(keychainSpy.setSharesCallCount, 1)
    let stored = keychainSpy.setSharesParams.first
    XCTAssertNotNil(stored?["ED25519"])
    XCTAssertNotNil(stored?["SECP256K1"])
    XCTAssertEqual(stored?["SECP256K1"]?.id, MockConstants.mockMpcShareId)

    let storedShareString = stored?["SECP256K1"]?.share ?? ""
    let decodedMpcShare = try JSONDecoder().decode(MpcShare.self, from: Data(storedShareString.utf8))
    XCTAssertEqual(decodedMpcShare.signingSharePairId, MockConstants.mockMpcShareId)
    XCTAssertEqual(decodedMpcShare, MockConstants.mockMpcShare)
  }

  @available(iOS 16, *)
  func test_generate_whenApiShareHasEmptySigningSharePairId_surfacesErrorAndDoesNotFallBackToBinary() async throws {
    // given: an API response whose decoded MpcShare has no signingSharePairId
    let apiMock = PortalApiMock()
    let badJson = "{\"clientId\":\"\",\"signingSharePairId\":\"\",\"share\":\"s\",\"ssid\":\"x\"}"
    let badShare = Data(badJson.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
    apiMock.generatePreGeneratedSharesReturnValue = GenerateApiResponse(
      secp256k1: GenerateApiCurveShare(share: badShare, id: "id"),
      ed25519: GenerateApiCurveShare(share: badShare, id: "id")
    )
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given / then: a validation failure is not a 5xx, so it surfaces without a binary retry
    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow the share-validation error")
    } catch {
      // expected
    }

    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0)
  }

  @available(iOS 16, *)
  func test_generate_whenApiShareHasInvalidBase64_surfacesErrorAndDoesNotFallBackToBinary() async throws {
    // given: an API response with an undecodable base64 share
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesReturnValue = GenerateApiResponse(
      secp256k1: GenerateApiCurveShare(share: "@@@@", id: "id"),
      ed25519: GenerateApiCurveShare(share: "@@@@", id: "id")
    )
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given / then: a decode failure is not a 5xx, so it surfaces without a binary retry
    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow the share-decode error")
    } catch {
      // expected
    }

    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0)
  }

  @available(iOS 16, *)
  func test_generate_whenApiThrowsNon5xxError_surfacesErrorAndDoesNotFallBackToBinary() async throws {
    // given: the API method throws a non-5xx error (e.g. a network timeout)
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = URLError(.timedOut)
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given / then: only 5xx errors fall back, so this surfaces without a binary retry
    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow the non-5xx error")
    } catch {
      // expected
    }

    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0)
  }

  @available(iOS 16, *)
  func test_generate_whenApiThrows5xxError_fallsBackToBinary_viaApiDouble() async throws {
    // given: the API method throws a server-side (5xx) error
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = PortalRequestsError.internalServerError(
      "500 - simulated pre-generated wallet failure",
      url: "https://mpc-client.portalhq.io/v1/generate"
    )
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    let addresses = try await mpc?.generate()

    // then: the 5xx triggered the binary fallback, which created the wallet
    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
    XCTAssertEqual(addresses?[.eip155], MockConstants.mockEip155Address)
  }

  @available(iOS 16, *)
  func test_generate_whenUsePreGeneratedWalletEnabled_storesDecodedSigningSharePairId_notEnvelopeId() async throws {
    // given: an API response whose envelope `id` differs from the share's decoded signingSharePairId
    let apiSpy = PortalApiSpy()
    apiSpy.generatePreGeneratedSharesReturnValue = try Self.makePreGeneratedApiResponse(id: "envelope-id-that-differs")
    let keychainSpy = PortalKeychainSpy()
    initPortalMpcWith(portalApi: apiSpy, keychain: keychainSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    _ = try await mpc?.generate()

    // then: the stored id (and the id sent to updateShareStatus) uses the decoded
    // signingSharePairId, keeping the API path identical to the binary path.
    let stored = keychainSpy.setSharesParams.first
    XCTAssertEqual(stored?["SECP256K1"]?.id, MockConstants.mockMpcShareId)
    XCTAssertEqual(stored?["ED25519"]?.id, MockConstants.mockMpcShareId)
    XCTAssertEqual(apiSpy.updateShareStatusSharePairIdsParam, [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId])
  }

  @available(iOS 16, *)
  func test_generate_whenApiRejectsWith4xx_surfacesErrorAndDoesNotFallBackToBinary() async throws {
    // given: the enclave rejects the claim with a 4xx client error (e.g. "wallet already exists")
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = PortalRequestsError.clientError(
      "400 - {\"error\":\"Wallet already exists\"}",
      url: "https://mpc-client.portalhq.io/v1/generate"
    )
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given / then: a 4xx is not retryable, so it surfaces rather than falling back
    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow the 4xx client error")
    } catch {
      XCTAssertFalse(PortalMpc.isRetryableServerError(error))
    }

    // and: the binary fallback was NOT attempted
    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0)
  }

  // MARK: isRetryableServerError classifier (exhaustive)

  func test_isRetryableServerError_returnsTrue_forInternalServerError() {
    // The SDK maps any 5xx response to `.internalServerError` (see PortalRequests.buildError),
    // so classification is by error-class, independent of the specific status code or body.
    XCTAssertTrue(PortalMpc.isRetryableServerError(
      PortalRequestsError.internalServerError("500 - internal error", url: "u")
    ))
    XCTAssertTrue(PortalMpc.isRetryableServerError(
      PortalRequestsError.internalServerError("502 - bad gateway", url: "u")
    ))
    XCTAssertTrue(PortalMpc.isRetryableServerError(
      PortalRequestsError.internalServerError("503 - service unavailable", url: "u")
    ))
    XCTAssertTrue(PortalMpc.isRetryableServerError(
      PortalRequestsError.internalServerError("", url: "")
    ))
  }

  func test_isRetryableServerError_returnsFalse_forClientError() {
    XCTAssertFalse(PortalMpc.isRetryableServerError(
      PortalRequestsError.clientError("400 - {\"error\":\"Wallet already exists\"}", url: "u")
    ))
    XCTAssertFalse(PortalMpc.isRetryableServerError(
      PortalRequestsError.clientError("404 - not found", url: "u")
    ))
    XCTAssertFalse(PortalMpc.isRetryableServerError(
      PortalRequestsError.clientError("429 - too many requests", url: "u")
    ))
  }

  func test_isRetryableServerError_returnsFalse_forOtherPortalRequestsErrors() {
    XCTAssertFalse(PortalMpc.isRetryableServerError(PortalRequestsError.unauthorized))
    XCTAssertFalse(PortalMpc.isRetryableServerError(PortalRequestsError.redirectError("302 - redirect")))
    XCTAssertFalse(PortalMpc.isRetryableServerError(PortalRequestsError.couldNotParseHttpResponse))
  }

  func test_isRetryableServerError_returnsFalse_forNonRequestErrors() {
    // Network/transport errors are not classed as 5xx and therefore do not fall back.
    XCTAssertFalse(PortalMpc.isRetryableServerError(URLError(.timedOut)))
    XCTAssertFalse(PortalMpc.isRetryableServerError(URLError(.networkConnectionLost)))
    XCTAssertFalse(PortalMpc.isRetryableServerError(URLError(.cannotConnectToHost)))
    XCTAssertFalse(PortalMpc.isRetryableServerError(URLError(.notConnectedToInternet)))
    // Share transform/validation failures are not retryable either.
    XCTAssertFalse(PortalMpc.isRetryableServerError(MpcError.unableToDecodeShare))
    XCTAssertFalse(PortalMpc.isRetryableServerError(MpcError.unexpectedErrorOnGenerate("boom")))
    XCTAssertFalse(PortalMpc.isRetryableServerError(NSError(domain: "com.portal.test", code: 42)))
  }

  // MARK: generate() retry — errors that surface without falling back

  @available(iOS 16, *)
  func test_generate_whenApiThrowsUnauthorized_surfacesErrorAndDoesNotFallBackToBinary() async {
    await assertGenerateSurfacesWithoutBinaryFallback(apiError: PortalRequestsError.unauthorized)
  }

  @available(iOS 16, *)
  func test_generate_whenApiThrowsRedirectError_surfacesErrorAndDoesNotFallBackToBinary() async {
    await assertGenerateSurfacesWithoutBinaryFallback(apiError: PortalRequestsError.redirectError("302 - redirect"))
  }

  @available(iOS 16, *)
  func test_generate_whenApiThrowsCouldNotParseHttpResponse_surfacesErrorAndDoesNotFallBackToBinary() async {
    await assertGenerateSurfacesWithoutBinaryFallback(apiError: PortalRequestsError.couldNotParseHttpResponse)
  }

  @available(iOS 16, *)
  func test_generate_whenApiThrowsClientError_surfacesErrorAndDoesNotFallBackToBinary() async {
    await assertGenerateSurfacesWithoutBinaryFallback(apiError: PortalRequestsError.clientError("404 - not found", url: "u"))
  }

  // MARK: generate() retry — 5xx fallback edge cases

  @available(iOS 16, *)
  func test_generate_when5xxAndBinaryAlsoFails_surfacesError() async throws {
    // given: the API returns a 5xx (so we fall back) but the binary DKG also fails
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = PortalRequestsError.internalServerError("500 - boom", url: "u")
    // MobileSpy defaults its generate return values to "", which fails to decode -> binary throws.
    let mobileSpy = MobileSpy()
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given / then: the binary failure surfaces (no infinite retry, no swallowing)
    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow when both the API and the binary fallback fail")
    } catch {
      // expected
    }

    // and: the API was tried once, then the binary was attempted once per curve
    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_when5xxFallback_runsPostGenerateLifecycleWithBinaryShares() async throws {
    // given: the API returns a 5xx, so generation falls back to the binary path
    let apiSpy = PortalApiSpy()
    apiSpy.generatePreGeneratedSharesErrorToThrow = PortalRequestsError.internalServerError("500 - boom", url: "u")
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    let keychainSpy = PortalKeychainSpy()
    initPortalMpcWith(portalApi: apiSpy, keychain: keychainSpy, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    _ = try await mpc?.generate()

    // then: the API was attempted once and the binary produced both curves
    XCTAssertEqual(apiSpy.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)

    // and: the shared post-generate lifecycle still runs on the binary shares
    XCTAssertEqual(keychainSpy.setSharesCallCount, 1)
    XCTAssertEqual(apiSpy.updateShareStatusCallsCount, 1)
    XCTAssertEqual(apiSpy.updateShareStatusTypeParam, .signing)
    XCTAssertEqual(apiSpy.updateShareStatusStatusParam, .STORED_CLIENT)
    XCTAssertEqual(apiSpy.refreshClientCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_generate_when5xxFallback_callsApiExactlyOnce_andDoesNotRetryApi() async throws {
    // given: a 5xx from the API, with a working binary fallback
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = PortalRequestsError.internalServerError("503 - service unavailable", url: "u")
    let mobileSpy = MobileSpy()
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    // and given
    let addresses = try await mpc?.generate()

    // then: the API path is tried exactly once (single attempt, then binary), never retried
    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 1)
    XCTAssertEqual(addresses?[.eip155], MockConstants.mockEip155Address)
  }

  // MARK: Retry test helpers

  /// Drives `generate()` with the pre-generated flag enabled and the API stubbed to throw
  /// `apiError`, asserting the error surfaces (is rethrown) and the binary fallback is NOT
  /// attempted. Used for the family of non-retryable (non-5xx) errors.
  @available(iOS 16, *)
  private func assertGenerateSurfacesWithoutBinaryFallback(
    apiError: Error,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    let apiMock = PortalApiMock()
    apiMock.generatePreGeneratedSharesErrorToThrow = apiError
    let mobileSpy = MobileSpy()
    // Give the binary a valid response so, if a fallback ever fired, generation would succeed —
    // making an incorrect fallback observable as a test failure rather than a decode error.
    mobileSpy.mobileGenerateSecp256k1ReturnValue = UnitTestMockConstants.validSecp256k1ShareRotatedResultJSON
    mobileSpy.mobileGenerateEd25519ReturnValue = UnitTestMockConstants.validED25519ShareRotatedResultJSON
    initPortalMpcWith(portalApi: apiMock, mobile: mobileSpy, featureFlags: FeatureFlags(usePreGeneratedWallet: true))

    do {
      _ = try await mpc?.generate()
      XCTFail("Expected generate() to rethrow the non-retryable error", file: file, line: line)
    } catch {
      XCTAssertFalse(PortalMpc.isRetryableServerError(error), "Test error should be classified non-retryable", file: file, line: line)
    }

    XCTAssertEqual(apiMock.generatePreGeneratedSharesCallsCount, 1, "API should be attempted exactly once", file: file, line: line)
    XCTAssertEqual(mobileSpy.mobileGenerateEd25519CallsCount, 0, "Binary ED25519 must not run for a non-retryable error", file: file, line: line)
    XCTAssertEqual(mobileSpy.mobileGenerateSecp256k1CallsCount, 0, "Binary SECP256K1 must not run for a non-retryable error", file: file, line: line)
  }

  private static func makePreGeneratedApiResponse(id: String = MockConstants.mockMpcShareId) throws -> GenerateApiResponse {
    let share = try MockConstants.mockBase64EncodedMpcShare
    return GenerateApiResponse(
      secp256k1: GenerateApiCurveShare(share: share, id: id),
      ed25519: GenerateApiCurveShare(share: share, id: id)
    )
  }
}

// MARK: - Recover Tests

extension PortalMpcTests {
  func testRecover() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.recover()")
    let recoverResponse = try await mpc?.generate()
    XCTAssert(recoverResponse != nil)
    XCTAssertEqual(recoverResponse?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(recoverResponse?[.solana], MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRecoverCompletion() throws {
    let expectation = XCTestExpectation(description: "Recover")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    var encounteredStatuses: Set<MpcStatuses> = Set()
    self.mpc?.recover(cipherText: MockConstants.mockCiphertext, method: BackupMethods.Password.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }
      guard let address = result.data else {
        XCTFail("Unable to parse addresses")
        return
      }
      XCTAssertEqual(address, MockConstants.mockEip155Address)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.recoverProgressCallbacks)
  }

  @available(iOS 16, *)
  func test_recover_willThrowCorrectError_whenApiClientIsNil() async throws {
    // given
    let portalApiMock = PortalApiMock()

    initPortalMpcWith(
      portalApi: portalApiMock
    )

    do {
      // and given
      _ = try await mpc?.recover(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when api.client not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.clientInformationUnavailable)
    }
  }

  @available(iOS 16, *)
  func test_recover_willThrowCorrectError_whenBackupWithPortalDisabled_andPassingNoCipherText() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: false))
    initPortalMpcWithDefaultStorageAnd(portalApi: portalApiMock)

    do {
      // and given
      _ = try await mpc?.recover(.iCloud)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when there is no cipher text passed and backup with portal disabled.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.noBackupCipherTextFound)
    }
  }

  @available(iOS 16, *)
  func test_recover_willCall_apiGetClientCipherText_whenBackupWithPortalEnabled_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try MockConstants.mockMpcShareString
    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(portalApiMock.getClientCipherTextCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_recoverWithGDrive_willThrowCorrectError_WhenThereIsNoGDriveStorage() async throws {
    // given
    let method: BackupMethods = .GoogleDrive
    initPortalMpcWith(
      gDriveStorage: nil,
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.recover(method, withCipherText: MockConstants.mockCiphertext)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnRecover("Storage method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_recoverWithPassword_willThrowCorrectError_WhenThereIsNoPasswordStorage() async throws {
    // given
    let method: BackupMethods = .Password
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: nil,
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.recover(method, withCipherText: MockConstants.mockCiphertext)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnRecover("Storage method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_recoverWithICloud_willThrowCorrectError_WhenThereIsNoICloudStorage() async throws {
    // given
    let method: BackupMethods = .iCloud
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: nil,
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and given
      _ = try await mpc?.recover(method, withCipherText: MockConstants.mockCiphertext)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnRecover("Storage method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_recoverWithPasskey_willThrowCorrectError_WhenThereIsNoPasskeyStorage() async throws {
    // given
    let method: BackupMethods = .Passkey
    initPortalMpcWith(
      gDriveStorage: MockGDriveStorage(),
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: nil
    )

    do {
      // and given
      _ = try await mpc?.recover(method, withCipherText: MockConstants.mockCiphertext)
      XCTFail("Expected error not thrown when calling PortalMpc.recover when the passed method storage not available.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnRecover("Storage method \(method.rawValue) not registered."))
    }
  }

  @available(iOS 16, *)
  func test_recover_willCall_storageRead_onlyOnce() async throws {
    // given
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try MockConstants.mockMpcShareString
    initPortalMpcWith(
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(iCloudStorageMock.readCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_storageDecrypt_onlyOnce() async throws {
    // given
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString
    initPortalMpcWith(
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(iCloudStorageMock.decryptCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_keychainGetShares_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      keychain: keychainSpy,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(keychainSpy.getSharesCallCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_keychainSetShares_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      keychain: keychainSpy,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(keychainSpy.setSharesCallCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_apiUpdateShareStatus_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.storeClientCipherTextReturnValue = true
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(portalApiMock.updateShareStatusCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_apiUpdateShareStatus_passingCorrectParams() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(portalApiMock.updateShareStatusSharePareTypeParam, .signing)
    XCTAssertEqual(portalApiMock.updateShareStatusStatusParam, .STORED_CLIENT)
  }

  @available(iOS 16, *)
  func test_recover_willCall_apiRefreshClient_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      portalApi: portalApiMock,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(portalApiMock.refreshClientCallsCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_keychainLoadMetadata_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      keychain: keychainSpy,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(keychainSpy.loadMetadataCallCount, 1)
  }

  @available(iOS 16, *)
  func test_recover_willCall_keychainGetAddresses_onlyOnce() async throws {
    // given
    let keychainSpy = PortalKeychainSpy()
    let iCloudStorageMock = ICloudStorageMock()
    iCloudStorageMock.decryptReturnValue = try UnitTestMockConstants.mockGenerateResponseString

    initPortalMpcWith(
      keychain: keychainSpy,
      iCloudStorage: iCloudStorageMock
    )

    // and given
    _ = try await mpc?.recover(.iCloud, withCipherText: MockConstants.mockCiphertext)

    // then
    XCTAssertEqual(keychainSpy.getAddressesCallCount, 1)
  }
}

// MARK: - generateSolanaWallet Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_generateSolanaWallet_willThrowCorrectError_whenThereIsNoETHWallet() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [:]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
      XCTFail("Expected error not thrown when calling PortalMpc.generateSolanaWallet when there is no eth wallet.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnGenerate("PortalMpc.generateSolanaWallet() - No eip155 wallet found. Please use createWallet() to generate both eip155 and solana wallets for this client."))
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willThrowCorrectError_whenThereIsSolanaWallet() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address",
      .solana: "dummy-solana-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
      XCTFail("Expected error not thrown when calling PortalMpc.generateSolanaWallet when there is splana wallet.")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.unexpectedErrorOnGenerate("PortalMpc.generateSolanaWallet() - Could not generate Solana wallet as it already exists."))
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_keychainGetAddresses_twice() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(keychainSpy.getAddressesCallCount, 2)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_keychainGetShares_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(keychainSpy.getSharesCallCount, 1)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_keychainSetShares_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(keychainSpy.setSharesCallCount, 1)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_apiUpdateShareStatus_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(portalApiMock.updateShareStatusCallsCount, 1)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_apiUpdateShareStatus_passingCorrectParams() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(portalApiMock.updateShareStatusSharePareTypeParam, .signing)
      XCTAssertEqual(portalApiMock.updateShareStatusStatusParam, .STORED_CLIENT)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_keychainLoadMetadata_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(keychainSpy.loadMetadataCallCount, 1)
    }
  }

  @available(iOS 16, *)
  func test_generateSolanaWallet_willCall_apiRefreshClient_onlyOnce() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = ClientResponse.stub(environment: ClientResponseEnvironment.stub(backupWithPortalEnabled: true))
    let keychainSpy = PortalKeychainSpy()
    keychainSpy.getAddressesReturnValue = [
      .eip155: "dummy-eip155-address"
    ]

    initPortalMpcWith(
      portalApi: portalApiMock,
      keychain: keychainSpy
    )

    do {
      // and given
      _ = try await mpc?.generateSolanaWallet()
    } catch {
      // then
      XCTAssertEqual(portalApiMock.refreshClientCallsCount, 1)
    }
  }
}

// MARK: - setGDriveConfiguration Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_setGDriveConfiguration_willThrowCorrectError_whenThereIsNoGDriveStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: nil,
      passwordStorage: MockPasswordStorage(),
      iCloudStorage: MockICloudStorage(),
      passKeyStorage: MockPasskeyStorage()
    )

    do {
      // and give
      _ = try mpc?.setGDriveConfiguration(clientId: "", backupOption: .appDataFolder)
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.backupMethodNotRegistered("PortalMpc.setGDriveConfig() - Could not find an instance of `GDriveStorage`. Please use `portal.registerBackupMethod()`"))
    }
  }

  @available(iOS 16, *)
  func test_setGDriveConfiguration_willPassCorrectValues_toGDriveStorage() async throws {
    // given
    let clientId = "client-id"
    let folderName = "folder-name"
    let gDriveStorage = GDriveStorage()
    initPortalMpcWith(
      gDriveStorage: gDriveStorage
    )

    // and give
    _ = try mpc?.setGDriveConfiguration(clientId: clientId, backupOption: .gdriveFolder(folderName: folderName))

    // then
    XCTAssertEqual(gDriveStorage.clientId, clientId)
    XCTAssertEqual(gDriveStorage.folder, folderName)
  }
}

// MARK: - setGDriveView Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_setGDriveView_willThrowCorrectError_whenThereIsNoGDriveStorage() async throws {
    // given
    initPortalMpcWith(
      gDriveStorage: nil
    )

    do {
      // and give
      _ = try await mpc?.setGDriveView(UIViewController())
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.backupMethodNotRegistered("PortalMpc.setGDriveView() - Could not find an instance of `GDriveStorage`. Please use `portal.registerBackupMethod()`"))
    }
  }

  @available(iOS 16, *)
  func test_setGDriveView_willPassCorrectView_toGDriveStorage() async throws {
    // given
    let view = await UIViewController()
    let gDriveStorage = GDriveStorage()
    initPortalMpcWith(
      gDriveStorage: gDriveStorage
    )

    // and give
    _ = try mpc?.setGDriveView(view)

    // then
    XCTAssertEqual(gDriveStorage.view, view)
  }
}

// MARK: - setPasskeyAuthenticationAnchor Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_setPasskeyAuthenticationAnchor_willThrowCorrectError_whenThereIsNoPassKeyStorage() async throws {
    // given
    initPortalMpcWith(
      passKeyStorage: nil
    )

    do {
      // and give
      _ = try await mpc?.setPasskeyAuthenticationAnchor(UIWindow())
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.backupMethodNotRegistered("PortalMpc.setPasskeyAuthenticationAnchor() - Could not find an instance of `PasskeyStorage`. Please use `portal.registerBackupMethod()`"))
    }
  }

  @available(iOS 16, *)
  func test_setPasskeyAuthenticationAnchor_willPassCorrectView_toPasskeyStorage() async throws {
    // given
    let passkeyStorage = PasskeyStorage()
    let anchor = await UIWindow()
    initPortalMpcWith(
      passKeyStorage: passkeyStorage
    )

    // and give
    _ = try mpc?.setPasskeyAuthenticationAnchor(anchor)

    // then
    XCTAssertEqual(passkeyStorage.anchor, anchor)
  }
}

// MARK: - setPasskeyConfiguration Tests

extension PortalMpcTests {
  @available(iOS 16, *)
  func test_setPasskeyConfiguration_willThrowCorrectError_whenThereIsNoPassKeyStorage() async throws {
    // given
    initPortalMpcWith(
      passKeyStorage: nil
    )

    do {
      // and give
      _ = try mpc?.setPasskeyConfiguration(relyingParty: "", webAuthnHost: "")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.backupMethodNotRegistered("PortalMpc.setPasskeyConfiguration() - Could not find an instance of `PasskeyStorage`. Please use `portal.registerBackupMethod()`"))
    }
  }

  @available(iOS 16, *)
  func test_setPasskeyConfiguration_willPassCorrectView_toPasskeyStorage() async throws {
    // given
    let passkeyStorage = PasskeyStorage()
    let relyingParty = "relying-party"
    let webAuthnHost = "web-authn-host"
    initPortalMpcWith(
      passKeyStorage: passkeyStorage
    )

    // and give
    _ = try mpc?.setPasskeyConfiguration(relyingParty: relyingParty, webAuthnHost: webAuthnHost)

    XCTAssertEqual(passkeyStorage.relyingParty, relyingParty)
    XCTAssertEqual(passkeyStorage.webAuthnHost, "https://\(webAuthnHost)")
  }
}

// MARK: - setPassword Tests

extension PortalMpcTests {
  func test_setPassword_willThrowCorrectError_whenThereIsNoPasswordStorage() async throws {
    // given
    initPortalMpcWith(
      passwordStorage: nil
    )

    do {
      // and give
      _ = try mpc?.setPassword("")
    } catch {
      // then
      XCTAssertEqual(error as? MpcError, MpcError.backupMethodNotRegistered("Could not find an instance of `PasswordStorage`. Please use `portal.registerBackupMethod()`"))
    }
  }

  func test_setPassword_willPassCorrectView_toPasswordStorage() async throws {
    // given
    let passwordStorage = PasswordStorage()
    let password = "test-password"
    initPortalMpcWith(
      passwordStorage: passwordStorage
    )

    // and give
    _ = try mpc?.setPassword(password)

    XCTAssertEqual(passwordStorage.password, password)
  }
}

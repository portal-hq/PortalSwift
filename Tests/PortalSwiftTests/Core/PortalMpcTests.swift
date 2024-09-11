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

  override func setUpWithError() throws {
    self.mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests()),
      keychain: MockPortalKeychain(),
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

  func testEject() throws {}

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
}

// MARK: - Test Helpers

extension PortalMpcTests {
    func initPortalMpcWith(
        portalApi: PortalApiProtocol = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests()),
        keychain: PortalKeychainProtocol = MockPortalKeychain(),
        mobile: Mobile = MockMobileWrapper(),
        gDriveStorage: PortalStorage? = nil,
        passwordStorage: PortalStorage? = nil,
        iCloudStorage: PortalStorage? = nil,
        passKeyStorage: PortalStorage? = nil
    ) {
        self.mpc = PortalMpc(
          apiKey: MockConstants.mockApiKey,
          api: portalApi,
          keychain: keychain,
          mobile: mobile
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
        let portalKeychainSpy = PortalKeychainProtocolSpy()
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
    func test_backup_willCall_apiRefreshClient_onlyOnce() async throws {
        // given
        let portalKeychainSpy = PortalKeychainProtocolSpy()
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
            XCTAssertEqual(error as? MpcError, MpcError.unableToEjectWallet("No backup share pair found for curve SECP256K1."))
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
        _ = try await mpc?.eject(.iCloud)

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
}

// MARK: - generate Tests
extension PortalMpcTests { }

// MARK: -  Tests
extension PortalMpcTests { }

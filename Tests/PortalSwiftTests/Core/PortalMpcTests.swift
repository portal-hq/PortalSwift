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
        _ = try await mpc?.eject(.iCloud, andOrganizationSolanaBackupShare: "")

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
        _ = try await mpc?.eject(.iCloud, andOrganizationSolanaBackupShare: "solana org backup share")

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
            XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, message: "error message")))
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
            XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, message: "error message")))
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
            XCTAssertEqual(error as? PortalMpcError, PortalMpcError(PortalError(code: 400, message: "error message")))
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
            .eip155 : "dummy-eip155-address",
            .solana : "dummy-solana-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            .eip155 : "dummy-eip155-address"
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
            _ = try mpc?.setGDriveConfiguration(clientId: "", folderName: "")
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
        _ = try mpc?.setGDriveConfiguration(clientId: clientId, folderName: folderName)
        
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

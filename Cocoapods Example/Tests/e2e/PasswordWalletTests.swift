@testable import Cocoapods_Example
import PortalSwift
import XCTest

class PasswordWalletTests: XCTestCase {
  static var user: UserResult?
  static var username: String?
  static var PortalWrap: PortalWrapper!
  static var testAGenerateSucceeded = false

  static func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let randomPart = String((0 ..< length).map { _ in letters.randomElement()! })
    let timestamp = String(Int(Date().timeIntervalSince1970))
    return randomPart + timestamp
  }

  override class func setUp() {
    super.setUp()
    self.username = self.randomString(length: 15)
    print("username: ", self.username!)
    self.PortalWrap = PortalWrapper()
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testLogin(chainId _: Int = 11_155_111, completion: @escaping (Result<Bool>) -> Void) {
    XCTContext.runActivity(named: "Login") { _ in
      let registerExpectation = XCTestExpectation(description: "Register")

      PasswordWalletTests.PortalWrap.signIn(username: PasswordWalletTests.username!) { (result: Result<UserResult>) in
        guard result.error == nil else {
          registerExpectation.fulfill()
          return XCTFail("Failed on sign In: \(result.error!)")
        }
        let userResult = result.data!
        print("✅ handleSignIn(): API key:", userResult.clientApiKey)
        PasswordWalletTests.user = userResult
        let backup = BackupOptions(passwordStorage: PasswordStorage())
        PasswordWalletTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
          result in
          guard result.error == nil else {
            registerExpectation.fulfill()
            return XCTFail("Unable to register Portal")
          }
          registerExpectation.fulfill()
          return completion(result)
        }
      }
      wait(for: [registerExpectation], timeout: 60)
    }
  }

  func testAGenerate() {
    let registerExpectation = XCTestExpectation(description: "Register")
    let generateExpectation = XCTestExpectation(description: "Generate")

    PasswordWalletTests.PortalWrap.signUp(username: PasswordWalletTests.username!) { (result: Result<UserResult>) in
      guard result.error == nil else {
        XCTFail("Failed on sign up: \(result.error!)")
        generateExpectation.fulfill()
        return
      }
      let userResult = result.data!
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      PasswordWalletTests.user = userResult
      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backup = BackupOptions(local: backupOption)
      print("registering portal")
      PasswordWalletTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup, chainId: 11_155_111, optimized: true) {
        result in
        guard result.error == nil else {
          registerExpectation.fulfill()
          generateExpectation.fulfill()
          return XCTFail("Unable to register Portal")
        }
        registerExpectation.fulfill()
        print(result.data!)
        PasswordWalletTests.PortalWrap.generate { result in
          guard result.error == nil else {
            generateExpectation.fulfill()
            return XCTFail()
          }
          PasswordWalletTests.testAGenerateSucceeded = true
          generateExpectation.fulfill()

          XCTAssertTrue(!(result.data!.isEmpty), "The string should be empty")
        }
      }
    }
    wait(for: [generateExpectation], timeout: 200)
  }

  func testBSign() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth sign")
    var address: String? = "0x290766b47d6ea98bae2bd189cc8c7b4aa3154371"

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      if let portal = PasswordWalletTests.PortalWrap.portal {
        do {
          address = try portal.keychain.getAddress()
        } catch {
          return XCTFail("Failed to get address: \(error)")
        }

        let params = [address!, "0xdeadbeaf"]

        PasswordWalletTests.PortalWrap.ethSign(params: params) { result in
          guard result.error == nil else {
            ethSignExpectation.fulfill()
            return XCTFail("Failed on eth_sign: \(result.error!)")
          }

          print("✅ eth_sign result: ", result.data!)
          XCTAssertFalse(result.data!.isEmpty, "eth sign success")

          ethSignExpectation.fulfill()
        }
      } else {
        return XCTFail("Failed to register portal object.")
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testCBackup() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let backupExpectation = XCTestExpectation(description: "Backup")

    self.testLogin { result in
      guard result.error == nil else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }

      let backupConfigs = try! BackupConfigs(passwordStorage: PasswordStorageConfig(password: "12345"))

      PasswordWalletTests.PortalWrap.backup(backupMethod: BackupMethods.Password.rawValue, user: PasswordWalletTests.user!, backupConfigs: backupConfigs) { backupResult in
        guard backupResult.error == nil else {
          print("❌ handleBackup():", result.error!)

          do {
            try PasswordWalletTests.PortalWrap.portal?.api.storedClientBackupShare(success: false) { result in
              guard result.error == nil else {
                backupExpectation.fulfill()
                return XCTFail("Backup failed \(String(describing: result.error))")
              }
            }
          } catch {
            backupExpectation.fulfill()
            return XCTFail("Backup failed: Error notifying Portal that backup share was not stored.")
          }
          backupExpectation.fulfill()
          return XCTFail("Backup failed: Error notifying Portal that backup share was not stored.")
        }

        do {
          try PasswordWalletTests.PortalWrap.portal?.api.storedClientBackupShare(success: true) { _ in
            guard backupResult.error == nil else {
              print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
              return
            }
            backupExpectation.fulfill()
            XCTAssertTrue((backupResult.data?.isEmpty) != nil, "Backup Success")
            print("✅ Backup: Successfully sent custodian cipherText")
          }
        } catch {
          print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
        }
      }
    }
    wait(for: [backupExpectation], timeout: 60)
  }

  func testRecover() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }
    let recoverExpectation = XCTestExpectation(description: "Recover")

    self.testLogin { result in
      guard result.error == nil else {
        recoverExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      let backupConfigs = try! BackupConfigs(passwordStorage: PasswordStorageConfig(password: "12345"))

      PasswordWalletTests.PortalWrap.recover(backupMethod: BackupMethods.Password.rawValue, user: PasswordWalletTests.user!, backupConfigs: backupConfigs) { result in
        guard result.error == nil else {
          recoverExpectation.fulfill()
          return XCTFail("Recover failed \(String(describing: result.error))")
        }
        recoverExpectation.fulfill()
        return XCTAssertTrue(result.data!, "Recover Success")
      }
    }
    wait(for: [recoverExpectation], timeout: 120)
  }

  func testEject() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }
    let ejectExpectation = XCTestExpectation(description: "Eject")

    self.testLogin { result in
      guard result.error == nil else {
        ejectExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      let backupConfigs = try! BackupConfigs(passwordStorage: PasswordStorageConfig(password: "12345"))

      PasswordWalletTests.PortalWrap.eject(backupMethod: BackupMethods.Password.rawValue, user: PasswordWalletTests.user!, backupConfigs: backupConfigs) { result in
        guard result.error == nil else {
          ejectExpectation.fulfill()
          return XCTFail("Eject failed \(String(describing: result.error))")
        }
        ejectExpectation.fulfill()
        return XCTAssertFalse(result.data!.isEmpty, "Eject Success")
      }
    }
    wait(for: [ejectExpectation], timeout: 120)
  }

  func testZSign() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth sign")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }

      PasswordWalletTests.PortalWrap.portal?.ethSign(message: "0xdeadbeaf") { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(result.error!)")
        }

        print("✅ eth_sign result: ", result.data!)
        XCTAssertFalse((result.data!.result as! Result<SignerResult>).data!.signature!.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testZSignTypedDataV3() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth signTypedData")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }

      PasswordWalletTests.PortalWrap.portal?.ethSignTypedDataV3(message: mockSignedTypeDataMessage) { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(result.error!)")
        }

        print("✅ eth_sign result: ", result.data!)
        XCTAssertFalse((result.data!.result as! Result<SignerResult>).data!.signature!.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testZSignTypedDataV4() {
    if !PasswordWalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth signTypedData")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }

      PasswordWalletTests.PortalWrap.portal?.ethSignTypedData(message: mockSignedTypeDataMessage) { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(result.error!)")
        }

        print("✅ eth_sign result: ", result.data!)
        XCTAssertFalse((result.data!.result as! Result<SignerResult>).data!.signature!.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }
}

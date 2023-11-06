@testable import SPM_Example
import PortalSwift
import XCTest

class WalletTests: XCTestCase {
  static var user: UserResult?
  static var username: String?
  static var PortalWrap: PortalWrapper!
  static var testAGenerateSucceeded = false

  static func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let randomPart = String((0 ..< length).map { _ in letters.randomElement() ?? "a" })
    let timestamp = String(Int(Date().timeIntervalSince1970))
    return randomPart + timestamp
  }

  override class func setUp() {
    super.setUp()
    self.username = self.randomString(length: 15)
    print("Username: ", self.username ?? "")
    self.PortalWrap = PortalWrapper()
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testLogin(chainId _: Int = 5, completion: @escaping (Result<Bool>) -> Void) {
    XCTContext.runActivity(named: "Login") { _ in
      let registerExpectation = XCTestExpectation(description: "Register")

      WalletTests.PortalWrap.signIn(username: WalletTests.username ?? "") { (result: Result<UserResult>) in
        guard result.error == nil else {
          registerExpectation.fulfill()
          return XCTFail("Failed on sign in: \(String(describing: result.error))")
        }
        guard let userResult = result.data else {
          return XCTFail("Failed on sign in: UserResult unable to be unpacked")
        }
        print("✅ handleSignIn(): API key:", userResult.clientApiKey)
        WalletTests.user = userResult
        let backupOption = LocalFileStorage()
        let backup = BackupOptions(local: backupOption)
        WalletTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
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

    WalletTests.PortalWrap.signUp(username: WalletTests.username ?? "") { (result: Result<UserResult>) in
      guard result.error == nil else {
        XCTFail("Failed on sign up: \(String(describing: result.error))")
        generateExpectation.fulfill()
        return
      }
      guard let userResult = result.data else {
        return XCTFail("Failed on sign up: UserResult unable to be unpacked")
      }
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      WalletTests.user = userResult
      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backup = BackupOptions(local: backupOption)
      print("registering portal")
      WalletTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup, chainId: 5, optimized: true) {
        result in
        guard result.error == nil else {
          registerExpectation.fulfill()
          generateExpectation.fulfill()
          return XCTFail("Unable to register Portal")
        }
        registerExpectation.fulfill()
        print(result.data ?? "")
        WalletTests.PortalWrap.generate { result in
          guard result.error == nil else {
            generateExpectation.fulfill()
            return XCTFail()
          }
          WalletTests.testAGenerateSucceeded = true
          generateExpectation.fulfill()

          XCTAssertTrue((result.data?.isEmpty) != nil, "The string should be empty")
        }
      }
    }
    wait(for: [generateExpectation], timeout: 200)
  }

  func testBSign() {
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth sign")
    var address: String? = "0x290766b47d6ea98bae2bd189cc8c7b4aa3154371"

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }
      if let portal = WalletTests.PortalWrap.portal {
        do {
          address = try portal.keychain.getAddress()
        } catch {
          return XCTFail("Failed to get address: \(error)")
        }

        let params = [address ?? "", "0xdeadbeaf"]

        WalletTests.PortalWrap.ethSign(params: params) { result in
          guard result.error == nil else {
            ethSignExpectation.fulfill()
            return XCTFail("Failed on eth_sign: \(String(describing: result.error))")
          }

          print("✅ eth_sign result: ", result.data ?? "")
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
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let backupExpectation = XCTestExpectation(description: "Backup")

    self.testLogin { result in
      guard result.error == nil else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }

      guard let user = WalletTests.user else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }

      WalletTests.PortalWrap.backup(backupMethod: BackupMethods.local.rawValue, user: user) { backupResult in
        guard backupResult.error == nil else {
          print("❌ handleBackup():", result.error ?? "")

          do {
            try WalletTests.PortalWrap.portal?.api.storedClientBackupShare(success: false) { result in
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
          try WalletTests.PortalWrap.portal?.api.storedClientBackupShare(success: true) { _ in
            guard backupResult.error == nil else {
              print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
              return
            }
            backupExpectation.fulfill()
            XCTAssertTrue(backupResult.data != nil, "Backup Success")
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
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }
    let recoverExpectation = XCTestExpectation(description: "Recover")

    guard let user = WalletTests.user else {
      recoverExpectation.fulfill()
      return XCTFail("Failed on login")
    }

    self.testLogin { result in
      guard result.error == nil else {
        recoverExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }
      WalletTests.PortalWrap.recover(backupMethod: BackupMethods.local.rawValue, user: user) { result in
        guard result.error == nil else {
          recoverExpectation.fulfill()
          return XCTFail("Recover failed \(String(describing: result.error))")
        }
        recoverExpectation.fulfill()
        return XCTAssertTrue(result.data != nil, "Recover Success")
      }
    }
    wait(for: [recoverExpectation], timeout: 120)
  }

  func testZSign() {
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth sign")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }

      WalletTests.PortalWrap.portal?.ethSign(message: "0xdeadbeaf") { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(String(describing: result.error))")
        }

        print("✅ eth_sign result: ", result.data ?? "")
        guard let response = result.data?.result as? Result<SignerResult> else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to parse result.data.result")
        }

        guard let signature = response.data?.signature else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to derive signature from result.data.result")
        }

        XCTAssertFalse(signature.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testZSignTypedDataV3() {
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth signTypedData")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }

      WalletTests.PortalWrap.portal?.ethSignTypedDataV3(message: mockSignedTypeDataMessage) { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(String(describing: result.error))")
        }

        print("✅ eth_sign result: ", result.data ?? "")
        guard let response = result.data?.result as? Result<SignerResult> else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to parse result.data.result")
        }

        guard let signature = response.data?.signature else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to derive signature from result.data.result")
        }

        XCTAssertFalse(signature.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testZSignTypedDataV4() {
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let ethSignExpectation = XCTestExpectation(description: "eth signTypedData")

    self.testLogin { result in
      guard result.error == nil else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(String(describing: result.error))")
      }

      WalletTests.PortalWrap.portal?.ethSignTypedData(message: mockSignedTypeDataMessage) { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(String(describing: result.error))")
        }

        print("✅ eth_sign result: ", result.data ?? "")
        guard let response = result.data?.result as? Result<SignerResult> else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to parse result.data.result")
        }

        guard let signature = response.data?.signature else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: Unable to derive signature from result.data.result")
        }

        XCTAssertFalse(signature.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }
}

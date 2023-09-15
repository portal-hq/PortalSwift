import PortalSwift
@testable import PortalSwift_Example
import XCTest

class WalletTests: XCTestCase {
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

  func testLogin(chainId _: Int = 5, completion: @escaping (Result<Bool>) -> Void) {
    return XCTContext.runActivity(named: "Login") { _ in
      let registerExpectation = XCTestExpectation(description: "Register")

      WalletTests.PortalWrap.signIn(username: WalletTests.username!) { (result: Result<UserResult>) in
        guard result.error == nil else {
          registerExpectation.fulfill()
          return XCTFail("Failed on sign In: \(result.error!)")
        }
        let userResult = result.data!
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

    WalletTests.PortalWrap.signUp(username: WalletTests.username!) { (result: Result<UserResult>) in
      guard result.error == nil else {
        XCTFail("Failed on sign up: \(result.error!)")
        generateExpectation.fulfill()
        return
      }
      let userResult = result.data!
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      WalletTests.user = userResult
      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backup = BackupOptions(local: backupOption)
      print("registering portal")
      WalletTests.PortalWrap.registerPortal(apiKey: userResult.clientApiKey, backup: backup, chainId: 5) {
        result in
        guard result.error == nil else {
          registerExpectation.fulfill()
          generateExpectation.fulfill()
          return XCTFail("Unable to register Portal")
        }
        registerExpectation.fulfill()
        print(result.data!)
        WalletTests.PortalWrap.generate { result in
          guard result.error == nil else {
            generateExpectation.fulfill()
            return XCTFail()
          }
          WalletTests.testAGenerateSucceeded = true
          generateExpectation.fulfill()

          XCTAssertTrue(!(result.data!.isEmpty), "The string should be empty")
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
        return XCTFail("Failed on login: \(result.error!)")
      }
      if let portal = WalletTests.PortalWrap.portal {
        do {
          address = try portal.keychain.getAddress()
        } catch {
          return XCTFail("Failed to get address: \(error)")
        }

        let params = [address!, "0xdeadbeaf"]

        WalletTests.PortalWrap.ethSign(params: params) { result in
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
    if !WalletTests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let backupExpectation = XCTestExpectation(description: "Backup")

    self.testLogin { result in
      guard result.error == nil else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      WalletTests.PortalWrap.backup(backupMethod: BackupMethods.local.rawValue, user: WalletTests.user!) { backupResult in
        guard backupResult.error == nil else {
          print("❌ handleBackup():", result.error!)

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
            XCTAssertTrue(backupResult.data!, "Backup Success")
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

    self.testLogin { result in
      guard result.error == nil else {
        recoverExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      WalletTests.PortalWrap.recover(backupMethod: BackupMethods.local.rawValue, user: WalletTests.user!) { result in
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
  
  func testZSign() {
    if !WalletTests.testAGenerateSucceeded {
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
      if let portal = WalletTests.PortalWrap.portal {
        do {
          address = try portal.keychain.getAddress()
        } catch {
          return XCTFail("Failed to get address: \(error)")
        }

        let params = [address!, "0xdeadbeaf"]

        WalletTests.PortalWrap.ethSign(params: params) { result in
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
}

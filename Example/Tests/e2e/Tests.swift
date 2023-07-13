import PortalSwift
@testable import PortalSwift_Example
import XCTest

class Tests: XCTestCase {
  static var user: UserResult?
  static var username: String?
  static var PortalWrap: PortalWrapper?
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
    print("USERNAME: ", self.username!)
    self.PortalWrap = PortalWrapper()
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testLogin(completion: @escaping (Result<Bool>) -> Void) {
    return XCTContext.runActivity(named: "Login") { _ in
      let registerExpectation = XCTestExpectation(description: "Register")

      Tests.PortalWrap?.signIn(username: Tests.username!) { (result: Result<UserResult>) in
        guard result.error == nil else {
          registerExpectation.fulfill()
          return XCTFail("Failed on sign In: \(result.error!)")
        }
        let userResult = result.data!
        print("✅ handleSignIn(): API key:", userResult.clientApiKey)
        Tests.user = userResult
        let backupOption = LocalFileStorage()
        let backup = BackupOptions(local: backupOption)
        Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
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

    Tests.PortalWrap?.signUp(username: Tests.username!) { (result: Result<UserResult>) in
      guard result.error == nil else {
        XCTFail("Failed on sign up: \(result.error!)")
        registerExpectation.fulfill()
        generateExpectation.fulfill()
        return
      }
      let userResult = result.data!
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      Tests.user = userResult
      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backup = BackupOptions(local: backupOption)
      print("registering portal")
      Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
        result in
        guard result.error == nil else {
          registerExpectation.fulfill()
          generateExpectation.fulfill()
          return XCTFail("Unable to register Portal")
        }
        registerExpectation.fulfill()
        print(result.data!)
        Tests.PortalWrap?.generate { result in
          guard result.error == nil else {
            generateExpectation.fulfill()
            return XCTFail()
          }
          Tests.testAGenerateSucceeded = true
          generateExpectation.fulfill()

          XCTAssertTrue(!(result.data!.isEmpty), "The string should be empty")
        }
      }
    }
    wait(for: [generateExpectation], timeout: 200)
  }

  func testBSign() {
    if !Tests.testAGenerateSucceeded {
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
      do {
        address = try Tests.PortalWrap?.portal?.keychain.getAddress()
      } catch {
        return XCTFail("Failed to get address: \(error)")
      }

      let params = [address!, "0xdeadbeaf"]

      Tests.PortalWrap?.ethSign(params: params) { result in
        guard result.error == nil else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(result.error!)")
        }

        print("✅ eth_sign result: ", result.data!)
        XCTAssertFalse(result.data!.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }

    wait(for: [ethSignExpectation], timeout: 30)
  }

  func testCBackup() {
    if !Tests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }

    let backupExpectation = XCTestExpectation(description: "Backup")

    self.testLogin { result in
      guard result.error == nil else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      Tests.PortalWrap?.backup(backupMethod: BackupMethods.local.rawValue, user: Tests.user!) { backupResult in
        guard backupResult.error == nil else {
          print("❌ handleBackup():", result.error!)

          do {
            try Tests.PortalWrap?.portal?.api.storedClientBackupShare(success: false) { result in
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
          try Tests.PortalWrap?.portal?.api.storedClientBackupShare(success: true) { _ in
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
    if !Tests.testAGenerateSucceeded {
      XCTFail("Failing fast - Generate test failed to complete successfully")
      return
    }
    let recoverExpectation = XCTestExpectation(description: "Recover")

    self.testLogin { result in
      guard result.error == nil else {
        recoverExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      Tests.PortalWrap?.recover(backupMethod: BackupMethods.local.rawValue, user: Tests.user!) { result in
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
}

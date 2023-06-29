import XCTest
import PortalSwift
@testable import PortalSwift_Example

class Tests: XCTestCase {
  static var user: UserResult?
  static var username: String?
  static var PortalWrap: PortalWrapper?
  
  static func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
  }
  
  override class func setUp() {
      super.setUp()
      username = "Sb5U00bIuQS5rv1" // randomString(length: 15)
      print("USERNAME: ", username!)
      PortalWrap = PortalWrapper()
    }
  

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
  
  func testLogin(completion: @escaping (Result<Bool>) -> Void) {
    return XCTContext.runActivity(named: "Login") { activity in
      let registerExpectation = XCTestExpectation(description: "Register")

      Tests.PortalWrap?.signIn(username: Tests.username!) { (result: Result<UserResult>) -> Void in
        guard (result.error == nil) else {
          return XCTFail("Failed on sign In: \(result.error!)")
        }
        let userResult = result.data!
        print("✅ handleSignIn(): API key:", userResult.clientApiKey)
        Tests.user = userResult
        let backupOption = LocalFileStorage()
        let backup = BackupOptions(local: backupOption)
        Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
          (result) -> Void in
          guard result.error == nil else {
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
    let Address = "PortalMpc.Address"
    let SigningShare = "PortalMpc.DkgResult"
    
    do {
      try Tests.PortalWrap?.deleteItem(key: Address)
      try Tests.PortalWrap?.deleteItem(key: SigningShare)
    } catch {
      print("Couldn't delete keychain items")
    }
    let registerExpectation = XCTestExpectation(description: "Register")
    let generateExpectation = XCTestExpectation(description: "Generate")

    Tests.PortalWrap?.signUp(username: Tests.username!) { (result: Result<UserResult>) -> Void in
      guard (result.error == nil) else {
        return XCTFail("Failed on sign up: \(result.error!)")
      }
      let userResult = result.data!
      print("✅ handleSignup(): API key:", userResult.clientApiKey)
      Tests.user = userResult
      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backup = BackupOptions(local: backupOption)
      print("registering portal")
      Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
        (result) -> Void in
        guard result.error == nil else {
          return XCTFail()
        }
        registerExpectation.fulfill()
        print(result.data!)
          Tests.PortalWrap?.generate() { (result) -> Void in
            guard result.error == nil else {
              generateExpectation.fulfill()
              return XCTFail()
            }
            do {
//              let share = try Tests.PortalWrap?.portal?.keychain.getSigningShare()
              generateExpectation.fulfill()
              XCTAssertTrue(!(result.data!.isEmpty), "The string should be empty")
              return
            } catch {
              generateExpectation.fulfill()
              return XCTFail("Generate Failed: \(error.localizedDescription)")
            }
          }
        }
    }
    wait(for: [generateExpectation], timeout: 120)
  }

  func testBSign() {
    let ethSignExpectation = XCTestExpectation(description: "eth sign")
    var address: String? = "0x290766b47d6ea98bae2bd189cc8c7b4aa3154371"
    
    testLogin() { result -> Void in
      guard (result.error == nil) else {
        ethSignExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      do {
        address = try Tests.PortalWrap?.portal?.keychain.getAddress()
      } catch {
        return XCTFail("Failed to get address: \(error)")
      }

      let params = [address!, "0xdeadbeaf"]

      Tests.PortalWrap?.ethSign(params: params) { result -> Void in
        guard (result.error == nil) else {
          ethSignExpectation.fulfill()
          return XCTFail("Failed on eth_sign: \(result.error!)")
        }
        
        print("✅ eth_sign result: ", result.data!)
        XCTAssertFalse(result.data!.isEmpty, "eth sign success")

        ethSignExpectation.fulfill()
      }
    }
    
    wait(for: [ethSignExpectation], timeout: 20)
  }
 
  func testCBackup() {
    let backupExpectation = XCTestExpectation(description: "Backup")

    do {
      let share = try Tests.PortalWrap?.portal?.keychain.getSigningShare()
      XCTAssertFalse(share!.isEmpty, "The share exists in the keychain")
    } catch {
      return XCTFail("Backup doesnt have a share: \(error.localizedDescription)")
    }
    
    testLogin() { result -> Void in
      guard (result.error == nil) else {
        backupExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
          Tests.PortalWrap?.backup(backupMethod: BackupMethods.local.rawValue, user: Tests.user!) { (result) -> Void in
            guard result.error == nil else {
              backupExpectation.fulfill()
              return XCTFail("Backup failed \(String(describing: result.error))")
            }
            backupExpectation.fulfill()
            XCTAssertTrue(result.data!, "Backup Success")
          }
      }
    wait(for: [backupExpectation], timeout: 60)
    
  }
  
  func testRecover() {
    let recoverExpectation = XCTestExpectation(description: "Recover")

    testLogin() { result -> Void in
      guard (result.error == nil) else {
        recoverExpectation.fulfill()
        return XCTFail("Failed on login: \(result.error!)")
      }
      Tests.PortalWrap?.recover(backupMethod: BackupMethods.local.rawValue, user: Tests.user!) { (result) -> Void in
          guard result.error == nil else {
            recoverExpectation.fulfill()
            return XCTFail("Recover failed \(String(describing: result.error))")
          }
          recoverExpectation.fulfill()
          XCTAssertTrue(result.data!, "Recover Success")
        }
    }
    wait(for: [recoverExpectation], timeout: 120)
  }
}

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
      username = randomString(length: 15)
      print("USERNAME: ", username!)
      PortalWrap = PortalWrapper()
    }
  

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
              let share = try Tests.PortalWrap?.portal?.keychain.getSigningShare()
              generateExpectation.fulfill()
              XCTAssertFalse(share!.isEmpty, "The string should be empty")
              return
            } catch {
              generateExpectation.fulfill()
              return XCTFail("Generate Failed: \(error.localizedDescription)")
            }
            generateExpectation.fulfill()
          }
        }
    }
    wait(for: [generateExpectation], timeout: 120)
  }

  func testBackup() {
    let backupExpectation = XCTestExpectation(description: "Backup")
    let registerExpectation = XCTestExpectation(description: "Register")

    print("USERNAME: ", Tests.username!)
    do {
      let share = try Tests.PortalWrap?.portal?.keychain.getSigningShare()
      XCTAssertFalse(share!.isEmpty, "The string should be empty")
    } catch {
      return XCTFail("Backup doesnt have a share: \(error.localizedDescription)")
    }
    
    Tests.PortalWrap?.signIn(username: Tests.username!) { (result: Result<UserResult>) -> Void in
      guard (result.error == nil) else {
        return XCTFail("Failed on sign In: \(result.error!)")
      }
      let userResult = result.data!
      print("✅ handleSignIn(): API key:", userResult.clientApiKey)
      Tests.user = userResult
//      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backupOption = ICloudStorage()
      print(backupOption)
      let backup = BackupOptions(icloud: backupOption)
      Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
        (result) -> Void in
        guard result.error == nil else {
          return XCTFail()
        }
        registerExpectation.fulfill()
        print(result.data!)
          Tests.PortalWrap?.backup(backupMethod: BackupMethods.iCloud.rawValue, user: Tests.user!) { (result) -> Void in
            guard result.error == nil else {
              return XCTFail("Backup failed \(String(describing: result.error))")
            }
            backupExpectation.fulfill()
            XCTAssertTrue(result.data!, "Backup Success")
          }
      }
    }
    wait(for: [backupExpectation], timeout: 35)
    
  }
  
  func testRecover() {
    let recoverExpectation = XCTestExpectation(description: "Recover")
    let registerExpectation = XCTestExpectation(description: "Register")

    print("USERNAME: ", Tests.username!)

    Tests.PortalWrap?.signIn(username: Tests.username!) { (result: Result<UserResult>) -> Void in
      guard (result.error == nil) else {
        return XCTFail("Failed on sign In: \(result.error!)")
      }
      let userResult = result.data!
      print("✅ handleSignIn(): API key:", userResult.clientApiKey)
      Tests.user = userResult
//      let backupOption = LocalFileStorage(fileName: "PORTAL_BACKUP")
      let backupOption = ICloudStorage()
      print(backupOption)
      let backup = BackupOptions(icloud: backupOption)
      Tests.PortalWrap?.registerPortal(apiKey: userResult.clientApiKey, backup: backup) {
        (result) -> Void in
        guard result.error == nil else {
          return XCTFail()
        }
        registerExpectation.fulfill()
        print(result.data!)
        Tests.PortalWrap?.recover(backupMethod: BackupMethods.iCloud.rawValue, user: Tests.user!) { (result) -> Void in
            guard result.error == nil else {
              return XCTFail("Recover failed \(String(describing: result.error))")
            }
            recoverExpectation.fulfill()
            XCTAssertTrue(result.data!, "Recover Success")
          }
      }
    }
    wait(for: [recoverExpectation], timeout: 35)
    
  }
  
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
  
  
}

import XCTest
import PortalSwift

struct UserResult: Codable {
  var clientApiKey: String
  var exchangeUserId: Int
}

struct SignUpBody: Codable {
  var username: String
}

struct CipherTextResult: Codable {
  var cipherText: String
}

struct ProviderRequest {
  var method: String
  var params: [Any]
  var skipLoggingResult: Bool
}

struct ProviderTransactionRequest {
  var method: String
  var params: [ETHTransactionParam]
  var skipLoggingResult: Bool
}

struct ProviderAddressRequest {
  var method: String
  var params: [ETHAddressParam]
  var skipLoggingResult: Bool
}
class Tests: XCTestCase {
  public var user: UserResult?
  public var CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"
  public var portal: Portal?
  let API_URL = "api.portalhq.io"
  let MPC_URL = "mpc.portalhq.io"
  private var asyncExpectation: XCTestExpectation!
  
  func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
  }
  func signUp(username: String, completionHandler: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL + "/mobile/signup",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing up:", result.error!)
        completionHandler(Result(error: result.error!))
        return
      }
      completionHandler(Result(data: result.data!))
    }
  }
  
  func signIn(username: String, completionHandler: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL + "/mobile/login",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        completionHandler(Result(error: result.error!))
        return
      }
      completionHandler(Result(data: result.data!))
    }
  }
  
  func registerPortal(apiKey: String) -> Void {
    
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        print("Couldnt load info plist")
        return }
      guard let ALCHEMY_API_KEY: String = infoDictionary["ALCHEMY_API_KEY"] as? String else {
        print("Error: Do you have `ALCHEMY_API_KEY=$(ALCHEMY_API_KEY)` in your info.plist?")
        return  }
      guard let GDRIVE_CLIENT_ID: String = infoDictionary["GDRIVE_CLIENT_ID"] as? String else {
        print("Error: Do you have `GDRIVE_CLIENT_ID=$(GDRIVE_CLIENT_ID)` in your info.plist?")
        return  }
      
      let backup = BackupOptions(icloud: ICloudStorage())
      let keychain = PortalKeychain()
      // Configure the chain.
      let chainId = 5
      let chain = "goerli"
      portal = try Portal(
        apiKey: apiKey,
        backup: backup,
        chainId: chainId,
        keychain: keychain,
        gatewayConfig: [
          chainId: "https://eth-\(chain).g.alchemy.com/v2/\(ALCHEMY_API_KEY)",
        ],
        autoApprove: true,
        apiHost: API_URL!,
        mpcHost: MPC_URL!
      )
    } catch {
      print("❌ Error registering portal:", error)
    }
  }
  func deleteKeychain() {
    do {
      print("Here is the keychain address: ", try portal?.keychain.getAddress() ?? "")
      try portal!.keychain.deleteAddress()
      try portal!.keychain.deleteSigningShare()
      
      print("Now its gone: ", try portal?.keychain.getAddress() ?? "")
    } catch {
      print(" ✅  Deleted keychain:", error)

    }
  }
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
      let expectation = self.expectation(description: "Async operation completed")
      var username = self.randomString(length: 10)

      signUp(username: username) { (result: Result<UserResult>) -> Void in
        guard (result.error == nil) else {
          XCTFail("Failed on sign up: \(result.error!)")
          return
        }
        var userResult = result.data!
        print("✅ handleSignup(): API key:", userResult.clientApiKey)
        self.user = userResult
        self.registerPortal(apiKey: userResult.clientApiKey)
        print("done registering portal")
        expectation.fulfill()
        print("expection fulfilled")
      }
      wait(for: [expectation], timeout: 20)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

  func testGenerateExample() {
    let generateExpectation = self.expectation(description: "Generate operation completed")
    portal!.mpc.generate { result in
      guard (result.error == nil) else {
        XCTFail("Expectation was not fulfilled: \(result.error)")
        return
      }
      
      print("✅ Address:", result.data!)
      do {
        var dkg = try self.portal!.keychain.getSigningShare()
        print(dkg)
      } catch {
        print(error)
      }
      generateExpectation.fulfill()
      }
    
    wait(for: [generateExpectation], timeout: 15)
    
    let backupExpectation = self.expectation(description: "Generate operation completed")

    self.portal!.mpc.backup(method: BackupMethods.iCloud.rawValue) { result in
      guard (result.error == nil) else {
        XCTFail("Expectation was not fulfilled: \(String(describing: result.error))")
        return
      }
      print("✅ handleBackup(): cipherText:", result.data!.index(result.data!.startIndex, offsetBy: 20))
      
      let request = HttpRequest<String, [String : String]>(
        url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
        method: "POST",
        body: ["cipherText": result.data!],
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      )
      request.send() { (result: Result<String>) in
        print("✅ handleBackup(): Successfully sent custodian cipherText:")
        backupExpectation.fulfill()
      }
    }
    wait(for: [backupExpectation], timeout: 17)
    deleteKeychain()
    
    print("Starting recover...")
    let recoverExpectation = self.expectation(description: "Generate operation completed")

    let request = HttpRequest<CipherTextResult, [String : String]>(
      url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text/fetch",
      method: "GET", body:[:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest

    )

    request.send() { (result: Result<CipherTextResult>) in
      guard result.error == nil else {
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        return
      }

      let cipherText = result.data!.cipherText

      self.portal?.mpc.recover(cipherText: cipherText, method: BackupMethods.GoogleDrive.rawValue) { (result: Result<String>) -> Void in
        if (result.error != nil) {
          print("❌ handleRecover(): portal.mpc.recover", result.error!)
          return;
        }

        print("✅ handleRecover(): portal.mpc.recover - cipherText:", result.data!)

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL + "/mobile/\(self.user!.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: [:],
          requestType: HttpRequestType.CustomRequest
        )

        request.send() { (result: Result<String>) in
          if (result.error != nil) {
            print("❌ handleRecover(): Error sending custodian cipherText:", result.error!)
          } else {
            print("✅ handleRecover(): Successfully sent custodian cipherText:", result.data!)
          }
        }
      }
    }
    wait(for: [recoverExpectation], timeout: 17)

    XCTAssertTrue(true, "Passed")

  }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
}

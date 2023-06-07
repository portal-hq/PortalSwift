//
//  Portal.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 5/16/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import PortalSwift
import Pods_PortalSwift_Example

struct UserResult: Codable {
  var clientApiKey: String
  var exchangeUserId: Int
}

enum KeychainError: Error {
  case ItemNotFound(item: String)
  case ItemAlreadyExists(item: String)
  case unexpectedItemData(item: String)
  case unhandledError(status: OSStatus)
  case keychainUnavailableOrNoPasscode(status: OSStatus)
}

struct CipherTextResult: Codable {
  var cipherText: String
}

class PortalWrapper {
  public var portal: Portal?
  public var CUSTODIAN_SERVER_URL: String?
  public var API_URL: String?
  public var MPC_URL: String?
  
  init () {
    let PROD_CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"
    let STAGING_CUSTODIAN_SERVER_URL = "https://staging-portalex-mpc-service.onrender.com"
    let PROD_API_URL = "api.portalhq.io"
    let PROD_MPC_URL = "mpc.portalhq.io"
    let STAGING_API_URL = "api-staging.portalhq.io"
    let STAGING_MPC_URL = "mpc-staging.portalhq.io"
    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Couldnt load info plist")
      return }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return  }
    print("ENV", ENV)
    if (ENV == "prod") {
      CUSTODIAN_SERVER_URL = PROD_CUSTODIAN_SERVER_URL
      API_URL = PROD_API_URL
      MPC_URL = PROD_MPC_URL
    } else {
      CUSTODIAN_SERVER_URL = STAGING_CUSTODIAN_SERVER_URL
      API_URL = STAGING_API_URL
      MPC_URL = STAGING_MPC_URL
    }
  }
  
  func signIn(username: String, completion: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/login",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )
    
    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing in:", result.error!)
        return completion(Result(error: result.error!))
        
      }
      return completion(Result(data: result.data!))
    }
  }
  
  func signUp(username: String, completion: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String : String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/signup",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )
    
    request.send() { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing up:", result.error!)
        return completion(Result(error: result.error!))
        
      }
      return completion(Result(data: result.data!))
    }
  }
  
  public enum PortalWrapperError: Error {
    case cantLoadInfoPlist
  }
  
  func registerPortal(apiKey: String, backup: BackupOptions, completion: @escaping (Result<Bool>) -> Void) -> Void {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        return completion(Result(error: PortalWrapperError.cantLoadInfoPlist))
      }
      guard let ALCHEMY_API_KEY: String = infoDictionary["ALCHEMY_API_KEY"] as? String else {
        print("Error: Do you have `ALCHEMY_API_KEY=$(ALCHEMY_API_KEY)` in your info.plist?")
        return
      }
      let keychain = PortalKeychain()
      // Configure the chain.
      let chainId = 5
      let chain = "goerli"
      portal = try Portal(
        apiKey: "f09ace22-7333-4543-9649-730e559e8685",
        backup: backup,
        chainId: chainId,
        keychain: keychain,
        gatewayConfig: [
          chainId: "https://eth-\(chain).g.alchemy.com/v2/\(ALCHEMY_API_KEY)",
        ],
        autoApprove: true,
        apiHost: "localhost:3001",
        mpcHost: "localhost:3002"
      )
      _ = portal?.provider.on(event: Events.PortalSigningRequested.rawValue, callback: { [weak self] data in self?.didRequestApproval(data: data)})
      
      _ = portal?.provider.on(event: Events.PortalDappSessionRequested.rawValue, callback: { [weak self] data in self?.didRequestApprovalDapps(data: data)})
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("❌ Error: Invalid Gateway URL")
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      print("❌ Error: No gateway config for chainId: \(chainId)")
    } catch {
      print("❌ Error registering portal:", error)
    }
    return completion(Result(data: true))
  }
  
  func didRequestApproval(data: Any) -> Void {
    _ = portal?.provider.emit(event: Events.PortalSigningApproved.rawValue, data: data)
  }
  
  func didRequestApprovalDapps(data: Any) -> Void {
    _ = portal?.provider.emit(event: Events.PortalDappSessionRejected.rawValue, data: data)
  }
  
  
  func generate(completion: @escaping (Result<String>) -> Void) -> Void  {
    portal?.mpc.generate() { (addressResult) -> Void in
      guard addressResult.error == nil else {
        return completion(Result(error: addressResult.error!))
      }
      return completion(Result(data: addressResult.data!))
      
    } progress: { status in
      print("Generate Status: ", status)
    }
  }
  

  func backup(backupMethod: BackupMethods.RawValue, user: UserResult, completion: @escaping (Result<Bool>) -> Void) -> Void {
    portal?.mpc.backup(method: backupMethod)  { (result: Result<String>) -> Void in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      let request = HttpRequest<String, [String : String]>(
        url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text",
        method: "POST",
        body: ["cipherText": result.data!],
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      )
      
      request.send() { (result: Result<String>) in
        completion(Result(data: true))
      }
    } progress: { status in
      print("Backup Status: ", status)
    }
  }
  
  func recover(backupMethod: BackupMethods.RawValue, user: UserResult, completion: @escaping (Result<Bool>) -> Void) -> Void {
    print("Starting recover...")
    let request = HttpRequest<CipherTextResult, [String : String]>(
      url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text/fetch",
      method: "GET", body:[:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    )

    request.send() { (result: Result<CipherTextResult>) in
      guard result.error == nil else {
        print("❌ handleRecover(): Error fetching cipherText:", result.error!)
        return completion(Result(error: result.error!))
      }
      
      let cipherText = result.data!.cipherText
      
      self.portal?.mpc.recover(cipherText: cipherText, method: backupMethod) { (result: Result<String>) -> Void in
        guard result.error == nil else {
          print("❌ handleRecover(): Error fetching cipherText:", result.error!)
          return completion(Result(error: result.error!))
        }

        let request = HttpRequest<String, [String : String]>(
          url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text",
          method: "POST",
          body: ["cipherText": result.data!],
          headers: [:],
          requestType: HttpRequestType.CustomRequest
        )

        request.send() { (result: Result<String>) in
          if (result.error != nil) {
            print("❌ handleRecover(): Error sending custodian cipherText:", result.error!)
            return completion(Result(error: result.error!))
          } else {
            print("✅ handleRecover(): Successfully sent custodian cipherText:")
            return completion(Result(data: true))
            
          }
        }
      } progress: { status in
        print("Recover Status: ", status)
      }
    }
  }
  
  func ethSign(params: [Any], completion: @escaping (Result<String>) -> Void) {
    let method = ETHRequestMethods.Sign.rawValue
    
    let payload = ETHRequestPayload(
      method: method,
      params: params
    )
    portal?.provider.request(payload: payload) { (result: Result<RequestCompletionResult>) -> Void in
      guard (result.error == nil) else {
          print("❌ Error calling \(method)", "Error:", result.error!)
          completion(Result(error: result.error!))
          return
        }
      guard ((result.data!.result as! Result<SignerResult>).error == nil) else {
          print("❌ Error testing signer request:", method, "Error:", (result.data!.result as! Result<SignerResult>).error)
          completion(Result(error: result.error!))
          return
        }
      if ((result.data!.result as! Result<SignerResult>).data!.signature != nil) {
        completion(Result(data: (result.data!.result as! Result<SignerResult>).data!.signature!))
        }
      }
  }
  
//  func ethSend(params: [Any], completion: @escaping (Result<RequestCompletionResult>) -> Void) {
//    let method = ETHRequestMethods.SendTransaction.rawValue
//
//    let payload = ETHRequestPayload(
//      method: method,
//      params: params
//    )
//    portal?.provider.request(payload: payload) { (result: Result<TransactionCompletionResult>) -> Void in
//      guard (result.error == nil) else {
//          print("❌ Error calling \(method)", "Error:", result.error!)
//        completion(Result(error: result.error!))
//          return
//        }
//      if ((result.data!.result as? SignerResult)?.signature != nil) {
//          print("✅ Signature for", method,(result.data!.result as! SignerResult).signature!)
//        completion(Result(data: (result.data!.result as! SignerResult).signature!))
//        }
//      }
//  }
  
  func transferFunds(user: UserResult, amount: Double, chainId: Int, address: String, completion: @escaping (Result<String>) -> Void) {
    let request = HttpRequest<String, [String : Any]>(
      url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/transfer",
      method: "POST",
      body: [
        "exchangeUserId": user.exchangeUserId,
        "amount": amount,
        "chainId": chainId,
        "address": address
    ],
      headers: ["Content-Type":"application/json"],
      requestType: HttpRequestType.CustomRequest
    )
    
    request.send() { (result: Result<String>) in
      if (result.error != nil) {
        print("❌ transferFunds(): Error sending funds:", result.error!)
        return completion(Result(error: result.error!))
      } else {
        print("✅ transferFunds(): Successfully sent funds!")
        return completion(Result(data: result.data!))
      }
    }
  }
  
  // HELPERS
  public func getItem(item: String) throws -> String {
    // Construct the query to retrieve the keychain item.
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: item,
      kSecAttrService as String: "PortalMpc.\(item)",
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true
    ]
    
    // Try to retrieve the keychain item that matches the query.
    var keychainItem: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &keychainItem)
    
    // Throw if the status is not successful.
    guard status != errSecItemNotFound else { throw KeychainError.ItemNotFound(item: item)}
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    
    // Attempt to format the keychain item as a string.
    guard let itemData = keychainItem as? Data,
          let itemString = String(data: itemData, encoding: String.Encoding.utf8)
    else {
      throw KeychainError.unexpectedItemData(item: item)
    }
    
    return itemString
  }

  public func setItem(
    key: String,
    value: String,
    completion: (Result<OSStatus>) -> Void
  ) -> Void {
    do {
      // Construct the query to set the keychain item.
      let query: [String: AnyObject] = [
        kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
      ]
      
      // Try to set the keychain item that matches the query.
      let status = SecItemAdd(query as CFDictionary, nil)
      
      // Throw if the status is not successful.
      if (status == errSecDuplicateItem) {
        try self.updateItem(key: key, value: value)
        return completion(Result(data: status))
      }
      guard status != errSecNotAvailable else {
        return completion(Result(error: KeychainError.keychainUnavailableOrNoPasscode(status: status)))
      }
      guard status == errSecSuccess else {
        return completion(Result(error: KeychainError.unhandledError(status: status)))
      }
      return completion(Result(data: status))
    } catch {
      return completion(Result(error: error))
    }
  }
  
  public func updateItem(key: String, value: String) throws {
    // Construct the query to update the keychain item.
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword
    ]
    
    // Construct the attributes to update the keychain item.
    let attributes: [String: AnyObject] = [
      kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
      kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
    ]
    
    // Try to update the keychain item that matches the query.
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    
    // Throw if the status is not successful.
    guard status != errSecItemNotFound else {
      throw KeychainError.ItemNotFound(item: key)
    }
    guard status != errSecNotAvailable else {
      throw KeychainError.keychainUnavailableOrNoPasscode(status: status)
    }
    guard status == errSecSuccess else {
      throw KeychainError.unhandledError(status: status)
    }
  }
  
  public func deleteItem(key: String) throws {
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
  }
}


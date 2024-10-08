//
//  Portal.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 5/16/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import AnyCodable
import Foundation
import PortalSwift

struct UserResult: Codable {
  var clientApiKey: String
  var exchangeUserId: Int
}

struct CipherTextResult: Codable {
  var cipherText: String
}

struct OrgShareResult: Codable {
  var orgShare: String
}

class PortalWrapper {
  public var portal: Portal?
  public var CUSTODIAN_SERVER_URL: String?
  public var API_URL: String?
  public var MPC_URL: String?

  init() {
    let PROD_CUSTODIAN_SERVER_URL = "https://portalex-mpc.portalhq.io"
    let PROD_API_URL = "api.portalhq.io"
    let PROD_MPC_URL = "mpc.portalhq.io"

    let STAGING_CUSTODIAN_SERVER_URL = "https://staging-portalex-mpc-service.onrender.com"
    let STAGING_API_URL = "api.portalhq.dev"
    let STAGING_MPC_URL = "mpc.portalhq.dev"

    let LOCAL_API_URL = "localhost:3001"
    let LOCAL_MPC_URL = "localhost:3002"
    guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
      print("Couldnt load info plist")
      return
    }
    guard let ENV: String = infoDictionary["ENV"] as? String else {
      print("Error: Do you have `ENV=$(ENV)` in your info.plist?")
      return
    }
    print("ENV", ENV)
    if ENV == "prod" {
      self.CUSTODIAN_SERVER_URL = PROD_CUSTODIAN_SERVER_URL
      self.API_URL = PROD_API_URL
      self.MPC_URL = PROD_MPC_URL
    } else if ENV == "staging" {
      self.CUSTODIAN_SERVER_URL = STAGING_CUSTODIAN_SERVER_URL
      self.API_URL = STAGING_API_URL
      self.MPC_URL = STAGING_MPC_URL
    } else if ENV == "local" {
      self.CUSTODIAN_SERVER_URL = STAGING_CUSTODIAN_SERVER_URL
      self.API_URL = LOCAL_API_URL
      self.MPC_URL = LOCAL_MPC_URL
    }
  }

  func signIn(username: String, completion: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String: String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/login",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    request.send { (result: Result<UserResult>) in
      guard result.error == nil else {
        print("❌ Error signing in:", result.error!)
        return completion(Result(error: result.error!))
      }
      return completion(Result(data: result.data!))
    }
  }

  func signUp(username: String, completion: @escaping (Result<UserResult>) -> Void) {
    let request = HttpRequest<UserResult, [String: String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/signup",
      method: "POST",
      body: ["username": username],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    request.send { (result: Result<UserResult>) in
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

  func registerPortal(apiKey: String, backup: BackupOptions, chainId: Int = 11_155_111, isMultiBackupEnabled: Bool? = nil, completion: @escaping (Result<Bool>) -> Void) {
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
      self.portal = try Portal(
        apiKey: apiKey,
        backup: backup,
        chainId: chainId,
        keychain: keychain,
        gatewayConfig: [
          11_155_111: "https://eth-sepolia.g.alchemy.com/v2/\(ALCHEMY_API_KEY)", 1: "https://eth-mainnet.g.alchemy.com/v2/\(ALCHEMY_API_KEY)", 80001: "https://polygon-mumbai.g.alchemy.com/v2/\(ALCHEMY_API_KEY)", 137: "https://polygon-mainnet.g.alchemy.com/v2/\(ALCHEMY_API_KEY)"
        ],
        autoApprove: false,
        apiHost: self.API_URL!,
        mpcHost: self.MPC_URL!,
        featureFlags: FeatureFlags(isMultiBackupEnabled: isMultiBackupEnabled)
      )
      _ = self.portal?.provider.on(event: Events.PortalSigningRequested.rawValue, callback: { [weak self] data in self?.didRequestApproval(data: data) })
      _ = self.portal?.provider.on(event: Events.PortalSignatureReceived.rawValue) { (data: Any) in
        let result = data as! RequestCompletionResult

        print("[ViewController] portal_signatureReceived: \(result)")
      }

      print("[ViewController] Portal initialized")
    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      print("❌ Error: Invalid Gateway URL")
    } catch let PortalArgumentError.noGatewayConfigForChain(chainId) {
      print("❌ Error: No gateway config for chainId: \(chainId)")
    } catch {
      print("❌ Error registering portal:", error)
    }
    return completion(Result(data: true))
  }

  func didRequestApproval(data: Any) {
    _ = self.portal?.provider.emit(event: Events.PortalSigningApproved.rawValue, data: data)
  }

  func generate(completion: @escaping (Result<String>) -> Void) {
    self.portal?.createWallet { addressResult in
      guard addressResult.error == nil else {
        return completion(Result(error: addressResult.error!))
      }
      return completion(Result(data: addressResult.data!))

    } progress: { status in
      print("Generate Status: ", status)
    }
  }

  func backup(backupMethod: BackupMethods.RawValue, user: UserResult, backupConfigs: BackupConfigs? = nil, completion: @escaping (Result<String>) -> Void) {
    self.portal?.backupWallet(method: backupMethod, backupConfigs: backupConfigs) { (result: Result<String>) in
      guard result.error == nil else {
        print("❌ backup(): Error backing up wallet", result.error)
        return completion(result)
      }
      let request = HttpRequest<String, [String: String]>(
        url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text",
        method: "POST",
        body: ["cipherText": result.data!, "backupMethod": backupMethod],
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      )

      request.send { (_: Result<String>) in
        do {
          try self.portal!.api.storedClientBackupShare(success: true, backupMethod: backupMethod) { result in
            guard result.error == nil else {
              print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
              return completion(result)
            }
            completion(result)
          }
        } catch {
          print("❌ handleBackup(): Error notifying Portal that backup share was stored.")
        }
      }
    } progress: { status in
      print("Backup Status: ", status)
    }
  }

  func eject(backupMethod: BackupMethods.RawValue, user: UserResult, backupConfigs _: BackupConfigs? = nil, completion: @escaping (Result<String>) -> Void) {
    print("[PortalWrapper] Starting eject...")
    // Setup request to get ciphert-text
    let request = HttpRequest<CipherTextResult, [String: String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(backupMethod)",
      method: "GET", body: [:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    )

    request.send { (result: Result<CipherTextResult>) in
      guard result.error == nil else {
        print("❌ [PortalWrapper] handleEject(): Error fetching cipherText:", result.error!)
        return completion(Result(error: result.error!))
      }

      let cipherText = result.data!.cipherText

      // Setup request to get org-share
      let requestOrgShare = HttpRequest<OrgShareResult, [String: String]>(
        url: self.CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(backupMethod)-SECP256K1",
        method: "GET", body: [:],
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      )

      requestOrgShare.send { (result: Result<OrgShareResult>) in
        guard result.error == nil else {
          return completion(Result(error: result.error!))
        }

        if let data = result.data {
          let orgShare = data.orgShare
          self.portal?.ejectPrivateKey(clientBackupCiphertext: cipherText, method: backupMethod, orgBackupShare: orgShare) { (result: Result<String>) in
            guard result.error == nil else {
              return completion(Result(error: result.error!))
            }
            return completion(result)
          }
        }
      }
    }
  }

  func recover(backupMethod: BackupMethods.RawValue, user: UserResult, backupConfigs: BackupConfigs? = nil, completion: @escaping (Result<Bool>) -> Void) {
    print("[PortalWrapper] Starting recover...")
    let request = HttpRequest<CipherTextResult, [String: String]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(backupMethod)", // Use this to fetch v6+ client backup share.
      method: "GET", body: [:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    )

    request.send { (result: Result<CipherTextResult>) in
      guard result.error == nil else {
        print("❌ [PortalWrapper] handleRecover(): Error fetching cipherText:", result.error!)
        return completion(Result(error: result.error!))
      }

      let cipherText = result.data!.cipherText

      self.portal?.recoverWallet(cipherText: cipherText, method: backupMethod, backupConfigs: backupConfigs) { (result: Result<String>) in
        guard result.error == nil else {
          print("❌ [PortalWrapper] handleRecover(): Error recovering wallet:", result.error!)
          return completion(Result(error: result.error!))
        }

        print("✅ [PortalWrapper] handleRecover(): Successfully recovered signing shares")
        return completion(Result(data: true))
      } progress: { status in
        print("[PortalWrapper] Recover Status: ", status)
      }
    }
  }

  func ethSign(params: [Any], completion: @escaping (Result<String>) -> Void) {
    do {
      let method = ETHRequestMethods.Sign.rawValue

      print("Portal.ethSign() - params: \(params)")

      let encodedParams = try params.map { param in
        AnyCodable(param)
      }
      let payload = ETHRequestPayload(
        method: method,
        params: encodedParams
      )
      self.portal?.provider.request(payload: payload) { (result: Result<RequestCompletionResult>) in
        guard result.error == nil else {
          print("❌ Error calling \(method)", "Error:", result.error!)
          completion(Result(error: result.error!))
          return
        }
        guard (result.data!.result as! Result<SignerResult>).error == nil else {
          print("❌ Error testing signer request:", method, "Error:", (result.data!.result as! Result<SignerResult>).error)
          completion(Result(error: result.error!))
          return
        }
        if (result.data!.result as! Result<SignerResult>).data!.signature != nil {
          completion(Result(data: (result.data!.result as! Result<SignerResult>).data!.signature!))
        }
      }
    } catch {
      completion(Result(error: error))
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
    let request = HttpRequest<String, [String: Any]>(
      url: CUSTODIAN_SERVER_URL! + "/mobile/\(user.exchangeUserId)/transfer",
      method: "POST",
      body: [
        "exchangeUserId": user.exchangeUserId,
        "amount": amount,
        "chainId": chainId,
        "address": address
      ],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    request.send { (result: Result<String>) in
      if result.error != nil {
        print("transferFunds(): Error sending funds:", result.error!)
        return completion(Result(error: result.error!))
      } else {
        print("transferFunds(): Successfully sent funds!")
        return completion(Result(data: result.data!))
      }
    }
  }
}

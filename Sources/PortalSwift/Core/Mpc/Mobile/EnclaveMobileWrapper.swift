//
//  HttpMobileWrapper.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 2/19/25.
//

import Foundation

class EnclaveMobileWrapper: Mobile {
  private let defaultWrapper = MobileWrapper()

  // Override sign method to use HTTP endpoint
  func MobileSign(
    _ apiKey: String?,
    _: String?,
    _ signingShare: String?,
    _ method: String?,
    _ params: String?,
    _ rpcURL: String?,
    _ chainId: String?,
    _ metadata: String?
  ) async -> String {
    guard let apiKey = apiKey,
          let signingShare = signingShare,
          let method = method,
          let params = params,
          let rpcURL = rpcURL,
          let chainId = chainId,
          let metadata = metadata
    else {
      let errorResult = SignResult(
        data: nil,
        error: PortalError(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
      )
      return try! String(data: JSONEncoder().encode(errorResult), encoding: .utf8)!
    }

    // Prepare request body
    let requestBody: [String: Any] = [
      "method": method,
      "params": params,
      "share": signingShare,
      "chainId": chainId,
      "rpcUrl": rpcURL,
      "metadataStr": metadata
    ]

    do {
      // Create URL request
      var request = URLRequest(url: URL(string: "https://mpc-client.portalhq.io/v1/sign")!)
      request.httpMethod = "POST"
      request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

      // Make request
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        let errorResult = SignResult(
          data: nil,
          error: PortalError(id: "INVALID_RESPONSE", message: "Invalid response received")
        )
        return try! String(data: JSONEncoder().encode(errorResult), encoding: .utf8)!
      }

      if httpResponse.statusCode != 200 {
        // Try to parse error message from response
        if let errorResponse = try? JSONDecoder().decode(EnclaveErrorResponse.self, from: data) {
          let errorResult = SignResult(
            data: nil,
            error: PortalError(
              id: String(errorResponse.code),
              message: errorResponse.message
            )
          )
          return try! String(data: JSONEncoder().encode(errorResult), encoding: .utf8)!
        }

        // Default error if can't parse response
        let errorResult = SignResult(
          data: nil,
          error: PortalError(
            id: String(httpResponse.statusCode),
            message: "Request failed with status: \(httpResponse.statusCode)"
          )
        )
        return try! String(data: JSONEncoder().encode(errorResult), encoding: .utf8)!
      }

      // Handle successful response
      let enclaveResponse = try JSONDecoder().decode(EnclaveSignResponse.self, from: data)
      let successResult = SignResult(data: enclaveResponse.data, error: nil)
      return try! String(data: JSONEncoder().encode(successResult), encoding: .utf8)!

    } catch {
      let errorResult = SignResult(
        data: nil,
        error: PortalError(
          id: "SIGNING_NETWORK_ERROR",
          message: error.localizedDescription
        )
      )
      return try! String(data: JSONEncoder().encode(errorResult), encoding: .utf8)!
    }
  }

  // Forward all other Mobile protocol methods to defaultWrapper
  func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileGenerate(apiKey, host, apiHost, metadata)
  }

  func MobileGenerateEd25519(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileGenerateEd25519(apiKey, host, apiHost, metadata)
  }

  func MobileGenerateSecp256k1(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileGenerateSecp256k1(apiKey, host, apiHost, metadata)
  }

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileBackup(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileBackupEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileBackupEd25519(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileBackupSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileBackupSecp256k1(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileRecoverSigning(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverSigningEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileRecoverSigningEd25519(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverSigningSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileRecoverSigningSecp256k1(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
    await defaultWrapper.MobileRecoverBackup(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) async -> String {
    await defaultWrapper.MobileDecrypt(key, dkgCipherText)
  }

  func MobileEncrypt(_ value: String) async -> String {
    await defaultWrapper.MobileEncrypt(value)
  }

  func MobileEncryptWithPassword(data value: String, password: String) async -> String {
    await defaultWrapper.MobileEncryptWithPassword(data: value, password: password)
  }

  func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) async -> String {
    await defaultWrapper.MobileDecryptWithPassword(key, dkgCipherText)
  }

  func MobileGetMe(_ url: String, _ token: String) -> String {
    defaultWrapper.MobileGetMe(url, token)
  }

  func MobileGetVersion() -> String {
    defaultWrapper.MobileGetVersion()
  }

  func MobileEjectWalletAndDiscontinueMPC(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
    await defaultWrapper.MobileEjectWalletAndDiscontinueMPC(clientDkgCipherText, serverDkgCipherText)
  }

  func MobileEjectWalletAndDiscontinueMPCEd25519(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
    await defaultWrapper.MobileEjectWalletAndDiscontinueMPCEd25519(clientDkgCipherText, serverDkgCipherText)
  }

  func MobileGetCustodianIdClientIdHashes(_ custodianIdClientIdJSON: String) -> String {
    defaultWrapper.MobileGetCustodianIdClientIdHashes(custodianIdClientIdJSON)
  }

  func MobileFormatShares(_ sharesJSON: String) -> String {
    defaultWrapper.MobileFormatShares(sharesJSON)
  }
}

// Response types
private struct EnclaveSignResponse: Codable {
  let data: String
}

private struct EnclaveErrorResponse: Codable {
  let code: Int
  let message: String
}

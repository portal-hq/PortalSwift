//
//  EnclaveMobileWrapper.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 2/19/25.
//

import Foundation

class EnclaveMobileWrapper: MPCMobile {
  private let requests: PortalRequestsProtocol = PortalRequests()

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
      return encodeErrorResult(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
    }

    guard let url = URL(string: "https://mpc-client.portalhq.io/v1/sign") else {
      return encodeErrorResult(id: "INVALID_URL", message: "Invalid URL")
    }

    let requestBody: [String: String] = [
      "method": method,
      "params": params,
      "share": signingShare,
      "chainId": chainId,
      "rpcUrl": rpcURL,
      "metadataStr": metadata,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ]

    do {
      let data = try await requests.post(url, withBearerToken: apiKey, andPayload: requestBody)
      let enclaveResponse = try JSONDecoder().decode(EnclaveSignResponse.self, from: data)
      return encodeSuccessResult(data: enclaveResponse.data)

    } catch {
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
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

// Helper function to encode success results
private func encodeSuccessResult(data: String?) -> String {
  let successResult = SignResult(data: data, error: nil)
  return encodeJSON(successResult)
}

// Helper function to encode error results
private func encodeErrorResult(id: String, message: String) -> String {
  let errorResult = SignResult(data: nil, error: PortalError(id: id, message: message))
  return encodeJSON(errorResult)
}

// Helper function to encode any Encodable to JSON string
private func encodeJSON<T: Encodable>(_ value: T) -> String {
  do {
    let jsonData = try JSONEncoder().encode(value)
    if let jsonString = String(data: jsonData, encoding: .utf8) {
      return jsonString
    } else {
      return "{\"error\":{\"id\":\"ENCODING_ERROR\",\"message\":\"Failed to encode JSON string\"}}"
    }
  } catch {
    return "{\"error\":{\"id\":\"ENCODING_ERROR\",\"message\":\"\(error.localizedDescription)\"}}"
  }
}

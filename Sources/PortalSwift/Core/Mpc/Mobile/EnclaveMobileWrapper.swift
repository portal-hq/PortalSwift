//
//  EnclaveMobileWrapper.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 2/19/25.
//

import Foundation

class EnclaveMobileWrapper: MPCMobile {
  private let requests: PortalRequestsProtocol
  private let enclaveMPCHost: String

  init(
    requests: PortalRequestsProtocol = PortalRequests(),
    enclaveMPCHost: String
  ) {
    self.requests = requests
    self.enclaveMPCHost = enclaveMPCHost
  }

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

    guard let url = URL(string: "https://\(enclaveMPCHost)/v1/sign") else {
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
      if let portalRequestError = error as? PortalRequestsError {
        let portalError = decodePortalError(errorStr: portalRequestError.dataStr)
        return encodeErrorResult(error: portalError)
      }
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
  }

  // Helper function to encode success results
  private func encodeSuccessResult(data: String) -> String {
    let successResult = SignResult(data: data, error: nil)
    return encodeJSON(successResult)
  }

  // Helper function to decode PortalRequestError to PortalError
  private func decodePortalError(errorStr: String?) -> PortalError? {
    guard let data = errorStr?.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(PortalError.self, from: data)
  }

  // Helper function to encode error results
  private func encodeErrorResult(id: String?, message: String?) -> String {
    let errorResult = SignResult(data: nil, error: PortalError(id: id, message: message))
    return encodeJSON(errorResult)
  }

  private func encodeErrorResult(error: PortalError?) -> String {
    let errorResult = SignResult(data: nil, error: error)
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
}

// Response types
struct EnclaveSignResponse: Codable {
  let data: String
}

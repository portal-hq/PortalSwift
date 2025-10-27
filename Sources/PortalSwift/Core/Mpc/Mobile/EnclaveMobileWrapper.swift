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
    _ host: String?,
    _ signingShare: String?,
    _ method: String?,
    _ params: String?,
    _ rpcURL: String?,
    _ chainId: String?,
    _ metadata: String?,
    _ curve: PortalCurve?,
    isRaw: Bool?
  ) async -> String {
      if isRaw ?? false {
          return await enclaveRawSign(
            apiKey: apiKey,
            signingShare: signingShare,
            params: params,
            curve: curve
          )
      } else {
          return await enclaveSign(
            apiKey: apiKey,
            signingShare: signingShare,
            method: method,
            params: params,
            rpcURL: rpcURL,
            chainId: chainId,
            metadata: metadata
          )
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

extension EnclaveMobileWrapper {
    
    private func enclaveRawSign(
      apiKey: String?,
      signingShare: String?,
      params: String?,
      curve: PortalCurve?
    ) async -> String {
      guard let apiKey = apiKey,
            let signingShare = signingShare,
            let params = params,
            let curve
      else {
        return encodeErrorResult(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
      }

      guard let url = URL(string: "https://\(enclaveMPCHost)/v1/raw/sign/\(curve.rawValue)") else {
        return encodeErrorResult(id: "INVALID_URL", message: "Invalid URL")
      }

      let requestBody: [String: String] = [
        "params": params,
        "share": signingShare,
        "clientPlatform": "NATIVE_IOS",
        "clientPlatformVersion": SDK_VERSION
      ]

      do {
        let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: apiKey)
        let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
        return encodeSuccessResult(data: enclaveResponse.data)
      } catch {
        if let portalRequestError = error as? PortalRequestsError {
          let portalError = decodePortalError(errorStr: portalRequestError.dataStr)
          return encodeErrorResult(error: portalError)
        }
        return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
      }
    }
    
    private func enclaveSign(
      apiKey: String?,
      signingShare: String?,
      method: String?,
      params: String?,
      rpcURL: String?,
      chainId: String?,
      metadata: String?
    ) async -> String {

      guard let apiKey,
            let signingShare,
            let method,
            let params,
            let chainId,
            let metadata
      else {
        return encodeErrorResult(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
      }
        
      guard let url = URL(string: "https://\(enclaveMPCHost)/v1/sign") else {
        return encodeErrorResult(id: "INVALID_URL", message: "Invalid URL")
      }

      var requestBody: [String: String] = [
        "method": method,
        "params": params,
        "share": signingShare,
        "chainId": chainId,
        "metadataStr": metadata,
        "clientPlatform": "NATIVE_IOS",
        "clientPlatformVersion": SDK_VERSION
      ]
        
        if let rpcURL {
            requestBody["rpcUrl"] = rpcURL
        }

      do {
        let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: apiKey)
        let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
        return encodeSuccessResult(data: enclaveResponse.data)
      } catch {
        if let portalRequestError = error as? PortalRequestsError {
          let portalError = decodePortalError(errorStr: portalRequestError.dataStr)
          return encodeErrorResult(error: portalError)
        }
        return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
      }
    }
}

// Response types
struct EnclaveSignResponse: Codable {
  let data: String
}

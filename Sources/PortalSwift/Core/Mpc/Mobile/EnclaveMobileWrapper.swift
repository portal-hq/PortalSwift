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
          let rpcURL,
          let chainId,
          let metadata
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

extension EnclaveMobileWrapper {
  func MobilePresign(
    _ apiKey: String,
    _ mpcAddr: String,
    _ shareStr: String,
    _ metadataStr: String,
    _ curve: PortalCurve?
  ) async -> String {
    return await enclavePresign(
      apiKey: apiKey,
      signingShare: shareStr,
      curve: curve
    )
  }

  func MobileSignWithPresignature(
    _ apiKey: String?,
    _ mpcAddr: String?,
    _ shareStr: String?,
    _ presignatureData: String?,
    _ method: String?,
    _ params: String?,
    _ rpcURL: String?,
    _ chainId: String?,
    _ metadataStr: String?,
    _ curve: PortalCurve?,
    isRaw: Bool?
  ) async -> String {
    if isRaw ?? false {
      return await enclaveRawSignWithPresignature(
        apiKey: apiKey,
        signingShare: shareStr,
        presignatureData: presignatureData,
        params: params,
        curve: curve
      )
    } else {
      return await enclaveSignWithPresignature(
        apiKey: apiKey,
        signingShare: shareStr,
        presignatureData: presignatureData,
        method: method,
        params: params,
        rpcURL: rpcURL,
        chainId: chainId,
        metadata: metadataStr
      )
    }
  }

  private func enclavePresign(
    apiKey: String?,
    signingShare: String?,
    curve: PortalCurve?
  ) async -> String {
    guard let apiKey = apiKey,
          let signingShare = signingShare,
          let curve = curve
    else {
      return encodePresignErrorResult(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
    }

    guard let url = URL(string: "https://\(enclaveMPCHost)/v1/presign/\(curve.rawValue)") else {
      return encodePresignErrorResult(id: "INVALID_URL", message: "Invalid URL")
    }

    let requestBody: [String: String] = [
      "share": signingShare,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ]

    do {
      let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: apiKey)
      let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclavePresignResponse.self)
      let presignResponse = PresignResponse(id: enclaveResponse.id, expiresAt: enclaveResponse.expiresAt, data: enclaveResponse.data, error: nil)
      return encodeJSON(presignResponse)
    } catch {
      if let portalRequestError = error as? PortalRequestsError {
        let portalError = decodePortalError(errorStr: portalRequestError.dataStr)
        return encodeJSON(PresignResponse(id: nil, expiresAt: nil, data: nil, error: portalError))
      }
      return encodePresignErrorResult(id: "PRESIGN_NETWORK_ERROR", message: error.localizedDescription)
    }
  }

  private func enclaveSignWithPresignature(
    apiKey: String?,
    signingShare: String?,
    presignatureData: String?,
    method: String?,
    params: String?,
    rpcURL: String?,
    chainId: String?,
    metadata: String?
  ) async -> String {
    guard let apiKey, let signingShare, let presignatureData,
          let method, let params, let rpcURL, let chainId, let metadata
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
      "presignature": presignatureData,
      "chainId": chainId,
      "rpcUrl": rpcURL,
      "metadataStr": metadata,
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

  private func enclaveRawSignWithPresignature(
    apiKey: String?,
    signingShare: String?,
    presignatureData: String?,
    params: String?,
    curve: PortalCurve?
  ) async -> String {
    guard let apiKey = apiKey,
          let signingShare = signingShare,
          let presignatureData = presignatureData,
          let params = params,
          let curve = curve
    else {
      return encodeErrorResult(id: "INVALID_PARAMETERS", message: "Invalid parameters provided")
    }

    guard let url = URL(string: "https://\(enclaveMPCHost)/v1/raw/sign/\(curve.rawValue)") else {
      return encodeErrorResult(id: "INVALID_URL", message: "Invalid URL")
    }

    let requestBody: [String: String] = [
      "params": params,
      "share": signingShare,
      "presignature": presignatureData,
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

  private func encodePresignErrorResult(id: String?, message: String?) -> String {
    let result = PresignResponse(id: nil, expiresAt: nil, data: nil, error: PortalError(id: id, message: message))
    return encodeJSON(result)
  }
}

// Response types
struct EnclaveSignResponse: Codable {
  let data: String
}

struct EnclavePresignResponse: Codable {
  let id: String
  let expiresAt: String
  let data: String
}

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
    _ token: String?,
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
        token: token,
        signingShare: signingShare,
        params: params,
        metadata: metadata,
        curve: curve
      )
    } else {
      return await enclaveSign(
        token: token,
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

  /// The sign result for a sign request the transport failed with `requestError`.
  ///
  /// A body carrying an error `id`, the enclave's own `{"id", "message"}` shape, is passed through
  /// unchanged so callers can match on the id. Any other body (an HTML or plain-text page from a
  /// proxy, an empty body, or JSON without an `id`) becomes a `SIGNING_NETWORK_ERROR` whose message
  /// is the transport's `"<status> - <body>"`, cut to `signingNetworkErrorMessageLimit` Unicode
  /// scalars, so the signer throws a `PortalMpcError` that keeps the HTTP status instead of
  /// reporting a missing signature. A 401 keeps its result with no error: the transport's
  /// unauthorized hook, installed by `Portal.init`, handles the rejected credential (see
  /// `PortalMpcError.isAuthFailure`).
  private func encodeErrorResult(requestError: PortalRequestsError) -> String {
    if let portalError = decodePortalError(errorStr: requestError.dataStr), portalError.isValid() {
      return encodeErrorResult(error: portalError)
    }
    switch requestError {
    case let .clientError(message, _), let .internalServerError(message, _):
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: Self.signingNetworkErrorMessage(message))
    case let .redirectError(message):
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: Self.signingNetworkErrorMessage(message))
    case .couldNotParseHttpResponse:
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: requestError.localizedDescription)
    case .unauthorized:
      return encodeErrorResult(error: nil)
    }
  }

  /// The most Unicode scalars of a transport message a `SIGNING_NETWORK_ERROR` keeps. The body
  /// comes from whatever answered, such as a proxy page that can run to several KB, and the signer
  /// logs the message when a presignature sign fails, so only the start of a longer message is
  /// kept. The limit counts scalars, at most 4 UTF-8 bytes each, rather than characters: one
  /// character can carry any number of combining marks, so a character limit bounds nothing.
  static let signingNetworkErrorMessageLimit = 256

  /// `transportMessage`, or its first `signingNetworkErrorMessageLimit` Unicode scalars followed by
  /// a truncation marker when it is longer. The cut can split a character, such as a letter from
  /// its accent, which is harmless in an error message.
  private static func signingNetworkErrorMessage(_ transportMessage: String) -> String {
    let scalars = transportMessage.unicodeScalars
    guard scalars.count > signingNetworkErrorMessageLimit else {
      return transportMessage
    }
    return String(scalars.prefix(signingNetworkErrorMessageLimit)) + "… (truncated)"
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
  // The enclave reads `signatureApprovalMemo`, `isRaw` and `reqId` out of `metadataStr`
  // for raw signs too (`RawSignRequest.MetadataStr`), so raw requests send the same
  // metadata as `/v1/sign`, matching the React Native SDK.
  private func enclaveRawSign(
    token: String?,
    signingShare: String?,
    params: String?,
    metadata: String?,
    curve: PortalCurve?
  ) async -> String {
    guard let token = token,
          let signingShare = signingShare,
          let params = params,
          let metadata,
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
      "metadataStr": metadata,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ]

    do {
      let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: token)
      let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
      return encodeSuccessResult(data: enclaveResponse.data)
    } catch {
      if let portalRequestError = error as? PortalRequestsError {
        return encodeErrorResult(requestError: portalRequestError)
      }
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
  }

  private func enclaveSign(
    token: String?,
    signingShare: String?,
    method: String?,
    params: String?,
    rpcURL: String?,
    chainId: String?,
    metadata: String?
  ) async -> String {
    guard let token,
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
      let request = PortalAPIRequest(
        url: url,
        method: .post,
        payload: requestBody,
        bearerToken: token,
        additionalHeaders: idempotencyKeyHeaders(method: method, metadata: metadata)
      )
      let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
      return encodeSuccessResult(data: enclaveResponse.data)
    } catch {
      if let portalRequestError = error as? PortalRequestsError {
        return encodeErrorResult(requestError: portalRequestError)
      }
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
  }
}

extension EnclaveMobileWrapper {
  func MobilePresign(
    _ token: String,
    _: String,
    _ shareStr: String,
    _: String,
    _ curve: PortalCurve?
  ) async -> String {
    return await enclavePresign(
      token: token,
      signingShare: shareStr,
      curve: curve
    )
  }

  func MobileSignWithPresignature(
    _ token: String?,
    _: String?,
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
        token: token,
        signingShare: shareStr,
        presignatureData: presignatureData,
        params: params,
        metadata: metadataStr,
        curve: curve
      )
    } else {
      return await enclaveSignWithPresignature(
        token: token,
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
    token: String?,
    signingShare: String?,
    curve: PortalCurve?
  ) async -> String {
    guard let token = token,
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
      let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: token)
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
    token: String?,
    signingShare: String?,
    presignatureData: String?,
    method: String?,
    params: String?,
    rpcURL: String?,
    chainId: String?,
    metadata: String?
  ) async -> String {
    guard let token, let signingShare, let presignatureData,
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
      let request = PortalAPIRequest(
        url: url,
        method: .post,
        payload: requestBody,
        bearerToken: token,
        additionalHeaders: idempotencyKeyHeaders(method: method, metadata: metadata)
      )
      let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
      return encodeSuccessResult(data: enclaveResponse.data)
    } catch {
      if let portalRequestError = error as? PortalRequestsError {
        return encodeErrorResult(requestError: portalRequestError)
      }
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
  }

  private func enclaveRawSignWithPresignature(
    token: String?,
    signingShare: String?,
    presignatureData: String?,
    params: String?,
    metadata: String?,
    curve: PortalCurve?
  ) async -> String {
    guard let token = token,
          let signingShare = signingShare,
          let presignatureData = presignatureData,
          let params = params,
          let metadata = metadata,
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
      "metadataStr": metadata,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ]

    do {
      let request = PortalAPIRequest(url: url, method: .post, payload: requestBody, bearerToken: token)
      let enclaveResponse = try await requests.execute(request: request, mappingInResponse: EnclaveSignResponse.self)
      return encodeSuccessResult(data: enclaveResponse.data)
    } catch {
      if let portalRequestError = error as? PortalRequestsError {
        return encodeErrorResult(requestError: portalRequestError)
      }
      return encodeErrorResult(id: "SIGNING_NETWORK_ERROR", message: error.localizedDescription)
    }
  }

  private func encodePresignErrorResult(id: String?, message: String?) -> String {
    let result = PresignResponse(id: nil, expiresAt: nil, data: nil, error: PortalError(id: id, message: message))
    return encodeJSON(result)
  }
}

// MARK: - Idempotency key

extension EnclaveMobileWrapper {
  /// The one metadata field the wrapper reads itself. Decoding the whole `MpcMetadata` would fail
  /// on metadata strings that omit its required fields.
  private struct EnclaveMetadataKeys: Decodable {
    let idempotencyKey: String?
  }

  /// The `Idempotency-Key` header for a `POST /v1/sign` request, or no header.
  ///
  /// `PortalMpcSigner` puts the key in the signing metadata (never for a raw sign); the enclave
  /// reads it from this header instead. The header is attached only when all of these hold:
  /// - `metadata` is JSON with a non-empty `idempotencyKey` after trimming;
  /// - `method` is one of the three broadcasts the enclave protects, since it rejects a key on
  ///   any other method with HTTP 400.
  ///
  /// There is no host check: the request goes to `enclaveMPCHost`, the Enclave host this instance
  /// was configured with, which already receives the request's bearer credential. A self-hosted or
  /// CNAME'd Enclave host gets the key like the default one, as on Android.
  ///
  /// A key that cannot be attached is dropped with one warning. The key itself is never logged.
  private func idempotencyKeyHeaders(method: String, metadata: String) -> [String: String] {
    guard let rawKey = (try? JSONDecoder().decode(EnclaveMetadataKeys.self, from: Data(metadata.utf8)))?.idempotencyKey else {
      return [:]
    }
    let key = trimIdempotencyKey(rawKey)
    guard !key.isEmpty else {
      return [:]
    }
    guard PortalRequestMethod(rawValue: method)?.supportsIdempotencyKey == true else {
      PortalLogger.shared.warn("EnclaveMobileWrapper - idempotencyKey not sent: the MPC Enclave API accepts it only for eth_sendTransaction, sol_signAndSendTransaction and sol_signAndConfirmTransaction, not \(method)")
      return [:]
    }
    return [PORTAL_IDEMPOTENCY_KEY_HEADER: key]
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

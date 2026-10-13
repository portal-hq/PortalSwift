//
//  YieldXyzPerpsErrors.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Stable error identifiers the Portal API returns as `id` for Yield.xyz Perps requests.
public enum YieldXyzPerpsErrorId {
  /// Yield.xyz changed a response shape; the feature is unavailable until Portal adapts. Not the
  /// caller's fault: treat it as a temporary outage, and do not retry in a tight loop.
  public static let integrationResponseSchemaDrift = "INTEGRATION_RESPONSE_SCHEMA_DRIFT"
  /// The client is account-abstracted; perps actions require an EOA client.
  public static let integrationRequiresEoaClient = "INTEGRATION_REQUIRES_EOA_CLIENT"
  /// The EIP-712 payload could not be hashed, so the signer could not be verified.
  public static let signatureUnverifiable = "PERPS_SIGNATURE_UNVERIFIABLE"
  /// No signer could be recovered from the signature.
  public static let signatureInvalid = "PERPS_SIGNATURE_INVALID"
  /// The signature recovered to a different account than the action was built for.
  public static let signatureAddressMismatch = "PERPS_SIGNATURE_ADDRESS_MISMATCH"
}

/// A request the SDK refuses before sending it.
public enum YieldXyzPerpsError: LocalizedError, Equatable {
  /// No `address` was given and no Portal EVM wallet address is available to default to.
  case noAddress
  /// The method needs a venue: `providerId` or a non-empty `providerIds`.
  case providerRequired(method: String)
  /// `submitTransaction` needs a `signedPayload` or a `transactionHash`.
  case submissionRequired
  /// `submitTransaction` needs `actionId` with a `signedPayload`.
  case actionIdRequired

  public var errorDescription: String? {
    switch self {
    case .noAddress:
      return "[YieldXyzPerps] No address was provided and no Portal EVM wallet address is available."
    case let .providerRequired(method):
      return "[YieldXyzPerps] \(method) requires providerId or providerIds."
    case .submissionRequired:
      return "[YieldXyzPerps] submitTransaction requires a signedPayload or a transactionHash."
    case .actionIdRequired:
      return "[YieldXyzPerps] submitTransaction requires actionId when submitting a signedPayload."
    }
  }
}

/// The Portal API error behind a failed Yield.xyz Perps request: its HTTP status and the `error`,
/// `id` and `details` of the response body. `details.code` carries the venue's machine-readable
/// code when there is one (for example `EXECUTE_PRECONDITION_FAILED`).
///
/// The API methods throw the transport's error unchanged; read this from it with `from(_:)`.
public struct YieldXyzPerpsApiError: Error, Equatable {
  /// The HTTP status, when the request reached the Portal API.
  public let status: Int?
  /// The stable error identifier, when the Portal API sent one (see `YieldXyzPerpsErrorId`).
  public let id: String?
  /// The response's `error` message, or its raw body when it is not a Portal error object.
  public let message: String?
  public let details: [String: AnyCodable]?

  public init(status: Int?, id: String? = nil, message: String? = nil, details: [String: AnyCodable]? = nil) {
    self.status = status
    self.id = id
    self.message = message
    self.details = details
  }

  /// The Portal API error behind `error`, unwrapping a `YieldXyzPerpsExecutionError`'s underlying
  /// error. `nil` when `error` is not an HTTP failure (for example a transport or decoding error).
  public static func from(_ error: Error?) -> YieldXyzPerpsApiError? {
    switch error {
    case let apiError as YieldXyzPerpsApiError:
      return apiError
    case let executionError as YieldXyzPerpsExecutionError:
      return from(executionError.underlyingError)
    case let requestsError as PortalRequestsError:
      return from(requestsError)
    default:
      return nil
    }
  }

  /// `true` for `INTEGRATION_RESPONSE_SCHEMA_DRIFT`.
  public var isSchemaDrift: Bool {
    id == YieldXyzPerpsErrorId.integrationResponseSchemaDrift
  }

  /// `true` for `INTEGRATION_REQUIRES_EOA_CLIENT`.
  public var isEoaRequired: Bool {
    id == YieldXyzPerpsErrorId.integrationRequiresEoaClient
  }

  /// `true` for any `PERPS_SIGNATURE_*` rejection: a client-side signing problem, never worth
  /// retrying as-is.
  public var isSignatureError: Bool {
    id == YieldXyzPerpsErrorId.signatureUnverifiable
      || id == YieldXyzPerpsErrorId.signatureInvalid
      || id == YieldXyzPerpsErrorId.signatureAddressMismatch
  }

  /// `true` for a `429` rate limit.
  public var isRateLimit: Bool {
    status == 429
  }

  private struct Body: Decodable {
    let error: String?
    let id: String?
    let details: [String: AnyCodable]?
  }

  private static func from(_ error: PortalRequestsError) -> YieldXyzPerpsApiError? {
    let message: String
    switch error {
    case .unauthorized:
      return YieldXyzPerpsApiError(status: 401)
    case let .clientError(text, _), let .internalServerError(text, _), let .redirectError(text):
      message = text
    case .couldNotParseHttpResponse:
      return nil
    }

    // The transport reports a failure as "<status> - <body>".
    let status = message.components(separatedBy: " - ").first.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard let body = error.dataStr, !body.isEmpty else {
      return YieldXyzPerpsApiError(status: status)
    }
    guard let decoded = try? JSONDecoder().decode(Body.self, from: Data(body.utf8)) else {
      return YieldXyzPerpsApiError(status: status, message: body)
    }
    return YieldXyzPerpsApiError(status: status, id: decoded.id, message: decoded.error ?? body, details: decoded.details)
  }
}

/// How a failed Portal API request is retried by the execution runner.
enum YieldXyzPerpsRequestFailure {
  /// `true` when the credential is spent: retrying cannot help.
  static func isCredentialFailure(_ error: Error) -> Bool {
    if error is PortalCredentialError {
      return true
    }
    if case PortalRequestsError.unauthorized = error {
      return true
    }
    return false
  }

  /// The HTTP status of `error`, when the request got an HTTP response.
  static func status(of error: Error) -> Int? {
    guard error is PortalRequestsError else {
      return nil
    }
    return YieldXyzPerpsApiError.from(error)?.status
  }

  /// A failed read worth repeating as-is: a rate limit, a 5xx, or a failure with no HTTP status
  /// (transport, or a body that did not decode). A spent credential never is.
  static func isTransient(_ error: Error) -> Bool {
    if isCredentialFailure(error) {
      return false
    }
    if let status = status(of: error) {
      return status == 429 || status >= 500
    }
    return true
  }

  /// A failure after which the backend may or may not have processed the request: a 5xx, or a
  /// failure with no HTTP status.
  static func isAmbiguous(_ error: Error) -> Bool {
    if isCredentialFailure(error) {
      return false
    }
    if let status = status(of: error) {
      return status >= 500
    }
    return true
  }
}

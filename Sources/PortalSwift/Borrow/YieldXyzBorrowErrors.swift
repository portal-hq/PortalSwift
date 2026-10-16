//
//  YieldXyzBorrowErrors.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Stable error identifiers the Portal API returns as `id` for Yield.xyz Borrow requests. Other
/// failures (validation, an unsupported chain, a request Yield.xyz rejected, the integration not
/// being enabled) are `400`s without an `id`; their `message` says which.
public enum YieldXyzBorrowErrorId {
  /// Yield.xyz changed a response shape; the feature is unavailable until Portal adapts. Not the
  /// caller's fault: treat it as a temporary outage, and do not retry in a tight loop.
  public static let integrationResponseSchemaDrift = "INTEGRATION_RESPONSE_SCHEMA_DRIFT"
}

/// A request the SDK refuses before sending it.
public enum YieldXyzBorrowError: LocalizedError, Equatable {
  /// `submitTransaction` needs a `transactionHash` or a `signedPayload`.
  case submissionRequired
  /// An id sent in the request path (for example `marketId`) is empty.
  case emptyIdentifier(name: String)

  public var errorDescription: String? {
    switch self {
    case .submissionRequired:
      return "[YieldXyzBorrow] submitTransaction requires a transactionHash or a signedPayload."
    case let .emptyIdentifier(name):
      return "[YieldXyzBorrow] \(name) must not be empty."
    }
  }
}

extension YieldXyzBorrowError: YieldXyzRequestRefusedBeforeSending {}

/// The Portal API error behind a failed Yield.xyz Borrow request: its HTTP status and the `error`,
/// `id` and `details` of the response body.
///
/// The API methods throw the transport's error unchanged; read this from it with `from(_:)`.
public struct YieldXyzBorrowApiError: Error, Equatable {
  /// The HTTP status, when the request reached the Portal API.
  public let status: Int?
  /// The stable error identifier, when the Portal API sent one (see `YieldXyzBorrowErrorId`).
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

  /// The Portal API error behind `error`, unwrapping a `YieldXyzBorrowExecutionError`'s underlying
  /// error. `nil` when `error` is not an HTTP failure (for example a transport or decoding error).
  public static func from(_ error: Error?) -> YieldXyzBorrowApiError? {
    switch error {
    case let apiError as YieldXyzBorrowApiError:
      return apiError
    case let executionError as YieldXyzBorrowExecutionError:
      return from(executionError.underlyingError)
    case let requestsError as PortalRequestsError:
      return YieldXyzApiErrorBody.parse(requestsError).map {
        YieldXyzBorrowApiError(status: $0.status, id: $0.id, message: $0.message, details: $0.details)
      }
    default:
      return nil
    }
  }

  /// `true` for `INTEGRATION_RESPONSE_SCHEMA_DRIFT`.
  public var isSchemaDrift: Bool {
    id == YieldXyzBorrowErrorId.integrationResponseSchemaDrift
  }

  /// `true` for a `429` rate limit.
  public var isRateLimit: Bool {
    status == 429
  }
}

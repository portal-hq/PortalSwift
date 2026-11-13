//
//  MeldErrors.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// A request the SDK refuses before sending it.
public enum MeldError: LocalizedError, Equatable {
  /// A value sent in the request path (for example `transactionId`) is empty.
  case emptyIdentifier(name: String)

  public var errorDescription: String? {
    switch self {
    case let .emptyIdentifier(name):
      return "[Meld] \(name) must not be empty."
    }
  }
}

/// The Portal API error behind a failed Meld request: its HTTP status and the `error` and `id` of the
/// response body.
///
/// The API methods throw the transport's error unchanged; read this from it with `from(_:)`.
/// - Meld's own rejections keep Meld's status (400, 403, 404, 409 or 422) and a message starting
///   `Meld API error:`; any other Meld failure, a rate limit included, is a `502`.
/// - A `401` has no message: the transport reports it as `PortalRequestsError.unauthorized`.
/// - The transaction reads answer a transaction that does not exist, or is not the client's, with a
///   `404` reading `Meld transaction does not exist.`, without the prefix.
/// - `createCustomer` fails with `409` when the client already has a Meld customer; `meldCustomerId`
///   is that customer's id when Portal has it on record. When it is `nil`, call `searchCustomer()`.
/// - A `400` with `Meld integration is not enabled…` means Meld is not enabled for the environment in
///   the Portal Dashboard.
public struct MeldApiError: Error, Equatable {
  /// The HTTP status, when the request reached the Portal API.
  public let status: Int?
  /// The stable error identifier, when the Portal API sent one.
  public let id: String?
  /// The response's `error` message, or its raw body when it is not a Portal error object.
  public let message: String?
  /// The existing customer's id, on the `409` from `createCustomer`, when Portal has the customer on
  /// record.
  public let meldCustomerId: String?

  public init(status: Int?, id: String? = nil, message: String? = nil, meldCustomerId: String? = nil) {
    self.status = status
    self.id = id
    self.message = message
    self.meldCustomerId = meldCustomerId
  }

  /// The Portal API error behind `error`. `nil` when `error` is not an HTTP failure (for example a
  /// transport or decoding error, or a `MeldError`).
  public static func from(_ error: Error?) -> MeldApiError? {
    switch error {
    case let apiError as MeldApiError:
      return apiError
    case let requestsError as PortalRequestsError:
      return PortalIntegrationApiErrorBody.parse(requestsError).map {
        MeldApiError(
          status: $0.status,
          id: $0.id,
          message: $0.message,
          meldCustomerId: $0.details?["meldCustomerId"]?.value as? String
        )
      }
    default:
      return nil
    }
  }
}

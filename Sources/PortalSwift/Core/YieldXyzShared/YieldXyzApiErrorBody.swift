//
//  YieldXyzApiErrorBody.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// The HTTP status and the `error`, `id` and `details` of a failed Portal API request, read from
/// the transport's error. Shared by the Yield.xyz integrations' public API error types.
struct YieldXyzApiErrorBody: Equatable {
  let status: Int?
  let id: String?
  /// The response's `error` message, or its raw body when it is not a Portal error object.
  let message: String?
  let details: [String: AnyCodable]?

  init(status: Int?, id: String? = nil, message: String? = nil, details: [String: AnyCodable]? = nil) {
    self.status = status
    self.id = id
    self.message = message
    self.details = details
  }

  private struct Body: Decodable {
    let error: String?
    let id: String?
    let details: [String: AnyCodable]?
  }

  /// `nil` when `error` carries no HTTP response.
  static func parse(_ error: PortalRequestsError) -> YieldXyzApiErrorBody? {
    let message: String
    switch error {
    case .unauthorized:
      return YieldXyzApiErrorBody(status: 401)
    case let .clientError(text, _), let .internalServerError(text, _), let .redirectError(text):
      message = text
    case .couldNotParseHttpResponse:
      return nil
    }

    // The transport reports a failure as "<status> - <body>".
    let status = message.components(separatedBy: " - ").first.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard let body = error.dataStr, !body.isEmpty else {
      return YieldXyzApiErrorBody(status: status)
    }
    guard let decoded = try? JSONDecoder().decode(Body.self, from: Data(body.utf8)) else {
      return YieldXyzApiErrorBody(status: status, message: body)
    }
    return YieldXyzApiErrorBody(status: status, id: decoded.id, message: decoded.error ?? body, details: decoded.details)
  }
}

/// An error a Yield.xyz API client raises before sending the request (an empty path id, a missing
/// submission). The backend never saw the request, and repeating it fails the same way.
protocol YieldXyzRequestRefusedBeforeSending: Error {}

/// How a failed Portal API request is retried by the Yield.xyz execution runners.
enum YieldXyzRequestFailure {
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

  /// `true` when the request was never sent: the client refused it, or could not encode it or build
  /// its URL.
  static func isRefusedBeforeSending(_ error: Error) -> Bool {
    if error is YieldXyzRequestRefusedBeforeSending {
      return true
    }
    if case PortalApiError.unableToEncodeData = error {
      return true
    }
    if let urlError = error as? URLError, urlError.code == .badURL {
      return true
    }
    return false
  }

  /// The HTTP status of `error`, when the request got an HTTP response.
  static func status(of error: Error) -> Int? {
    guard let requestsError = error as? PortalRequestsError else {
      return nil
    }
    return YieldXyzApiErrorBody.parse(requestsError)?.status
  }

  /// `true` for a `429` rate limit.
  static func isRateLimit(_ error: Error) -> Bool {
    status(of: error) == 429
  }

  /// A failed read worth repeating as-is: a rate limit, a 5xx, or a failure with no HTTP status
  /// (transport, or a body that did not decode). A spent credential, or a request that was never
  /// sent, never is.
  static func isTransient(_ error: Error) -> Bool {
    if isCredentialFailure(error) || isRefusedBeforeSending(error) {
      return false
    }
    if let status = status(of: error) {
      return status == 429 || status >= 500
    }
    return true
  }

  /// A failure after which the backend may or may not have processed the request: a 5xx, or a
  /// failure with no HTTP status. A request that was never sent is not ambiguous.
  static func isAmbiguous(_ error: Error) -> Bool {
    if isCredentialFailure(error) || isRefusedBeforeSending(error) {
      return false
    }
    if let status = status(of: error) {
      return status >= 500
    }
    return true
  }
}

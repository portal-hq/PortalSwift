//
//  PortalIntegrationApiErrorBody.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// The HTTP status and the `error`, `id` and `details` of a failed Portal API request, read from
/// the transport's error. Shared by the Portal integrations' public API error types.
struct PortalIntegrationApiErrorBody: Equatable {
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
  static func parse(_ error: PortalRequestsError) -> PortalIntegrationApiErrorBody? {
    let message: String
    switch error {
    case .unauthorized:
      return PortalIntegrationApiErrorBody(status: 401)
    case let .clientError(text, _), let .internalServerError(text, _), let .redirectError(text):
      message = text
    case .couldNotParseHttpResponse:
      return nil
    }

    // The transport reports a failure as "<status> - <body>".
    let status = message.components(separatedBy: " - ").first.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard let body = error.dataStr, !body.isEmpty else {
      return PortalIntegrationApiErrorBody(status: status)
    }
    guard let decoded = try? JSONDecoder().decode(Body.self, from: Data(body.utf8)) else {
      return PortalIntegrationApiErrorBody(status: status, message: body)
    }
    return PortalIntegrationApiErrorBody(status: status, id: decoded.id, message: decoded.error ?? body, details: decoded.details)
  }
}

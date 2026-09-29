//
//  PortalAPIRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 15/05/2025.
//

import Foundation

public protocol PortalBaseRequestProtocol {
  var url: URL { get }
  var method: HttpMethod { get }
  var headers: [String: String] { get }
  var payload: (any Codable)? { get }
}

public extension PortalBaseRequestProtocol {
  var method: HttpMethod { return .get }
  var headers: [String: String] {
    return [
      "Accept": "application/json",
      "Content-Type": "application/json"
    ]
  }

  var payload: (any Codable)? { return nil }
}

/// Use this PortalAPIRequest to create simple get request with only custom URL
public class PortalAPIRequest: PortalBaseRequestProtocol {
  public var url: URL
  public var method: HttpMethod
  public var headers: [String: String]
  public var payload: (any Codable)?

  public required init(
    url: URL,
    method: HttpMethod = .get,
    payload: (any Codable)? = nil,
    bearerToken: String? = nil,
    traceId: String? = nil
  ) {
    self.url = url
    self.method = method
    self.payload = payload

    var defaultHeaders = [
      "Accept": "application/json",
      "Content-Type": "application/json",
      PORTAL_TRACE_ID_HEADER: traceId ?? generateTraceId()
    ]
    if let bearerToken = bearerToken {
      defaultHeaders["Authorization"] = "Bearer \(bearerToken)"
    }

    self.headers = defaultHeaders
  }

  /// Creates a request that also carries `additionalHeaders`.
  ///
  /// - Parameter additionalHeaders: Extra headers for this request only, such as
  ///   `PORTAL_IDEMPOTENCY_KEY_HEADER`. They are added to the default headers and never replace
  ///   one: a name matching a default header, in any casing, is ignored. The defaults are `Accept`,
  ///   `Content-Type`, the trace id header, and `Authorization` when `bearerToken` is set.
  public convenience init(
    url: URL,
    method: HttpMethod = .get,
    payload: (any Codable)? = nil,
    bearerToken: String? = nil,
    traceId: String? = nil,
    additionalHeaders: [String: String]
  ) {
    self.init(url: url, method: method, payload: payload, bearerToken: bearerToken, traceId: traceId)

    let defaultHeaderNames = Array(self.headers.keys)
    for (name, value) in additionalHeaders {
      let overridesDefault = defaultHeaderNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
      if !overridesDefault {
        self.headers[name] = value
      }
    }
  }
}

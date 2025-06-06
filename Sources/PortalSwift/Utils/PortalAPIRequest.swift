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
    bearerToken: String? = nil
  ) {
    self.url = url
    self.method = method
    self.payload = payload

    var defaultHeaders = [
      "Accept": "application/json",
      "Content-Type": "application/json"
    ]
    if let bearerToken = bearerToken {
      defaultHeaders["Authorization"] = "Bearer \(bearerToken)"
    }

    self.headers = defaultHeaders
  }
}

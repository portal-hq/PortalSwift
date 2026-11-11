//
//  YieldXyzRequestBuilder.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Builds the URLs of a Yield.xyz integration proxy (`/api/v3/clients/me/integrations/<name>`), with
/// the same wire format as the other Portal SDKs.
struct YieldXyzRequestBuilder {
  /// The characters `encodeURIComponent` leaves unescaped. Query values and path segments are
  /// encoded with it so the wire format matches the other Portal SDKs, and so `+`, `&`, `=`, `,`,
  /// `/` and `:` never reach the server unescaped (Express decodes a raw `+` as a space).
  static let uriComponentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
  )

  /// `https://<host>` (or `http://localhost…`).
  let baseUrl: String
  /// The integration's base path, e.g. `/api/v3/clients/me/integrations/yield-xyz-borrow`.
  let basePath: String
  /// The error thrown for an empty path id, named after the parameter.
  let emptyIdentifier: (_ name: String) -> Error

  /// Percent-encodes `value` as a single URI component.
  static func encodeURIComponent(_ value: String) -> String? {
    value.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
  }

  /// Comma-joins a list filter, skipping blank entries; an empty list is not sent.
  static func joined(_ values: [String]?) -> String? {
    guard let values = values?.filter({ !$0.isEmpty }), !values.isEmpty else {
      return nil
    }
    return values.joined(separator: ",")
  }

  /// Encodes an id as a single path segment. An empty id is rejected: `/markets/` would reach the
  /// list route instead.
  func pathSegment(_ name: String, _ value: String) throws -> String {
    guard !value.isEmpty else {
      throw emptyIdentifier(name)
    }
    guard let encoded = Self.encodeURIComponent(value) else {
      throw PortalApiError.unableToEncodeData
    }
    return encoded
  }

  /// Builds the URL of `path` with the query items that have a value, in the order given. An empty
  /// value is not sent: the Portal API rejects an empty string.
  func makeUrl(path: String, query: [(String, String?)] = []) throws -> URL {
    var urlString = "\(baseUrl)\(basePath)\(path)"
    var pairs: [String] = []
    for (name, value) in query {
      guard let value, !value.isEmpty else {
        continue
      }
      guard let encoded = Self.encodeURIComponent(value) else {
        throw PortalApiError.unableToEncodeData
      }
      pairs.append("\(name)=\(encoded)")
    }
    if !pairs.isEmpty {
      urlString += "?" + pairs.joined(separator: "&")
    }
    guard let url = URL(string: urlString) else {
      throw URLError(.badURL)
    }
    return url
  }
}

//
//  YieldXyzOpenValue.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// A string value the backend types as an open set: the known values are listed as static
/// members, and a value Yield.xyz adds later decodes as-is and re-encodes verbatim instead of
/// failing or collapsing to `unknown`.
///
/// Compare with `==` or `switch` on the static members (a `switch` needs a `default`).
public protocol YieldXyzOpenValue: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral,
  CustomStringConvertible where RawValue == String
{
  init(rawValue: String)
}

public extension YieldXyzOpenValue {
  init(stringLiteral value: String) {
    self.init(rawValue: value)
  }

  /// Decodes the bare string, whatever its value.
  init(from decoder: Decoder) throws {
    try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
  }

  /// Encodes the raw string unchanged.
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  var description: String {
    rawValue
  }
}

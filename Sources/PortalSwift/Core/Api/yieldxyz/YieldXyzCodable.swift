//
//  YieldXyzCodable.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation

/// A `String`-backed, Codable enum that decodes unrecognized values to a designated `unknownValue`
/// instead of throwing.
///
/// Yield.xyz (StakeKit) is an external provider that periodically adds new action/transaction and
/// opportunity types. Without this, a single unrecognized value would fail decoding of the entire
/// response (e.g. an `enter`/`exit`/`discover` payload), breaking otherwise-usable operations.
public protocol YieldXyzUnknownTolerantEnum: RawRepresentable, Codable where RawValue == String {
  /// The case returned when the decoded raw value is not recognized.
  static var unknownValue: Self { get }
}

public extension YieldXyzUnknownTolerantEnum {
  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = Self(rawValue: rawValue) ?? Self.unknownValue
  }
}

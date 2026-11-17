//
//  Ramps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for ramps-related (on/off-ramp) functionality in the Portal SDK.
///
/// This class provides access to various on/off-ramp providers and their capabilities:
/// Noah and Meld.
public class Ramps {
  /// Access to the Noah on/off-ramp provider functionality.
  /// This property can be set for custom implementations.
  public var noah: NoahProtocol

  /// Access to the Meld on/off-ramp aggregator.
  /// This property can be set for custom implementations.
  public var meld: MeldProtocol

  /// Create an instance of Ramps around provider implementations, for example test doubles for a
  /// `PortalProtocol` conformance.
  /// - Parameters:
  ///   - noah: The Noah implementation `noah` returns.
  ///   - meld: The Meld implementation `meld` returns.
  public init(noah: NoahProtocol, meld: MeldProtocol) {
    self.noah = noah
    self.meld = meld
  }

  /// Create an instance of `Ramps`.
  /// - Parameter api: The Portal API instance to use for ramps operations.
  convenience init(api: PortalApiProtocol) {
    self.init(noah: Noah(api: api.noah), meld: Meld(api: api.meld))
  }
}

//
//  Ramps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for ramps-related (on/off-ramp) functionality in the Portal SDK.
///
/// This class provides access to various on/off-ramp providers and their capabilities.
/// Currently supports Noah as the primary ramps provider.
public class Ramps {
  /// Access to the Noah on/off-ramp provider functionality.
  /// This property can be set for custom implementations.
  public var noah: NoahProtocol

  /// Create an instance of `Ramps`.
  /// - Parameter api: The Portal API instance to use for ramps operations.
  init(api: PortalApiProtocol) {
    self.noah = Noah(api: api.noah)
  }
}

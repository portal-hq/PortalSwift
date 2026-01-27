//
//  Security.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for security-related functionality in the Portal SDK.
///
/// This class provides access to various security providers and their capabilities.
/// Supports Blockaid and Hypernative as security providers.
public class Security {
  
  /// Access to Blockaid security provider functionality.
  public var blockaid: BlockaidProtocol
  
  /// Access to Hypernative security provider functionality.
  public var hypernative: HypernativeProtocol

  /// Create an instance of Security.
  /// - Parameter api: The Portal API instance to use for security operations.
  init(api: PortalApiProtocol) {
    self.hypernative = Hypernative(api: api.hypernative)
    self.blockaid = Blockaid(api: api.blockaid)
  }
}

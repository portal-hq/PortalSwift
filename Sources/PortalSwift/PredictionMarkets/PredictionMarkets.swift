//
//  PredictionMarkets.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The main entry point for prediction-markets functionality in the Portal SDK.
///
/// Currently supports Agg.
public class PredictionMarkets {
  /// Access to Agg functionality: one method per Agg route, plus the helpers.
  /// This property can be set for custom implementations.
  public var agg: AggProtocol

  /// Create an instance of PredictionMarkets.
  /// - Parameters:
  ///   - api: The Portal API instance to use for prediction-markets operations.
  ///   - dependencies: What `connect` and `deposit` need to sign and send (injected by Portal).
  init(api: PortalApiProtocol, dependencies: AggDependencies = AggDependencies()) {
    self.agg = Agg(api: api.agg, dependencies: dependencies)
  }
}

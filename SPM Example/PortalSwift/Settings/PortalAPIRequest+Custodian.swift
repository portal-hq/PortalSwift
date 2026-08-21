//
//  PortalAPIRequest+Custodian.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 12/08/2026.
//  Copyright © 2026 Portal. All rights reserved.
//

import Foundation
import PortalSwift

/// Header the PortalEx custodian server expects on every request.
private let CUSTODIAN_API_KEY_HEADER = "x-api-key"

extension PortalAPIRequest {
  /// Builds a request for the PortalEx custodian server, stamping the environment-specific
  /// `x-api-key` header the custodian requires.
  ///
  /// Use this instead of `PortalAPIRequest(url:method:payload:)` for every request to
  /// `ApplicationConfiguration.custodianServerUrl`. Requests to the Portal API itself must keep
  /// using the plain initializer, as they authenticate with a bearer token instead.
  static func custodian(
    url: URL,
    method: HttpMethod = .get,
    payload: (any Codable)? = nil
  ) -> PortalAPIRequest {
    let request = PortalAPIRequest(url: url, method: method, payload: payload)

    // Empty for `.localHost`, which runs a custodian server that doesn't check the key.
    // For production and staging, `Settings.requireSecret` guarantees this is non-empty.
    if let custodianApiKey = Settings.shared.portalConfig.appConfig?.custodianApiKey, !custodianApiKey.isEmpty {
      request.headers[CUSTODIAN_API_KEY_HEADER] = custodianApiKey
    }

    return request
  }
}

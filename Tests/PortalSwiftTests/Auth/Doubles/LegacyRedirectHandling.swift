//
//  LegacyRedirectHandling.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// The deprecated `handleRedirect(_:)`, reached through a protocol so the tests that exercise it on
/// purpose need no deprecated context of their own.
///
/// A call made through a protocol requirement does not warn even though the type's witness is
/// deprecated, so this silences that one method and nothing else: marking whole test classes
/// deprecated instead would also hide a future deprecation of anything else they call.
protocol LegacyRedirectHandling {
  func handleRedirect(_ url: String) async throws -> AuthResult?
  func handleRedirect(_ url: URL) async throws -> AuthResult?
}

extension PortalAuth: LegacyRedirectHandling {}

extension PortalAuth {
  /// `self`, seen as `LegacyRedirectHandling`: `auth.legacy.handleRedirect(url)` calls the
  /// deprecated method without a warning.
  var legacy: LegacyRedirectHandling {
    self
  }
}

//
//  AuthFailingEjectMobile.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A binary whose eject calls come back with the MPC service's `AUTH_FAILED` — the id the Go
/// binary uses for a rejected credential — so `PortalMpcTests` can prove eject classifies it
/// like every other binary operation instead of surfacing a generic eject error.
final class AuthFailingEjectMobile: MockMobileWrapper {
  private static let authFailed = "{\"privateKey\":\"\",\"error\":{\"id\":\"AUTH_FAILED\",\"code\":401,\"message\":\"401 - Unauthorized\"}}"

  override public func MobileEjectWalletAndDiscontinueMPC(_: String, _: String) -> String {
    Self.authFailed
  }

  override public func MobileEjectWalletAndDiscontinueMPCEd25519(_: String, _: String) -> String {
    Self.authFailed
  }
}

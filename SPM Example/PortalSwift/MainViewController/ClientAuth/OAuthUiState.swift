//
//  OAuthUiState.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// Which social sign-in controls are live.
///
/// One field per provider rather than a set keyed by `AuthMethod`: there are two, each maps to
/// exactly one button, and naming them makes a test that asserts one while the other stays put
/// possible to read.
struct OAuthUiState: Equatable {
  /// Google sign-in can be started.
  let canSignInWithGoogle: Bool
  /// Apple sign-in can be started.
  let canSignInWithApple: Bool
}

/// Resolves the social sign-in controls.
///
/// Kept a pure function for the same reason as `resolveAuthUiState(clientAuthSession:user:)`:
/// enablement expressed as a value is testable in the unit bundle, where the same logic
/// scattered across `isEnabled` assignments inside a view controller is not.
///
/// `allowedAuthMethods` is `nil` until **Get Auth Methods** has been tapped, and that state
/// enables both buttons rather than disabling them. A provider being enabled is the normal
/// case, the screen's whole idiom is that each step is a deliberate tap, and requiring a call
/// before the first button works would trade a clear backend error for a button that looks
/// broken. An empty array is a fetched answer, not an unfetched one, and disables both.
///
/// `isRequestInFlight` is deliberately **shared** across providers, not per provider: one
/// single-use `state` is shared by every authorize URL in a backend response, so resolving a
/// second provider invalidates the first one's URL. Disabling both for the duration is what
/// makes the one-tap version of that race unreachable.
func resolveOAuthUiState(
  isConfigured: Bool,
  allowedAuthMethods: [AuthMethod]?,
  isRequestInFlight: Bool
) -> OAuthUiState {
  func canSignIn(with method: AuthMethod) -> Bool {
    let isAllowed = allowedAuthMethods?.contains(method) ?? true

    return isConfigured && !isRequestInFlight && isAllowed
  }

  return OAuthUiState(
    canSignInWithGoogle: canSignIn(with: .google),
    canSignInWithApple: canSignIn(with: .apple)
  )
}

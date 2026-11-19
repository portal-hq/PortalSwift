//
//  MagicLinkConfirmation.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// A magic link whose email was read and is waiting on the user's Confirm or Cancel.
///
/// Holds the `AuthRedirect.MagicLink` rather than its bare token: the wrapper redacts the grant
/// when printed, so this state cannot leak it through a debug print. The email is shown on screen
/// and never logged.
struct PendingMagicLink: Equatable {
  let link: AuthRedirect.MagicLink
  let email: String
}

/// What to do with a magic link the app just received.
enum MagicLinkRoute: Equatable {
  /// The user already confirmed this link. It is spent, so its details can no longer be read;
  /// `confirmMagicLink` replays the sign-in it completed instead.
  case replay
  /// The link is already waiting on the user: show its confirmation again without a second
  /// lookup, because each link can be looked up only a few times.
  case showConfirmation(PendingMagicLink)
  /// A link not seen before: read its email, then ask the user.
  case fetchDetails
}

/// Routes a magic link through the confirmation step. Mirrors Android's `resolveMagicLinkRoute`:
/// - a link not seen before fetches its details;
/// - a link waiting on the user shows its confirmation again;
/// - a link the user already confirmed replays instead of reading details for a spent grant;
/// - a different link replaces the one waiting on the user.
///
/// A pure function so the decision is readable in one place: the SDK cannot tell a link delivered
/// again after confirmation from a fresh one by its token, so the app remembers which link it
/// confirmed. Nothing here ever exchanges a link that the user has not confirmed on screen.
func resolveMagicLinkRoute(
  link: AuthRedirect.MagicLink,
  pending: PendingMagicLink?,
  confirmed: AuthRedirect.MagicLink?
) -> MagicLinkRoute {
  if link == confirmed {
    return .replay
  }
  if let pending = pending, pending.link == link {
    return .showConfirmation(pending)
  }
  return .fetchDetails
}

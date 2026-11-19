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
/// when printed. The email is shown on the confirmation alert and redacted here too, so printing
/// this state cannot leak either.
struct PendingMagicLink: Equatable, CustomStringConvertible {
  let link: AuthRedirect.MagicLink
  let email: String

  var description: String {
    "PendingMagicLink(link: \(self.link), email: <redacted>)"
  }
}

/// What to do with a magic link the app just received.
enum MagicLinkRoute: Equatable {
  /// This link's confirmation is already running: wait for it rather than asking again.
  case alreadyConfirming
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
/// One more case than Android: a link whose confirmation is still running is neither asked about
/// again nor sent again, so a re-delivery mid-exchange cannot put a stale question on screen.
///
/// A pure function so the decision is readable in one place: the SDK cannot tell a link delivered
/// again after confirmation from a fresh one by its token, so the app remembers which link it
/// confirmed. Nothing here ever exchanges a link that the user has not confirmed on screen.
func resolveMagicLinkRoute(
  link: AuthRedirect.MagicLink,
  pending: PendingMagicLink?,
  confirming: AuthRedirect.MagicLink?,
  confirmed: AuthRedirect.MagicLink?
) -> MagicLinkRoute {
  if link == confirming {
    return .alreadyConfirming
  }
  if link == confirmed {
    return .replay
  }
  if let pending = pending, pending.link == link {
    return .showConfirmation(pending)
  }
  return .fetchDetails
}

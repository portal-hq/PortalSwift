//
//  ClientAuthCoordinator.swift
//  SPM Example
//
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift
import UIKit

/// Process-wide state for the Client Auth flow, and the one place an inbound redirect URL is
/// routed through.
///
/// The URL handler (`SceneDelegate`) knows nothing about the screen that asked for the login, and
/// the screen may not exist yet when the URL arrives — a magic link tapped while the app is not
/// running launches it. So the coordinator owns both halves: a `redirectSink` the live screen
/// installs, and a one-slot stash the screen drains when it appears.
///
/// Everything here is in-memory by design. The session token, the pending TOTP `userJwt` and the
/// redirect URL (which carries a single-use grant) are all bearer credentials: they live for the
/// life of the process and are never written to `UserDefaults` or logged. The only persisted
/// value is a boolean flag, `firstLaunchClearKey`.
///
/// Threading: the mutable properties are touched from the main thread (URL callbacks, view
/// lifecycle). Only the first-launch clear is thread-safe on its own, because it is `async` and
/// two screens can reach it at once.
final class ClientAuthCoordinator {
  /// The app-wide instance, keyed to the redirect scheme the Info.plist registers.
  static let shared = ClientAuthCoordinator(
    redirectScheme: Settings.shared.clientAuthConfig.redirectScheme,
    defaults: UserDefaults.standard
  )

  /// `UserDefaults` flag recording that the persisted (Keychain) session was cleared once for
  /// this install. Keychain items outlive app deletion, so a reinstall would otherwise restore
  /// the previous user's session on first launch.
  static let firstLaunchClearKey = "ClientAuth.didClearPersistedSessionAfterInstall"

  /// The scheme this app owns, lowercased once at construction; `nil` when Client Auth is not
  /// configured, in which case no URL is ever claimed.
  private let redirectScheme: String?
  private let defaults: UserDefaults
  private let warn: (String) -> Void

  /// The adopted session, held for the life of the process.
  var session: PortalSession?

  /// The `userJwt` of a TOTP step waiting on a code. Never persisted, never logged.
  var pendingTotpUserJwt: String?

  /// The live `Portal.onSessionInvalidated(_:)` subscription, cancelled before a new one is
  /// installed and on teardown.
  var sessionInvalidatedHandle: PortalSessionInvalidationHandle?

  /// Serializes session adoptions by session identity, so a launch-time restore and a redirect
  /// login for the same user — two different sessions — run one after the other on their own
  /// credentials, and only a redelivery of the very same session joins the run in flight.
  let adoptionGuard = AdoptionGuard<Bool>()

  /// The presented Client Auth screen, up-cast to `UIViewController` so this type carries no
  /// availability annotation and `SceneDelegate` can reach it unguarded.
  weak var activeScreen: UIViewController?

  /// Installed by the live screen while it can handle a redirect itself.
  var redirectSink: ((URL) -> Void)?

  /// One-slot handoff from the Client Auth screen to the main screen.
  private var handoffSession: PortalSession?

  /// One-slot stash for a redirect that arrived with no screen to take it.
  private var pendingLaunchURL: URL?

  private let firstLaunchLock = NSLock()

  /// Guarded by `firstLaunchLock`: the in-flight clear concurrent callers join. Its value is
  /// whether the clear completed, so a joiner learns the outcome rather than only the timing.
  private var firstLaunchClearTask: Task<Bool, Never>?

  init(redirectScheme: String?, defaults: UserDefaults = .standard, warn: @escaping (String) -> Void = { print($0) }) {
    let normalized = redirectScheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    self.redirectScheme = (normalized?.isEmpty ?? true) ? nil : normalized
    self.defaults = defaults
    self.warn = warn
  }

  // MARK: - Handoff

  /// Publishes an authenticated session for the main screen to adopt. Replaces any pending one:
  /// only the newest login is worth adopting.
  func setHandoff(_ session: PortalSession) {
    self.handoffSession = session
  }

  /// Takes the pending session, if any, and clears the slot so one login is adopted once.
  func consumeHandoff() -> PortalSession? {
    let pending = self.handoffSession
    self.handoffSession = nil
    return pending
  }

  // MARK: - Launch URL

  /// Holds a redirect until a screen is ready for it. In memory only — the URL carries a
  /// single-use grant token that must not survive the process.
  func stashLaunchURL(_ url: URL) {
    self.pendingLaunchURL = url
  }

  /// Takes the stashed redirect, if any, and clears the slot so it is handled once.
  func consumeLaunchURL() -> URL? {
    let pending = self.pendingLaunchURL
    self.pendingLaunchURL = nil
    return pending
  }

  // MARK: - URL routing

  /// Claims `url` when it is this app's Client Auth redirect.
  ///
  /// Matching is on the scheme alone, case-insensitively: the OS matched the same scheme to
  /// deliver the URL here, and validating the full redirect target is the SDK's job inside
  /// `handleRedirect`. A claimed URL goes to the live screen when there is one, and to the stash
  /// otherwise; it is never both, so a redirect cannot be handled twice.
  ///
  /// The URL is never logged: its query carries the grant token.
  ///
  /// - Returns: `true` when this app's Client Auth flow took the URL, so the caller can let
  ///   other handlers (the Google reversed-client-id scheme, WalletConnect) see the rest.
  @discardableResult
  func handleIfClientAuth(_ url: URL) -> Bool {
    guard let redirectScheme = self.redirectScheme else { return false }
    guard let scheme = url.scheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), scheme == redirectScheme else {
      return false
    }

    if let sink = self.redirectSink {
      sink(url)
    } else {
      self.stashLaunchURL(url)
    }

    return true
  }

  // MARK: - Teardown

  /// Drops everything this process holds about the signed-in user.
  ///
  /// Signing in as somebody else is not signing out, so this deliberately leaves persisted state
  /// alone: clearing the Keychain session is `handleClientAuthSignOut`'s job. Idempotent, and the
  /// invalidation subscription is cancelled exactly once.
  func clearInMemorySession() {
    self.session = nil
    self.pendingTotpUserJwt = nil
    self.handoffSession = nil

    let handle = self.sessionInvalidatedHandle
    self.sessionInvalidatedHandle = nil
    handle?.cancel()
  }

  // MARK: - First launch after install

  /// Runs `clearer` once per install, before the first `restoreSession()`.
  ///
  /// Keychain items survive app deletion, so without this the first launch after a reinstall
  /// would restore a session the user believes they removed with the app.
  ///
  /// The flag is set only after `clearer` succeeds, so a Keychain error means "try again next
  /// launch" rather than "silently skipped forever". A failure is swallowed and warned: a signed
  /// out user with a stale item is a nuisance, an app that will not start is worse.
  ///
  /// Concurrent callers coalesce onto one run.
  ///
  /// - Returns: whether the install is known to be clear of a previous install's session —
  ///   `true` when this launch's clear succeeded or an earlier launch already did it, `false`
  ///   when the clear failed. The caller must not restore on `false`: the entry that is still
  ///   on disk is the one this exists to remove.
  @discardableResult
  func clearPersistedSessionOnFirstLaunchIfNeeded(using clearer: @escaping () async throws -> Void) async -> Bool {
    guard !self.defaults.bool(forKey: Self.firstLaunchClearKey) else { return true }

    self.firstLaunchLock.lock()

    if let existing = self.firstLaunchClearTask {
      self.firstLaunchLock.unlock()
      return await existing.value
    }

    // Re-read under the lock. A caller that read `false` above and was descheduled while another
    // caller's clear ran to completion — flag set, slot emptied — would otherwise start a second
    // clear, and that one could delete a session persisted in between.
    guard !self.defaults.bool(forKey: Self.firstLaunchClearKey) else {
      self.firstLaunchLock.unlock()
      return true
    }

    // Created under the lock so the body's own cleanup cannot clear the slot before it is filled.
    let started = Task<Bool, Never> { [weak self] in
      // A deallocated coordinator cannot vouch for the Keychain, and the caller is about to
      // decide whether to restore on this answer.
      guard let self else { return false }

      let cleared: Bool
      do {
        try await clearer()
        self.defaults.set(true, forKey: Self.firstLaunchClearKey)
        cleared = true
      } catch {
        // Type name only: a Keychain or SDK error can carry the account it failed on.
        self.warn("ClientAuth: could not clear the persisted session on first launch (\(type(of: error))); will retry next launch.")
        cleared = false
      }

      self.firstLaunchLock.lock()
      self.firstLaunchClearTask = nil
      self.firstLaunchLock.unlock()

      return cleared
    }

    self.firstLaunchClearTask = started
    self.firstLaunchLock.unlock()

    return await started.value
  }

  /// Restores the persisted session, running the first-launch clear first.
  ///
  /// Split into two injected closures so the ordering — clear, then restore — is testable
  /// without a Keychain: getting it backwards would restore the very session the clear exists
  /// to remove.
  ///
  /// A failed clear skips the restore entirely. Restoring anyway would hand back the previous
  /// install's session — the one case this whole path exists to prevent — and only until the
  /// next launch, whose retry deletes it. Staying signed out for one launch is the honest
  /// outcome; the flag is still unset, so the clear runs again next time.
  func restoreClientAuthSession(clear: @escaping () async throws -> Void, restore: @escaping () async throws -> Void) async {
    guard await self.clearPersistedSessionOnFirstLaunchIfNeeded(using: clear) else {
      self.warn("ClientAuth: skipping session restore because the first-launch clear did not complete.")
      return
    }

    do {
      try await restore()
    } catch {
      self.warn("ClientAuth: restoring the persisted session failed (\(type(of: error))); treating the user as signed out.")
    }
  }
}

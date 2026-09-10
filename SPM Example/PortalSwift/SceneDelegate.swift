//
//  SceneDelegate.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import os
import UIKit

/// The example app runs on the `UIScene` lifecycle, so `UIApplicationDelegate`'s
/// `application(_:open:options:)` and the `launchOptions[.url]` cold-start key are never
/// used: every incoming URL arrives here instead — in `connectionOptions.urlContexts` when
/// the URL launches the app, and in `scene(_:openURLContexts:)` when the app is already
/// running.
///
/// Measured on the iOS 26.5 simulator during step 7a: with `UIApplicationSceneManifest`
/// deleted UIKit still connected a `UIWindowSceneSessionRoleApplication` scene and left the
/// app-delegate URL callbacks silent, so the manifest is declared again in `Info.plist` and
/// names this class through `UISceneDelegateClassName`. Both callbacks below were then
/// observed firing for `portalswiftexample://auth/callback` (cold start: `urlContexts=1`;
/// warm: `openURLContexts`).
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  /// Window ownership lives on the scene, not on `AppDelegate`. UIKit creates this window
  /// from the `UISceneStoryboardFile` (`Main`) before `scene(_:willConnectTo:options:)` runs.
  var window: UIWindow?

  /// Unified-log channel for the Client Auth URL handling. Only URL schemes and step names
  /// are ever written here; never the redirect URL itself (it carries a single-use grant
  /// token), and never its path or query.
  private let clientAuthLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SPM Example", category: "ClientAuth")

  /// Cold start: the URL that launched the app.
  func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    for context in connectionOptions.urlContexts {
      self.routeIncomingUrl(step: "cold-start", url: context.url)
    }
  }

  /// Warm start: a URL delivered while the app is already running.
  func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      self.routeIncomingUrl(step: "openURLContexts", url: context.url)
    }
  }

  /// Offers `url` to the Client Auth flow and records the outcome by scheme and step only.
  ///
  /// A URL the coordinator does not claim is left alone: the app registers a second scheme (the
  /// Google reversed client id) whose handling lives elsewhere.
  private func routeIncomingUrl(step: String, url: URL) {
    let claimed = ClientAuthCoordinator.shared.handleIfClientAuth(url)
    self.logClientAuthUrl(step: step, url: url, claimed: claimed)
  }

  /// Records that a URL reached the app on `step`, by scheme only.
  private func logClientAuthUrl(step: String, url: URL, claimed: Bool) {
    let scheme = url.scheme ?? "(none)"
    self.clientAuthLogger.notice("ClientAuth URL [\(step, privacy: .public)]: \(scheme, privacy: .public), claimed: \(claimed, privacy: .public)")
  }
}

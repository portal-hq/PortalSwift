//
//  ViewController+ClientAuth.swift
//  SPM Example
//
//  Client Auth integration for the main screen.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import os.log
import PortalSwift
import UIKit

/// The main screen's half of the Client Auth demo: it owns the *credential*, while
/// `ClientAuthViewController` owns the *login*.
///
/// The split follows the Android example (`MainActivity` + `ClientAuthActivity`): a login screen
/// can be cold-started by a redirect with no main screen behind it, so it must not be the thing
/// that builds `Portal`. Instead it hands the resolved `PortalSession` to
/// `ClientAuthCoordinator`, and this file picks it up and adopts it — which means the Portal a
/// Client Auth wallet is created through is byte-for-byte the one every other button on this
/// screen uses, feature-flag switches included.
///
/// Logging rule for everything below: `endUserId`, `clientId`, `exchangeUserId`, auth-method names
/// and step names are safe. The email, the redirect URL, the TOTP secret or link, the user JWT and
/// the client session token never appear in a log line, a status view or the status label.
@available(iOS 16.0, *)
extension ViewController: ClientAuthReporter {
  // MARK: - ClientAuthReporter

  /// Progress line from the adoption pipeline. Fixed literals and ids only, by contract with
  /// `SessionAdoption`.
  func log(_ line: String) {
    self.logger.info("ViewController.ClientAuth - \(line)")
  }

  /// A non-fatal adoption step failed. Surfaced on screen because the whole point of the demo is
  /// seeing which of `getClient` / `backupConfig` / `registerClient` / `wallet` went wrong.
  func reportFailure(step: String, error: Error) {
    self.logger.error("ViewController.ClientAuth - ❌ step \(step) failed: \(error)")
    self.showStatusView(message: "\(self.failureStatus) Client Auth \(step) failed: \(error.localizedDescription)")
  }

  // MARK: - Actions

  /// The storyboard's "Sign in with Portal" button. One control for both directions, because the
  /// two are mutually exclusive: `resolveAuthUiState` never offers sign-in and sign-out at once.
  @IBAction func handleClientAuth(_: UIButton) {
    guard ClientAuthCoordinator.shared.session == nil else {
      self.handleClientAuthSignOut()
      return
    }

    let config = Settings.shared.clientAuthConfig
    guard config.isConfigured else {
      // Never interpolate `config` itself — its description carries only the flags, but the
      // missing-key list is the actionable part and is safe (key *names*, never values).
      let missing = config.missingKeys.joined(separator: ", ")
      self.logger.error("ViewController.handleClientAuth() - ❌ Client Auth is not configured. Missing: \(missing)")
      self.showStatusView(message: "\(self.failureStatus) \(PortalExampleAppError.clientAuthNotConfigured().localizedDescription). Missing: \(missing)")
      return
    }

    self.presentClientAuth(initialURL: nil)
  }

  /// Presents the Client Auth screen, optionally with a redirect URL that arrived before it
  /// existed.
  ///
  /// The URL is handed to the screen rather than acted on here: only `PortalAuth.handleRedirect`
  /// can turn a grant into a session, and the screen is what owns the `PortalAuth` call and the
  /// step log that goes with it. The URL is never logged — it carries a single-use grant.
  ///
  /// Presented modally like `FirebaseAuthViewController`, and never twice: a second present on an
  /// already-presenting controller is a UIKit no-op that logs a warning, and the coordinator's
  /// `redirectSink` already routes redirects to the screen that is up.
  func presentClientAuth(initialURL: URL?) {
    guard self.presentedViewController == nil else {
      // A screen is already up; it owns `redirectSink`, so a redirect reaches it without us.
      if let initialURL {
        ClientAuthCoordinator.shared.handleIfClientAuth(initialURL)
      }
      return
    }

    let clientAuthViewController = ClientAuthViewController()
    // The same provider this screen restores and clears through, so both halves share one
    // `PortalAuth` — the replay memo and the sign-in-in-flight guard live on that instance, and a
    // second one would silently split both.
    clientAuthViewController.authProvider = PortalAuthProvider.shared
    clientAuthViewController.initialURL = initialURL

    let navigationController = UINavigationController(rootViewController: clientAuthViewController)
    self.present(navigationController, animated: true)
  }

  /// Runs from `viewDidAppear`.
  ///
  /// Deliberately a synchronous read-and-return of two read-and-clear slots (Android's `onResume`):
  /// it runs on every appearance, so it must not start I/O of its own.
  func clientAuthViewDidAppear() {
    if let session = ClientAuthCoordinator.shared.consumeHandoff() {
      self.adoptClientAuthSession(session)
    }

    // A redirect that cold-started the app with no screen up. Presenting it here is what turns a
    // launch-time deep link into a finished login.
    if let launchURL = ClientAuthCoordinator.shared.consumeLaunchURL() {
      self.presentClientAuth(initialURL: launchURL)
    }
  }

  /// Restores a persisted session on launch and adopts it.
  ///
  /// The Keychain read is preceded by a one-time clear (`clearPersistedSessionOnFirstLaunchIfNeeded`
  /// inside the coordinator) because Keychain items outlive app deletion: without it, a fresh
  /// install of the demo would silently resume the previous install's user.
  ///
  /// Every failure is swallowed and logged. "Not signed in" and "could not read storage" both mean
  /// the same thing to this screen — stay signed out — and an uncaught throw here would take the
  /// launch path with it.
  func restoreClientAuthSession() {
    let auth: PortalAuth?
    do {
      auth = try PortalAuthProvider.shared.get()
    } catch {
      self.logger.error("ViewController.restoreClientAuthSession() - ❌ Could not build PortalAuth: \(error)")
      return
    }

    // `nil` is the normal path: the four AUTH_* keys are blank in every checkout that has not
    // opted into the feature.
    guard let auth else {
      return
    }

    Task {
      await ClientAuthCoordinator.shared.restoreClientAuthSession(
        clear: {
          try await auth.clearPersistedSession()
        },
        restore: { [weak self] in
          guard let self else {
            return
          }

          let session: PortalSession?
          do {
            session = try await auth.restoreSession()
          } catch {
            self.logger.error("ViewController.restoreClientAuthSession() - ❌ Could not restore a session: \(error)")
            return
          }

          guard let session else {
            self.logger.debug("ViewController.restoreClientAuthSession() - No persisted Client Auth session")
            return
          }

          self.logger.info("ViewController.restoreClientAuthSession() - ✅ Restored session for endUserId: \(session.endUserId)")
          self.adoptClientAuthSession(session)
        }
      )
    }
  }

  // MARK: - Adoption

  /// Makes `session` this screen's credential and runs the adoption pipeline behind it.
  ///
  /// Order matters and mirrors Android: the coordinator's session is set *before* `registerPortal()`
  /// so `resolveCredentialSource` sees it and takes the `Portal(credentials:)` arm, and adoption
  /// runs against that Portal rather than one built inside the login screen.
  ///
  /// Overlapping calls (a launch-time restore and a redirect landing milliseconds apart) join one
  /// run through `AdoptionGuard`, so `createWallet()` can never be issued twice for one login.
  func adoptClientAuthSession(_ session: PortalSession) {
    let coordinator = ClientAuthCoordinator.shared
    coordinator.session = session
    self.updateClientAuthUi()

    Task {
      let portal: Portal
      do {
        portal = try await self.registerPortal()
      } catch {
        self.logger.error("ViewController.adoptClientAuthSession() - ❌ Could not register Portal: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Could not register Portal: \(error.localizedDescription)")
        return
      }

      let adoptionTask = coordinator.adoptionGuard.start(
        onBusy: { [weak self] in
          self?.log("Client Auth adoption already in flight, joining it")
        },
        task: { [weak self] () async throws -> Bool in
          guard let self else {
            return false
          }

          return await adoptSessionIntoApp(
            session: session,
            portal: RealClientAuthPortal(portal),
            getMethods: {
              guard let auth = try PortalAuthProvider.shared.get() else {
                throw PortalExampleAppError.clientAuthNotConfigured()
              }

              return try await auth.getMethods()
            },
            reporter: self,
            registerClient: { [weak self] request in
              guard let self else {
                throw PortalExampleAppError.portalNotInitialized()
              }

              return try await self.registerClientAuthClient(request)
            },
            isBuiltWithBackupWithPortal: Settings.shared.isBuiltWithBackupWithPortal,
            onAuthenticated: { [weak self] adopted in
              guard let self else {
                return
              }

              // A synthesized custodian user so every existing backup / recover / funding button on
              // this screen keeps working unchanged. `clientApiKey` is blank on purpose: the
              // session is the credential, and `resolveCredentialSource` reads a blank key as
              // absent precisely so this user can never be mistaken for a custodian login.
              self.user = UserResult(
                clientApiKey: "",
                clientId: adopted.clientId,
                exchangeUserId: adopted.exchangeUserId ?? "",
                username: adopted.session.endUserId
              )
              self.log("adopted clientId: \(adopted.clientId), exchangeUserId: \(adopted.exchangeUserId ?? "none")")

              // Addresses are deliberately not written into the screen here: they are the *device's*
              // wallet state, and `updateUIComponents()` derives them from `isWalletOnDevice()`.
              self.updateClientAuthUi()
              self.updateUIComponents()
            }
          )
        }
      )

      switch await adoptionTask.value {
      case let .success(adopted):
        if adopted {
          self.showStatusView(message: "\(self.successStatus) Client Auth session adopted")
        }
      case let .failure(error):
        self.reportFailure(step: "adoptSession", error: error)
      }
    }
  }

  // MARK: - Sign-out and invalidation

  /// Drops the in-memory session and its UI, leaving the persisted copy alone.
  ///
  /// Signing *in* is not signing out — only `handleClientAuthSignOut()` clears storage. Called
  /// before every custodian sign-in because a session outranks a user in `resolveCredentialSource`,
  /// so a restored session would otherwise win the branch and the custodian login would build a
  /// Portal for the wrong client.
  func clearClientAuthSession() {
    ClientAuthCoordinator.shared.clearInMemorySession()
    self.updateClientAuthUi()
  }

  /// The host-initiated sign-out.
  ///
  /// Both clears are needed. `Portal.clearSession()` invalidates the credential, but it does not
  /// reach `PortalAuth`'s replay memo — so without `clearPersistedSession()` a redirect delivered
  /// a second time would replay the login that was just signed out of.
  func handleClientAuthSignOut() {
    Task {
      if let portal {
        do {
          try await portal.clearSession()
        } catch {
          self.logger.error("ViewController.handleClientAuthSignOut() - ❌ Could not clear the session: \(error)")
        }
      }

      await self.clearPersistedClientAuthSession()

      self.clearClientAuthSession()
      self.signOutLocally()
      self.showStatusView(message: "\(self.successStatus) Client Auth session cleared")
    }
  }

  /// The backend rejected the credential: local cleanup only.
  ///
  /// No `portal.clearSession()` here, unlike the sign-out button — the session is already dead and
  /// invalidated by the SDK, and calling it again would be a second invalidation of a spent
  /// credential. `clearPersistedSession()` still runs so the replay memo cannot serve the dead
  /// session back on the next redirect.
  func handleSessionInvalidated() {
    self.logger.warning("ViewController.handleSessionInvalidated() - The backend rejected the Client Auth session")

    Task {
      await self.clearPersistedClientAuthSession()

      self.clearClientAuthSession()
      self.signOutLocally()
      self.showStatusView(message: "\(self.failureStatus) Session invalidated - signed out")
    }
  }

  /// Shared by the sign-out button and the invalidation listener. Failures are logged, never
  /// rethrown: a stale Keychain copy must not stop the screen returning to its signed-out state.
  private func clearPersistedClientAuthSession() async {
    do {
      guard let auth = try PortalAuthProvider.shared.get() else {
        return
      }

      try await auth.clearPersistedSession()
    } catch {
      self.logger.error("ViewController.clearPersistedClientAuthSession() - ❌ Could not clear persisted session: \(error)")
    }
  }

  // MARK: - UI

  /// The only writer of the two Client Auth controls.
  ///
  /// Derived from `resolveAuthUiState`, the same function `updateUIComponents()` uses for the
  /// custodian controls, so what the screen offers and what `registerPortal()` builds from can
  /// never disagree.
  func updateClientAuthUi() {
    let config = Settings.shared.clientAuthConfig
    let session = ClientAuthCoordinator.shared.session
    let state = resolveAuthUiState(clientAuthSession: session, user: self.user)

    let title: String
    let isEnabled: Bool
    let status: String

    if !config.isConfigured {
      title = "Sign in with Portal (not configured)"
      isEnabled = false
      status = "Client Auth: not configured (missing \(config.missingKeys.joined(separator: ", ")))"
    } else if let session {
      title = "Sign out of Portal"
      isEnabled = state.canSignOutClientAuth
      let exchangeUserId = self.user?.exchangeUserId ?? ""
      status = exchangeUserId.isEmpty
        ? "Credential: Client Auth session (endUserId: \(session.endUserId))"
        : "Credential: Client Auth session (endUserId: \(session.endUserId), exchangeUserId: \(exchangeUserId))"
    } else {
      title = "Sign in with Portal"
      isEnabled = state.canSignInWithClientAuth
      if let user, !user.clientApiKey.isEmpty {
        status = "Credential: Client API Key (clientId: \(user.clientId))"
      } else {
        status = "Credential: none (signed out)"
      }
    }

    DispatchQueue.main.async {
      self.clientAuthButton.isEnabled = isEnabled
      if var configuration = self.clientAuthButton.configuration {
        // A storyboard button carrying a `buttonConfiguration` ignores `setTitle(_:for:)`.
        configuration.title = title
        self.clientAuthButton.configuration = configuration
      } else {
        self.clientAuthButton.setTitle(title, for: .normal)
      }
      self.clientAuthStatusLabel.text = status
    }
  }

  // MARK: - Custodian registration

  /// Registers a Client Auth client with the PortalEx custodian so it gets a self-managed backup
  /// store — the same one `/mobile/signup` creates for a custodian-issued client.
  ///
  /// Without it a session that authenticated through Portal has no `exchangeUserId`, and every
  /// backup, recover and funding button on this screen has nowhere to read or write. Idempotent per
  /// `clientId`, so a resumed session can re-register safely.
  func registerClientAuthClient(_ request: ClientRegistrationRequest) async throws -> ClientRegistrationResult {
    guard let config else {
      throw PortalExampleAppError.configurationNotSet()
    }
    guard let url = URL(string: "\(config.custodianServerUrl)/clients/register") else {
      throw URLError(.badURL)
    }

    self.logger.info("ViewController.registerClientAuthClient() - Registering clientId: \(request.clientId)")

    let apiRequest = PortalAPIRequest.custodian(url: url, method: .post, payload: request)
    let response = try await self.requests.execute(request: apiRequest, mappingInResponse: ClientRegistrationResponse.self)

    return ClientRegistrationResult(exchangeUserId: response.exchangeUserId)
  }
}

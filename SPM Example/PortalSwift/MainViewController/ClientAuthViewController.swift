//
//  ClientAuthViewController.swift
//  SPM Example
//
//  Drives Portal's Client Auth flow (magic link, Google/Apple, TOTP) and hands the resolved
//  session back to `ViewController` through `ClientAuthCoordinator`.
//

import os.log
import PortalSwift
import UIKit

/// Portal's Client Auth demo surface: sign in, and nothing else.
///
/// The screen owns authentication only. It builds no `Portal` and touches no custodian —
/// session adoption (the authenticated call, custodian registration and wallet resolution)
/// runs in `ViewController`, against the one `Portal` `registerPortal()` builds with the
/// feature-flag switches applied. Mirrors Android's `ClientAuthActivity`.
///
/// Nothing here logs the email, the redirect URL, the `totpLink`, the TOTP secret, the
/// pending userJwt or the resolved session token: the step log carries step names, fixed
/// literals and the (non-secret) `endUserId`.
@available(iOS 16.0, *)
final class ClientAuthViewController: UIViewController {
  // MARK: - Injection

  /// The provider that hands out the screen's `PortalAuth`.
  ///
  /// Set by the presenter so the whole app shares one `PortalAuth` instance — the SDK's replay
  /// memo and its single-sign-in-in-flight guard live on that instance, so a second one would
  /// silently split both. Falls back to a locally built provider when the presenter sets none,
  /// which keeps the screen runnable on its own.
  var authProvider: PortalAuthProvider?

  /// A redirect that arrived before this screen existed (cold start through the URL handler).
  /// Consumed exactly once, in `viewDidAppear`.
  var initialURL: URL?

  // MARK: - State

  private let logger = Logger()

  private var auth: PortalAuth?

  /// What `getMethods()` last reported, or `nil` when it has not been called. Screen-scoped:
  /// with no answer yet both provider buttons stay optimistically enabled, which costs a tap
  /// to correct and never blocks a login the environment does allow.
  private var allowedAuthMethods: [AuthMethod]?

  private var isOAuthRequestInFlight = false
  private var isSendingMagicLink = false

  /// Seconds left on the send cooldown; `0` means the button is live again.
  private var magicLinkCooldownRemaining = 0
  private var magicLinkCooldownTimer: Timer?

  private var logLines: [String] = []

  /// Fixed cooldown after a successful send and after a `rateLimited` rejection. Every send
  /// delivers a real email and the backend rate limits per address, so the app never resends
  /// on its own — this only stops a user from hammering the button into a 429.
  private static let magicLinkCooldownSeconds = 30

  /// How long a copied TOTP value stays on the pasteboard.
  private static let pasteboardExpirySeconds: TimeInterval = 60

  private var config: ClientAuthConfig {
    Settings.shared.clientAuthConfig
  }

  /// The JWT of a login waiting on a code. Held on the coordinator, not here: the redirect that
  /// produced it may be re-delivered to a different screen instance, and a pasted callback URL
  /// is gone with this view controller.
  private var pendingUserJwt: String? {
    get { ClientAuthCoordinator.shared.pendingTotpUserJwt }
    set { ClientAuthCoordinator.shared.pendingTotpUserJwt = newValue }
  }

  private lazy var resolvedAuthProvider: PortalAuthProvider = self.authProvider ?? ClientAuthViewController.makeDefaultAuthProvider()

  // MARK: - Views

  private let scrollView = UIScrollView()
  private let stack = UIStackView()

  private let notConfiguredLabel = UILabel()
  private let statusLabel = UILabel()
  private let emailField = UITextField()
  private let sendMagicLinkButton = UIButton(type: .system)
  private let getMethodsButton = UIButton(type: .system)

  private let externalBrowserSwitch = UISwitch()
  private let googleButton = UIButton(type: .system)
  private let appleButton = UIButton(type: .system)

  private let pastedRedirectField = UITextField()
  private let handleRedirectButton = UIButton(type: .system)

  private let totpHintLabel = UILabel()
  private let totpSecretField = UITextField()
  private let copyTotpSecretButton = UIButton(type: .system)
  private let copyTotpLinkButton = UIButton(type: .system)
  private let generateTotpCodeButton = UIButton(type: .system)
  private let showTotpQrButton = UIButton(type: .system)
  private let totpCodeField = UITextField()
  private let verifyTotpButton = UIButton(type: .system)

  private let doneButton = UIButton(type: .system)
  private let resultLabel = UILabel()
  private let logLabel = UILabel()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .systemBackground
    self.title = "Client Auth"

    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(self.handleDone)
    )

    self.setupUI()
    self.resolveAuth()

    if self.auth == nil {
      self.showNotConfigured()
    } else if !self.config.isMagicLinkConfigured {
      self.append("• magic link not configured — missing \(self.config.missingKeys.joined(separator: ", "))")
    }

    // A redirect can rebuild this screen while a login is mid-TOTP; the pending JWT outlives the
    // view controller so the step resumes rather than dead-ending on a spent grant.
    if self.pendingUserJwt != nil {
      self.append("• resumed a login still awaiting a TOTP code")
      self.statusLabel.text = "Awaiting TOTP code"
    }

    self.updateMagicLinkButton()
    self.applyTotpUiState()
    self.applyOAuthUiState()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // While this screen is on top it is where redirects belong: the coordinator forwards
    // instead of stashing, and the presenter can find the screen to hand a URL to.
    ClientAuthCoordinator.shared.activeScreen = self
    ClientAuthCoordinator.shared.redirectSink = { [weak self] url in
      self?.completeRedirect(url)
    }

    if let initialURL = self.initialURL {
      self.initialURL = nil
      self.completeRedirect(initialURL)
    }

    // A URL that landed before any sink was installed (cold start, or the screen was closed).
    if let stashed = ClientAuthCoordinator.shared.consumeLaunchURL() {
      self.completeRedirect(stashed)
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Only tear down our own registration: a screen being replaced must not unhook its successor.
    if ClientAuthCoordinator.shared.activeScreen === self {
      ClientAuthCoordinator.shared.activeScreen = nil
      ClientAuthCoordinator.shared.redirectSink = nil
    }
  }

  deinit {
    self.magicLinkCooldownTimer?.invalidate()
  }

  // MARK: - PortalAuth

  /// The provider used when the presenter supplies none. Reads `Settings.shared` lazily on every
  /// call so an environment switch is picked up, and never reads `Settings.shared.isAccountAbstracted`
  /// after construction — `updateUIComponents()` rewrites that from the live client, and a rebuild
  /// there would discard the replay memo mid-login.
  private static func makeDefaultAuthProvider() -> PortalAuthProvider {
    PortalAuthProvider(
      config: { Settings.shared.clientAuthConfig },
      apiHost: { Settings.shared.portalConfig.environment.portalApiHost },
      pendingTotpUserJwt: { ClientAuthCoordinator.shared.pendingTotpUserJwt }
    )
  }

  /// Resolves the screen's `PortalAuth` once. `nil` means Client Auth is not configured (or the
  /// instance could not be built), which the banner explains.
  private func resolveAuth() {
    do {
      self.auth = try self.resolvedAuthProvider.get()
    } catch {
      self.auth = nil
      self.reportFailure(step: "portalAuth", error: error)
    }
  }

  // MARK: - UI state

  private func showNotConfigured() {
    let missingKeys = self.config.missingKeys
    self.notConfiguredLabel.text = missingKeys.isEmpty
      ? "Client Auth is unavailable. See the step log below."
      : "Client Auth is not configured. Add these to Secrets.xcconfig: " + missingKeys.joined(separator: ", ")
    self.notConfiguredLabel.isHidden = false
    self.setEnabled(self.getMethodsButton, false)
    self.setEnabled(self.handleRedirectButton, false)
    self.pastedRedirectField.isEnabled = false
    self.emailField.isEnabled = false
  }

  /// Pushes `resolveTotpUiState` onto the views: the single place any TOTP control's enabled
  /// state is written, so what the screen offers cannot drift from what the resolved state says.
  private func applyTotpUiState() {
    let state = resolveTotpUiState(
      pendingUserJwt: self.pendingUserJwt,
      secretOrLink: self.totpSecretField.text ?? "",
      code: self.totpCodeField.text ?? ""
    )

    self.totpSecretField.isEnabled = state.isSectionEnabled
    self.totpCodeField.isEnabled = state.isSectionEnabled
    self.setEnabled(self.copyTotpSecretButton, state.canCopySecret)
    self.setEnabled(self.copyTotpLinkButton, state.canCopyLink)
    self.setEnabled(self.generateTotpCodeButton, state.canDeriveCode)
    self.setEnabled(self.showTotpQrButton, state.canShowQr)
    self.setEnabled(self.verifyTotpButton, state.canSubmitCode && self.auth != nil)
  }

  /// Pushes `resolveOAuthUiState` onto the views: the single place either provider button's
  /// enabled state is written. Both go dark while one request is in flight — the `state` in an
  /// authorize URL is single use and shared across providers, so resolving the other one now
  /// would invalidate the URL this call is about to open.
  private func applyOAuthUiState() {
    let state = resolveOAuthUiState(
      isConfigured: self.auth != nil && self.config.isConfigured,
      allowedAuthMethods: self.allowedAuthMethods,
      isRequestInFlight: self.isOAuthRequestInFlight
    )

    self.setEnabled(self.googleButton, state.canSignInWithGoogle)
    self.setEnabled(self.appleButton, state.canSignInWithApple)
  }

  private func updateMagicLinkButton() {
    let isCoolingDown = self.magicLinkCooldownRemaining > 0
    let title = isCoolingDown ? "Send Magic Link (\(self.magicLinkCooldownRemaining)s)" : "Send Magic Link"
    self.sendMagicLinkButton.setTitle(title, for: .normal)
    self.setEnabled(
      self.sendMagicLinkButton,
      self.auth != nil && self.config.isMagicLinkConfigured && !self.isSendingMagicLink && !isCoolingDown
    )
  }

  private func setEnabled(_ button: UIButton, _ isEnabled: Bool) {
    button.isEnabled = isEnabled
    button.alpha = isEnabled ? 1.0 : 0.5
  }

  // MARK: - Actions: auth methods

  @objc private func handleGetMethods() {
    guard let auth = self.auth else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let methods = try await auth.getMethods()
        self.allowedAuthMethods = methods.allowedAuthMethods
        let names = methods.allowedAuthMethods.map(\.rawValue).joined(separator: ", ")
        self.append("✓ getMethods — [\(names)], autoCreateWallet=\(methods.autoCreateWallet)")

        // Said out loud per provider: a button going dark on its own reads as a bug.
        for method in [AuthMethod.google, AuthMethod.apple] where !methods.allowedAuthMethods.contains(method) {
          self.append("• \(method.rawValue) is not enabled for this auth environment — button disabled")
        }

        self.applyOAuthUiState()
        self.showResult("Auth methods loaded", success: true)
      } catch {
        self.reportFailure(step: "getMethods", error: error)
      }
    }
  }

  // MARK: - Actions: magic link

  /// Sends the email and nothing more — the login result arrives later as a deep link.
  ///
  /// Never retried automatically: every call delivers a real email and sends are rate limited,
  /// so a resend is an explicit tap, and the button sits out a fixed cooldown afterwards.
  @objc private func handleSendMagicLink() {
    guard let auth = self.auth else { return }
    let email = (self.emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !email.isEmpty else {
      self.showResult("Enter an email first", success: false)
      return
    }

    self.isSendingMagicLink = true
    self.updateMagicLinkButton()

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await auth.sendMagicLink(email)
        self.isSendingMagicLink = false
        self.append("✓ sendMagicLink — email sent")
        self.append("• open the link on this device to continue")
        self.showResult("Magic link sent", success: true)
        self.startMagicLinkCooldown()
      } catch {
        self.isSendingMagicLink = false
        self.reportFailure(step: "sendMagicLink", error: error)
        if let authError = error as? PortalAuthError, authError == .rateLimited {
          // The backend sends no Retry-After, so the app picks its own quiet period.
          self.append("• rate limited — waiting \(ClientAuthViewController.magicLinkCooldownSeconds)s before another send")
          self.startMagicLinkCooldown()
        } else {
          self.updateMagicLinkButton()
        }
      }
    }
  }

  private func startMagicLinkCooldown() {
    self.magicLinkCooldownTimer?.invalidate()
    self.magicLinkCooldownRemaining = ClientAuthViewController.magicLinkCooldownSeconds
    self.updateMagicLinkButton()

    self.magicLinkCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }
      self.magicLinkCooldownRemaining -= 1
      if self.magicLinkCooldownRemaining <= 0 {
        self.magicLinkCooldownRemaining = 0
        timer.invalidate()
        self.magicLinkCooldownTimer = nil
      }
      self.updateMagicLinkButton()
    }
  }

  // MARK: - Actions: OAuth

  @objc private func handleGoogleLogin() {
    self.handleOAuthLogin(.google)
  }

  @objc private func handleAppleLogin() {
    self.handleOAuthLogin(.apple)
  }

  /// Runs one of the two OAuth paths.
  ///
  /// Default (switch off) is `signInWith*`: the SDK owns an `ASWebAuthenticationSession`, matches
  /// the callback inside that session and completes the login without the URL ever passing
  /// through the OS URL handler — the only path a same-scheme app on the device cannot hijack.
  ///
  /// Switch on is the URL-only path every SDK shares: `loginWith*` resolves the authorize URL,
  /// the app opens it in the external browser, and the redirect returns through the OS handler →
  /// `ClientAuthCoordinator` → `completeRedirect(_:)`. Nothing here waits for it, which is why
  /// that flow survives the app being backgrounded or killed while the browser is open.
  private func handleOAuthLogin(_ method: AuthMethod) {
    guard let auth = self.auth else { return }
    let usesExternalBrowser = self.externalBrowserSwitch.isOn
    let step = (usesExternalBrowser ? "loginWith" : "signInWith") + ClientAuthViewController.providerLabel(method)

    self.isOAuthRequestInFlight = true
    self.applyOAuthUiState()

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        if usesExternalBrowser {
          // Two arms differing only in the call, so the branch is verifiable by reading it.
          let result = method == .apple ? try await auth.loginWithApple() : try await auth.loginWithGoogle()
          self.append("✓ \(step) — authorize URL resolved")
          self.openAuthorizeUrl(result.authorizeUrl, step: step)
        } else {
          guard let window = self.view.window else {
            self.append("✗ \(step) — no window to present the sign-in sheet from")
            self.showResult("\(step) failed", success: false)
            self.isOAuthRequestInFlight = false
            self.applyOAuthUiState()
            return
          }
          auth.setAuthPresentationAnchor(window)
          let result = method == .apple ? try await auth.signInWithApple() : try await auth.signInWithGoogle()
          self.append("✓ \(step) — sign-in sheet completed")
          self.handle(authResult: result)
        }
      } catch {
        self.reportFailure(step: step, error: error)
      }
      self.isOAuthRequestInFlight = false
      self.applyOAuthUiState()
    }
  }

  /// Hands the authorize URL to whatever browser the device has.
  ///
  /// The scheme is checked first: this URL comes off the network, and opening an arbitrary scheme
  /// hands control to whichever app claims it.
  private func openAuthorizeUrl(_ authorizeUrl: String, step: String) {
    guard let url = URL(string: authorizeUrl),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https"
    else {
      self.append("✗ \(step) — refusing to open a non-http(s) authorize URL")
      self.showResult("Unexpected authorize URL", success: false)
      return
    }

    UIApplication.shared.open(url, options: [:]) { [weak self] didOpen in
      guard let self else { return }
      if didOpen {
        self.append("• opened the browser — complete the sign-in and the redirect returns here")
        self.showResult("Opened the browser", success: true)
      } else {
        self.append("• no browser on this device can open the authorize URL")
        self.showResult("\(step) failed", success: false)
      }
    }
  }

  // MARK: - Actions: redirect

  @objc private func handleRedirectTapped() {
    let raw = (self.pastedRedirectField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else {
      self.showResult("Paste the callback URL first", success: false)
      return
    }
    self.completeRedirect(raw)
  }

  /// Completes a redirect delivered by the OS URL handler (through `ClientAuthCoordinator`).
  func completeRedirect(_ url: URL) {
    // `absoluteString` keeps the percent-encoding intact so the grant is decoded exactly once.
    self.completeRedirect(url.absoluteString)
  }

  /// No app-level replay guard: `PortalAuth` remembers the grant it last exchanged and replays the
  /// result, which is why the whole app shares one instance. A re-delivered single-use grant would
  /// otherwise read on screen as an auth failure on top of a login that already succeeded.
  private func completeRedirect(_ rawUrl: String) {
    guard let auth = self.auth else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        switch try await auth.handleRedirect(rawUrl) {
        // Not ours — no token, wrong redirect target, or no recognizable auth-method marker.
        // Never an error: the app's router may have other handlers to try.
        case .none:
          self.append("• handleRedirect — ignored, not a Client Auth redirect")
        case let .some(result):
          self.handle(authResult: result)
        }
      } catch {
        self.reportFailure(step: "handleRedirect", error: error)
      }
    }
  }

  private func handle(authResult: AuthResult) {
    switch authResult {
    case let .authenticated(result):
      self.publish(result.session)
    case let .totpRequired(result):
      self.promptForTotp(result)
    }
  }

  // MARK: - TOTP

  /// Moves the screen into the TOTP step. Nothing has been persisted at this point — the login is
  /// not complete until `handleVerifyTotp` resolves a session.
  private func promptForTotp(_ result: TotpRequiredResult) {
    self.pendingUserJwt = result.userJwt

    if let totpLink = result.totpLink {
      // First-time enrollment. Seeded into an editable field rather than shown read-only so the
      // same control serves the already-enrolled case below. Never logged: it embeds the secret.
      self.totpSecretField.text = totpLink
      self.append("• TOTP enrollment required — add the secret to an authenticator, or Generate")
    } else {
      // Already enrolled: the backend sends the secret exactly once, so there is nothing to show.
      self.append("• TOTP required — already enrolled")
      self.append("• enter a code from your authenticator, or paste the secret you saved at enrollment")
    }

    self.statusLabel.text = "Awaiting TOTP code"
    self.showResult("TOTP required", success: true)
    self.applyTotpUiState()
  }

  /// Derives a code from the secret in the field.
  ///
  /// TEST AFFORDANCE ONLY: holding both factors on one device is exactly what TOTP exists to
  /// prevent. It is here so the flow is demoable without provisioning an authenticator per test
  /// account; a real app collects the code from the user.
  @objc private func handleGenerateTotpCode() {
    do {
      let derived = try generateTotpCode(self.totpSecretField.text ?? "")
      self.totpCodeField.text = derived.code
      self.append("✓ generated TOTP code — valid for \(derived.secondsRemaining)s")
      self.applyTotpUiState()
    } catch {
      self.reportFailure(step: "generateTotpCode", error: error)
    }
  }

  /// Puts the bare base32 secret on the pasteboard.
  ///
  /// This is the one an authenticator app can actually accept by paste: a manual "setup key" field
  /// takes the secret alone and rejects a full `otpauth://` URI.
  ///
  /// TEST AFFORDANCE ONLY — see `copyToPasteboard(_:)`.
  @objc private func handleCopyTotpSecret() {
    guard let secret = extractTotpSecret(self.totpSecretField.text ?? "") else {
      self.showResult("No base32 secret in that value", success: false)
      return
    }

    self.copyToPasteboard(secret)
    self.append("• copied the TOTP secret (\(secret.count) base32 chars)")
    self.showResult("Copied to clipboard", success: true)
  }

  /// Puts the whole enrollment URI on the pasteboard, for an authenticator that accepts URIs
  /// directly or for moving the link off the device — not for a manual setup field.
  ///
  /// TEST AFFORDANCE ONLY — see `copyToPasteboard(_:)`.
  @objc private func handleCopyTotpLink() {
    self.copyToPasteboard(self.totpSecretField.text ?? "")
    self.append("• copied the TOTP setup link")
    self.showResult("Copied to clipboard", success: true)
  }

  /// Writes a live 2FA value to the pasteboard.
  ///
  /// TEST AFFORDANCE ONLY: a shared TOTP secret on the system pasteboard is readable by every app
  /// in the foreground. `localOnly` keeps it off Universal Clipboard (so it never reaches the
  /// user's other devices) and `expirationDate` bounds how long it can be read at all. Acceptable
  /// in a demo app whose whole purpose is manual testing; not something to copy into a custodian
  /// integration.
  private func copyToPasteboard(_ value: String) {
    // `typeListString` bridges as an untyped `NSArray`; its first entry is the plain-text UTI,
    // and the literal below is that same UTI for the (unreachable) empty-list case.
    let stringType = (UIPasteboard.typeListString.firstObject as? String) ?? "public.utf8-plain-text"
    UIPasteboard.general.setItems(
      [[stringType: value]],
      options: [
        .localOnly: true,
        .expirationDate: Date().addingTimeInterval(ClientAuthViewController.pasteboardExpirySeconds)
      ]
    )
  }

  /// Shows the enrollment link as a QR for an authenticator to scan.
  ///
  /// What gets encoded is `scannableTotpPayload`'s answer, not the field's raw text — the two
  /// differ only for a link pasted percent-encoded, where the decoded form is the one an
  /// authenticator can read. Nothing is rebuilt around a bare secret: the URI carries the issuer
  /// and account label a scan sets up, and a QR of a naked secret is rejected by every
  /// authenticator that scans it. The image itself comes from the SDK.
  @objc private func handleShowTotpQr() {
    // The payload comes from the same function that enabled the button, so what is encoded is
    // always what the gate approved. The guard is cheap insurance if that ever stops holding.
    let raw = self.totpSecretField.text ?? ""
    guard let payload = scannableTotpPayload(raw), let secret = extractTotpSecret(payload) else {
      self.showResult("Not a full otpauth:// link", success: false)
      return
    }

    do {
      let image = try portalTotpQrCodeImage(otpAuthUrl: payload)
      self.presentTotpQrSheet(image: image, secret: secret)
      self.append("• showing the enrollment QR — scan it, or use Copy Secret to type it in")
    } catch {
      self.reportFailure(step: "showTotpQr", error: error)
    }
  }

  /// Presents the SDK-rendered QR.
  ///
  /// The image view sits on pure white, deliberately not the theme's colours: a scanner relies on
  /// the contrast the QR specification assumes, and in dark mode a themed surface bleeds into the
  /// quiet zone and produces a code that looks plausible on screen and simply will not read.
  private func presentTotpQrSheet(image: UIImage, secret: String) {
    let sheet = UIViewController()
    sheet.view.backgroundColor = .systemBackground
    sheet.title = "Scan with your authenticator"

    let content = UIStackView()
    content.axis = .vertical
    content.alignment = .center
    content.spacing = 8
    content.translatesAutoresizingMaskIntoConstraints = false
    sheet.view.addSubview(content)

    let imageView = UIImageView(image: image)
    imageView.backgroundColor = .white
    imageView.contentMode = .scaleAspectFit
    imageView.layer.magnificationFilter = .nearest
    imageView.accessibilityLabel = "TOTP enrollment QR code"
    imageView.translatesAutoresizingMaskIntoConstraints = false
    content.addArrangedSubview(imageView)

    let caption = UILabel()
    caption.text = "Cannot scan? Enter this key"
    caption.font = .systemFont(ofSize: 12)
    caption.textColor = .secondaryLabel
    content.setCustomSpacing(16, after: imageView)
    content.addArrangedSubview(caption)

    let secretLabel = UILabel()
    secretLabel.text = formatTotpSecret(secret)
    secretLabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
    secretLabel.textAlignment = .center
    secretLabel.numberOfLines = 0
    content.addArrangedSubview(secretLabel)

    let closeButton = UIButton(type: .system)
    closeButton.setTitle("Close", for: .normal)
    closeButton.addTarget(self, action: #selector(self.dismissPresentedSheet), for: .touchUpInside)
    content.setCustomSpacing(24, after: secretLabel)
    content.addArrangedSubview(closeButton)

    NSLayoutConstraint.activate([
      content.centerYAnchor.constraint(equalTo: sheet.view.centerYAnchor),
      content.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor, constant: 20),
      content.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor, constant: -20),
      imageView.widthAnchor.constraint(equalToConstant: 240),
      imageView.heightAnchor.constraint(equalToConstant: 240)
    ])

    if let presentation = sheet.sheetPresentationController {
      presentation.detents = [.medium(), .large()]
      presentation.prefersGrabberVisible = true
    }
    self.present(sheet, animated: true)
  }

  @objc private func dismissPresentedSheet() {
    self.presentedViewController?.dismiss(animated: true)
  }

  /// Submits the code against the pending JWT.
  ///
  /// A wrong code does not consume the JWT, so the section stays live for another attempt. An
  /// expired one restarts the login — there is no refresh path.
  @objc private func handleVerifyTotp() {
    guard let auth = self.auth, let userJwt = self.pendingUserJwt else { return }
    let code = (self.totpCodeField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    self.setEnabled(self.verifyTotpButton, false)

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let result = try await auth.verifyTotp(code, userJwt: userJwt)
        self.append("✓ verifyTotp — code accepted")
        self.publish(result.session)
      } catch {
        self.reportFailure(step: "verifyTotp", error: error)
        self.append("• the JWT is still valid — try another code")
      }
      // Re-resolved rather than set true: a successful verify clears the JWT, which disables the
      // whole section, and this must not contradict that.
      self.applyTotpUiState()
    }
  }

  // MARK: - Handoff

  /// Hands the session to the app. Deliberately does not dismiss: the step log is the point of
  /// this screen, so the user reads it and taps Back to app.
  private func publish(_ session: PortalSession) {
    ClientAuthCoordinator.shared.setHandoff(session)

    // The JWT was scoped to submitting a code and the login is now complete, so it is dead weight —
    // and leaving it set would re-enable the TOTP section on the next redirect replay.
    self.pendingUserJwt = nil
    self.applyTotpUiState()

    self.append("✓ session resolved — endUserId=\(session.endUserId)")
    self.append("• tap 'Back to app' to register Portal with this session")
    self.statusLabel.text = "Signed in: \(session.endUserId)"
    self.showResult("Authenticated", success: true)
  }

  @objc private func handleDone() {
    self.dismiss(animated: true)
  }

  // MARK: - Logging

  private func reportFailure(step: String, error: Error) {
    // Step name only at `.public`; the message stays private, so nothing a server or a transport
    // put in it can reach the persistent unified log.
    self.logger.error("ClientAuth.\(step, privacy: .public) - ❌ \(error.localizedDescription)")
    self.append("✗ \(step) — \(error.localizedDescription)")
    self.showResult("\(step) failed", success: false)
  }

  private func append(_ line: String) {
    self.logLines.append(line)
    self.logLabel.text = self.logLines.joined(separator: "\n")
  }

  private func showResult(_ message: String, success: Bool) {
    self.resultLabel.text = (success ? "✅ " : "❌ ") + message
    self.resultLabel.textColor = success ? .systemGreen : .systemRed
  }

  private static func providerLabel(_ method: AuthMethod) -> String {
    switch method {
    case .google:
      return "Google"
    case .apple:
      return "Apple"
    case .emailMagicLink:
      return "MagicLink"
    }
  }

  // MARK: - UI setup

  private func setupUI() {
    self.scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.scrollView.keyboardDismissMode = .interactive
    self.view.addSubview(self.scrollView)
    NSLayoutConstraint.activate([
      self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
      self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
    ])

    self.stack.axis = .vertical
    self.stack.spacing = 12
    self.stack.translatesAutoresizingMaskIntoConstraints = false
    self.scrollView.addSubview(self.stack)
    NSLayoutConstraint.activate([
      self.stack.topAnchor.constraint(equalTo: self.scrollView.topAnchor, constant: 20),
      self.stack.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
      self.stack.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
      self.stack.bottomAnchor.constraint(equalTo: self.scrollView.bottomAnchor, constant: -20)
    ])

    self.setupSignInSection()
    self.setupSocialSection()
    self.setupRedirectSection()
    self.setupTotpSection()
    self.setupResultSection()
  }

  private func setupSignInSection() {
    self.stack.addArrangedSubview(self.makeSectionHeader("Sign in with Portal"))

    self.notConfiguredLabel.text = ""
    self.notConfiguredLabel.font = .systemFont(ofSize: 13)
    self.notConfiguredLabel.textColor = .systemOrange
    self.notConfiguredLabel.numberOfLines = 0
    self.notConfiguredLabel.isHidden = true
    self.notConfiguredLabel.accessibilityIdentifier = "clientAuthNotConfiguredLabel"
    self.stack.addArrangedSubview(self.notConfiguredLabel)

    self.statusLabel.text = "Not authenticated"
    self.statusLabel.font = .systemFont(ofSize: 14)
    self.statusLabel.textColor = .secondaryLabel
    self.statusLabel.numberOfLines = 0
    self.statusLabel.accessibilityIdentifier = "clientAuthStatusLabel"
    self.stack.addArrangedSubview(self.statusLabel)

    self.emailField.placeholder = "Email"
    self.emailField.borderStyle = .roundedRect
    self.emailField.autocapitalizationType = .none
    self.emailField.autocorrectionType = .no
    self.emailField.keyboardType = .emailAddress
    self.emailField.textContentType = .emailAddress
    self.emailField.accessibilityIdentifier = "clientAuthEmailField"
    self.stack.addArrangedSubview(self.emailField)

    self.configureButton(self.sendMagicLinkButton, title: "Send Magic Link", color: .systemBlue, action: #selector(self.handleSendMagicLink))
    self.sendMagicLinkButton.accessibilityIdentifier = "clientAuthSendMagicLinkButton"
    self.stack.addArrangedSubview(self.sendMagicLinkButton)

    self.configureButton(self.getMethodsButton, title: "Get Auth Methods", color: .systemGray, action: #selector(self.handleGetMethods))
    self.getMethodsButton.accessibilityIdentifier = "clientAuthGetMethodsButton"
    self.stack.addArrangedSubview(self.getMethodsButton)

    self.stack.addArrangedSubview(self.makeSeparator())
  }

  private func setupSocialSection() {
    self.stack.addArrangedSubview(self.makeSectionHeader("Social sign-in"))

    let hint = UILabel()
    hint.text = "By default the SDK owns the sign-in sheet and the callback never leaves it. "
      + "Switch on the external browser to use the URL-only path instead: the redirect returns to "
      + "this screen through the same deep link a magic link uses. Tap Get Auth Methods first to "
      + "see whether this environment allows a provider."
    hint.font = .systemFont(ofSize: 12)
    hint.textColor = .secondaryLabel
    hint.numberOfLines = 0
    self.stack.addArrangedSubview(hint)

    let switchRow = UIStackView()
    switchRow.axis = .horizontal
    switchRow.spacing = 12
    switchRow.alignment = .center

    let switchLabel = UILabel()
    switchLabel.text = "Use external browser (URL-only path)"
    switchLabel.font = .systemFont(ofSize: 14)
    switchLabel.numberOfLines = 0
    switchRow.addArrangedSubview(switchLabel)

    self.externalBrowserSwitch.isOn = false
    self.externalBrowserSwitch.setContentHuggingPriority(.required, for: .horizontal)
    self.externalBrowserSwitch.accessibilityIdentifier = "clientAuthExternalBrowserSwitch"
    switchRow.addArrangedSubview(self.externalBrowserSwitch)

    self.stack.addArrangedSubview(switchRow)

    self.configureButton(self.googleButton, title: "Sign in with Google", color: .systemIndigo, action: #selector(self.handleGoogleLogin))
    self.googleButton.accessibilityIdentifier = "clientAuthGoogleButton"
    self.stack.addArrangedSubview(self.googleButton)

    // Sign in with Apple is the host's own control here — Portal delivers it as a web authorize
    // URL, not through AuthenticationServices — so the button follows the Human Interface
    // Guidelines: black fill, the Apple logo, and the exact "Sign in with Apple" wording.
    var appleTitleAttributes = AttributeContainer()
    appleTitleAttributes.font = UIFont.boldSystemFont(ofSize: 16)

    var appleConfiguration = UIButton.Configuration.filled()
    appleConfiguration.attributedTitle = AttributedString("Sign in with Apple", attributes: appleTitleAttributes)
    appleConfiguration.image = UIImage(systemName: "apple.logo")
    appleConfiguration.imagePadding = 8
    appleConfiguration.baseBackgroundColor = .black
    appleConfiguration.baseForegroundColor = .white
    appleConfiguration.background.cornerRadius = 8
    self.appleButton.configuration = appleConfiguration
    self.appleButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    self.appleButton.addTarget(self, action: #selector(self.handleAppleLogin), for: .touchUpInside)
    self.appleButton.accessibilityIdentifier = "clientAuthAppleButton"
    self.stack.addArrangedSubview(self.appleButton)

    self.stack.addArrangedSubview(self.makeSeparator())
  }

  private func setupRedirectSection() {
    self.stack.addArrangedSubview(self.makeSectionHeader("Paste the callback URL"))

    let hint = UILabel()
    hint.text = "A fallback for a redirect the OS could not deliver — paste it here to finish the login."
    hint.font = .systemFont(ofSize: 12)
    hint.textColor = .secondaryLabel
    hint.numberOfLines = 0
    self.stack.addArrangedSubview(hint)

    self.pastedRedirectField.placeholder = "portalswiftexample://auth/callback?token=…"
    self.pastedRedirectField.borderStyle = .roundedRect
    self.pastedRedirectField.autocapitalizationType = .none
    self.pastedRedirectField.autocorrectionType = .no
    self.pastedRedirectField.keyboardType = .URL
    self.pastedRedirectField.accessibilityIdentifier = "clientAuthPastedRedirectField"
    self.stack.addArrangedSubview(self.pastedRedirectField)

    self.configureButton(self.handleRedirectButton, title: "Handle Redirect", color: .systemTeal, action: #selector(self.handleRedirectTapped))
    self.handleRedirectButton.accessibilityIdentifier = "clientAuthHandleRedirectButton"
    self.stack.addArrangedSubview(self.handleRedirectButton)

    self.stack.addArrangedSubview(self.makeSeparator())
  }

  private func setupTotpSection() {
    self.stack.addArrangedSubview(self.makeSectionHeader("Two-factor code"))

    self.totpHintLabel.text = "Enabled when a login requires TOTP. Show QR is the normal path on "
      + "first enrollment — scan it with an authenticator. Typing it in by hand wants Copy Secret, "
      + "not Copy Link: a manual setup field takes the bare base32 secret and rejects a full "
      + "otpauth:// URI. Code derivation is a test affordance; a real app collects the code from "
      + "the user."
    self.totpHintLabel.font = .systemFont(ofSize: 12)
    self.totpHintLabel.textColor = .secondaryLabel
    self.totpHintLabel.numberOfLines = 0
    self.totpHintLabel.accessibilityIdentifier = "clientAuthTotpHintLabel"
    self.stack.addArrangedSubview(self.totpHintLabel)

    self.totpSecretField.placeholder = "otpauth://… or a base32 secret"
    self.totpSecretField.borderStyle = .roundedRect
    self.totpSecretField.autocapitalizationType = .none
    self.totpSecretField.autocorrectionType = .no
    self.totpSecretField.accessibilityIdentifier = "clientAuthTotpSecretField"
    self.totpSecretField.addTarget(self, action: #selector(self.handleTotpFieldChanged), for: .editingChanged)
    self.stack.addArrangedSubview(self.totpSecretField)

    let copyRow = UIStackView()
    copyRow.axis = .horizontal
    copyRow.spacing = 12
    copyRow.distribution = .fillEqually

    self.configureButton(self.copyTotpSecretButton, title: "Copy Secret", color: .systemGray, action: #selector(self.handleCopyTotpSecret))
    self.copyTotpSecretButton.accessibilityIdentifier = "clientAuthCopyTotpSecretButton"
    copyRow.addArrangedSubview(self.copyTotpSecretButton)

    self.configureButton(self.copyTotpLinkButton, title: "Copy Link", color: .systemGray, action: #selector(self.handleCopyTotpLink))
    self.copyTotpLinkButton.accessibilityIdentifier = "clientAuthCopyTotpLinkButton"
    copyRow.addArrangedSubview(self.copyTotpLinkButton)

    self.stack.addArrangedSubview(copyRow)

    let derivationRow = UIStackView()
    derivationRow.axis = .horizontal
    derivationRow.spacing = 12
    derivationRow.distribution = .fillEqually

    self.configureButton(self.generateTotpCodeButton, title: "Generate", color: .systemGray, action: #selector(self.handleGenerateTotpCode))
    self.generateTotpCodeButton.accessibilityIdentifier = "clientAuthGenerateTotpCodeButton"
    derivationRow.addArrangedSubview(self.generateTotpCodeButton)

    self.configureButton(self.showTotpQrButton, title: "Show QR", color: .systemGray, action: #selector(self.handleShowTotpQr))
    self.showTotpQrButton.accessibilityIdentifier = "clientAuthShowTotpQrButton"
    derivationRow.addArrangedSubview(self.showTotpQrButton)

    self.stack.addArrangedSubview(derivationRow)

    self.totpCodeField.placeholder = "6-digit code"
    self.totpCodeField.borderStyle = .roundedRect
    self.totpCodeField.keyboardType = .numberPad
    self.totpCodeField.textContentType = .oneTimeCode
    self.totpCodeField.accessibilityIdentifier = "clientAuthTotpCodeField"
    self.totpCodeField.addTarget(self, action: #selector(self.handleTotpFieldChanged), for: .editingChanged)
    self.stack.addArrangedSubview(self.totpCodeField)

    self.configureButton(self.verifyTotpButton, title: "Verify TOTP", color: .systemGreen, action: #selector(self.handleVerifyTotp))
    self.verifyTotpButton.accessibilityIdentifier = "clientAuthVerifyTotpButton"
    self.stack.addArrangedSubview(self.verifyTotpButton)

    self.stack.addArrangedSubview(self.makeSeparator())
  }

  private func setupResultSection() {
    self.configureButton(self.doneButton, title: "Back to app", color: .systemBlue, action: #selector(self.handleDone))
    self.doneButton.accessibilityIdentifier = "clientAuthDoneButton"
    self.stack.addArrangedSubview(self.doneButton)

    self.resultLabel.text = ""
    self.resultLabel.font = .systemFont(ofSize: 13)
    self.resultLabel.textAlignment = .center
    self.resultLabel.numberOfLines = 0
    self.resultLabel.accessibilityIdentifier = "clientAuthResultLabel"
    self.stack.addArrangedSubview(self.resultLabel)

    self.logLabel.text = ""
    self.logLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    self.logLabel.textColor = .label
    self.logLabel.numberOfLines = 0
    self.logLabel.accessibilityIdentifier = "clientAuthLogTextView"
    self.stack.addArrangedSubview(self.logLabel)
  }

  @objc private func handleTotpFieldChanged() {
    self.applyTotpUiState()
  }

  private func configureButton(_ button: UIButton, title: String, color: UIColor, action: Selector) {
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .boldSystemFont(ofSize: 16)
    button.backgroundColor = color
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(.white, for: .disabled)
    button.layer.cornerRadius = 8
    button.heightAnchor.constraint(equalToConstant: 44).isActive = true
    button.addTarget(self, action: action, for: .touchUpInside)
  }

  private func makeSectionHeader(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .boldSystemFont(ofSize: 18)
    label.textAlignment = .left
    return label
  }

  private func makeSeparator() -> UIView {
    let separator = UIView()
    separator.backgroundColor = .separator
    separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return separator
  }
}

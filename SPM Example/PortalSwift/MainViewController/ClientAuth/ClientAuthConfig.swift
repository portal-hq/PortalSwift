//
//  ClientAuthConfig.swift
//  SPM Example
//
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

// MARK: - Missing keys

/// The `AUTH_*` Info.plist keys that are blank, in a fixed order.
///
/// A free function taking values rather than a property on `ClientAuthConfig` so a test asserts
/// on the rule instead of on whatever `Secrets.xcconfig` the developer happens to have.
func missingClientAuthKeys(
  authEnvironmentId: String,
  redirectUrl: String,
  magicLinkFromEmail: String,
  magicLinkTemplateId: String
) -> [String] {
  var missing: [String] = []
  if isBlankClientAuthValue(authEnvironmentId) { missing.append("AUTH_ENVIRONMENT_ID") }
  if isBlankClientAuthValue(redirectUrl) { missing.append("AUTH_REDIRECT_URL") }
  if isBlankClientAuthValue(magicLinkFromEmail) { missing.append("AUTH_MAGIC_LINK_FROM_EMAIL") }
  if isBlankClientAuthValue(magicLinkTemplateId) { missing.append("AUTH_MAGIC_LINK_TEMPLATE_ID") }
  return missing
}

/// Blank means "absent": Xcode expands an undefined `$(VAR)` to an empty string, so the
/// Info.plist key exists either way, and a stray space in `Secrets.xcconfig` must not read as
/// a configured value.
private func isBlankClientAuthValue(_ value: String) -> Bool {
  value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

// MARK: - Redirect scheme

/// The custom scheme (or `https`) the app must own for `redirectUrl` to reach it, lowercased.
///
/// Parsed by hand rather than through `URL`: the value comes from build configuration, may be
/// blank or malformed, and `URL(string:)` accepts shapes whose `scheme` is not what the OS
/// matches a `CFBundleURLSchemes` entry against.
///
/// - Returns: `nil` when the value is blank, carries no scheme, or the candidate is not an
///   RFC 3986 scheme (`ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`).
func redirectScheme(of redirectUrl: String) -> String? {
  clientAuthRedirectScheme(of: redirectUrl)
}

/// The implementation behind both `redirectScheme(of:)` and `ClientAuthConfig.redirectScheme`.
///
/// Named apart from either because a member named `redirectScheme` shadows the free function
/// inside the type's own scope, and the app target has no module-qualified path to a free
/// function to disambiguate with.
private func clientAuthRedirectScheme(of redirectUrl: String) -> String? {
  let trimmed = redirectUrl.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty, let colon = trimmed.firstIndex(of: ":") else {
    return nil
  }

  let candidate = trimmed[trimmed.startIndex ..< colon]
  guard let first = candidate.first, first.isASCIILetterForScheme else {
    return nil
  }
  guard candidate.allSatisfy({ $0.isSchemeCharacter }) else {
    return nil
  }

  return candidate.lowercased()
}

private extension Character {
  var isASCIILetterForScheme: Bool {
    isASCII && isLetter
  }

  var isSchemeCharacter: Bool {
    guard isASCII else { return false }
    return isLetter || isNumber || self == "+" || self == "-" || self == "."
  }
}

// MARK: - ClientAuthConfig

/// The four `AUTH_*` values, read from the Info.plist by `Settings`.
///
/// All four are blank by default — `Secrets.xcconfig` is gitignored and nothing in CI defines
/// them — so "not configured" is the normal path and has to stay inert.
///
/// Two tiers, because the SDK has two requirements: `PortalAuth`'s initializer needs the
/// environment id and the redirect URL, while `sendMagicLink` additionally needs the magic-link
/// pair. An app with only the core pair still does OAuth.
struct ClientAuthConfig: Equatable, CustomStringConvertible {
  let authEnvironmentId: String
  let redirectUrl: String
  let magicLinkFromEmail: String
  let magicLinkTemplateId: String

  init(
    authEnvironmentId: String = "",
    redirectUrl: String = "",
    magicLinkFromEmail: String = "",
    magicLinkTemplateId: String = ""
  ) {
    self.authEnvironmentId = authEnvironmentId
    self.redirectUrl = redirectUrl
    self.magicLinkFromEmail = magicLinkFromEmail
    self.magicLinkTemplateId = magicLinkTemplateId
  }

  /// What `PortalAuth(authEnvironmentId:redirectUrl:)` requires to be non-blank.
  var isConfigured: Bool {
    !isBlankClientAuthValue(self.authEnvironmentId) && !isBlankClientAuthValue(self.redirectUrl)
  }

  /// `sendMagicLink` fails without both backend-required magic-link fields.
  var isMagicLinkConfigured: Bool {
    self.isConfigured
      && !isBlankClientAuthValue(self.magicLinkFromEmail)
      && !isBlankClientAuthValue(self.magicLinkTemplateId)
  }

  /// Passed verbatim to the SDK, which normalizes the address at send time.
  var magicLink: MagicLinkConfig? {
    guard self.isMagicLinkConfigured else { return nil }
    return MagicLinkConfig(fromEmail: self.magicLinkFromEmail, templateId: self.magicLinkTemplateId)
  }

  var missingKeys: [String] {
    missingClientAuthKeys(
      authEnvironmentId: self.authEnvironmentId,
      redirectUrl: self.redirectUrl,
      magicLinkFromEmail: self.magicLinkFromEmail,
      magicLinkTemplateId: self.magicLinkTemplateId
    )
  }

  /// The URL scheme the app has to register for `redirectUrl` to be delivered to it.
  var redirectScheme: String? {
    clientAuthRedirectScheme(of: self.redirectUrl)
  }

  /// Describes the gate, never the values.
  ///
  /// The environment id, the redirect URL, the sender address and the template id are all
  /// configuration secrets or user-identifying, and the unified log is persistent, so the only
  /// things safe to print are the two flags and the names of the missing keys.
  var description: String {
    "ClientAuthConfig(isConfigured: \(self.isConfigured), isMagicLinkConfigured: \(self.isMagicLinkConfigured), missingKeys: \(self.missingKeys))"
  }
}

// MARK: - PortalAuthParams

/// Everything `PortalAuth` is constructed from, as a value so a test can assert on the exact
/// arguments a rebuild used without reaching into the SDK.
struct PortalAuthParams: Equatable {
  let authEnvironmentId: String
  let redirectUrl: String
  let apiHost: String
  let magicLink: MagicLinkConfig?
  let isAccountAbstracted: Bool
}

// MARK: - PortalAuthProvider

/// Holds the one `PortalAuth` the app uses, shared by the main screen (restore, clear) and the
/// Client Auth screen (send, handleRedirect).
///
/// Sessions are keyed by `authEnvironmentId`, so two instances would in fact share Keychain
/// storage — a single instance just removes any chance of them disagreeing about the redirect
/// URL or the host, and it is what keeps the SDK's replay memo and sign-in guard meaningful.
///
/// `isAccountAbstracted` is deliberately a value this type owns, snapshotted at construction and
/// re-read only on an explicit user toggle or an environment change. `Settings.shared`'s copy is
/// rewritten from the live client by `updateUIComponents()` on every refresh, and reading it here
/// would silently mint a new `PortalAuth` mid-flow — discarding the replay memo and any pending
/// TOTP step.
final class PortalAuthProvider {
  /// The app-wide provider, wired to `Settings` and to the coordinator's pending TOTP step.
  ///
  /// The closures are read at each `get()` rather than captured as values, so an environment
  /// switch or a reloaded `Secrets.xcconfig` is picked up by the next rebuild instead of being
  /// frozen at launch.
  static let shared = PortalAuthProvider(
    config: { Settings.shared.clientAuthConfig },
    apiHost: { Settings.shared.portalConfig.environment.portalApiHost },
    pendingTotpUserJwt: { ClientAuthCoordinator.shared.pendingTotpUserJwt }
  )

  private let lock = NSLock()
  private let config: () -> ClientAuthConfig
  private let apiHost: () -> String
  private let pendingTotpUserJwt: () -> String?
  private let factory: (PortalAuthParams) throws -> PortalAuth
  private let warn: (String) -> Void

  /// Guarded by `lock`.
  private var instance: PortalAuth?
  /// Guarded by `lock`.
  private var accountAbstracted: Bool

  init(
    config: @escaping () -> ClientAuthConfig,
    apiHost: @escaping () -> String,
    isAccountAbstracted: Bool = Settings.shared.isAccountAbstracted,
    pendingTotpUserJwt: @escaping () -> String? = { nil },
    factory: @escaping (PortalAuthParams) throws -> PortalAuth = PortalAuthProvider.defaultFactory,
    warn: @escaping (String) -> Void = { print($0) }
  ) {
    self.config = config
    self.apiHost = apiHost
    self.accountAbstracted = isAccountAbstracted
    self.pendingTotpUserJwt = pendingTotpUserJwt
    self.factory = factory
    self.warn = warn
  }

  /// The account-abstraction flag the current instance was built with.
  var isAccountAbstracted: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.accountAbstracted
  }

  /// The shared instance, or `nil` when Client Auth is not configured.
  ///
  /// The build happens under `lock` so concurrent callers get one instance rather than one each;
  /// a throwing factory leaves the slot empty, so the next call retries.
  func get() throws -> PortalAuth? {
    let config = self.config()
    guard config.isConfigured else { return nil }

    self.lock.lock()
    defer { self.lock.unlock() }

    if let instance = self.instance {
      return instance
    }

    let params = PortalAuthParams(
      authEnvironmentId: config.authEnvironmentId,
      redirectUrl: config.redirectUrl,
      apiHost: self.apiHost(),
      magicLink: config.magicLink,
      isAccountAbstracted: self.accountAbstracted
    )
    let built = try self.factory(params)
    self.instance = built
    return built
  }

  /// Records an explicit user toggle. Rebuilds on the next `get()` only when the value changed.
  func setAccountAbstracted(_ value: Bool) {
    self.lock.lock()
    guard value != self.accountAbstracted else {
      self.lock.unlock()
      return
    }
    self.accountAbstracted = value
    let discardedInstance = self.instance != nil
    self.instance = nil
    self.lock.unlock()

    if discardedInstance {
      self.warnIfPendingTotpDiscarded()
    }
  }

  /// Records an environment (API host) change. The next `get()` rebuilds.
  func environmentDidChange() {
    self.lock.lock()
    let discardedInstance = self.instance != nil
    self.instance = nil
    self.lock.unlock()

    if discardedInstance {
      self.warnIfPendingTotpDiscarded()
    }
  }

  /// The `userJwt` of a TOTP step only means something to the instance that issued it, so a
  /// rebuild strands the user mid-verification. Warn by name only: the JWT itself is a bearer
  /// credential and never reaches a log line.
  private func warnIfPendingTotpDiscarded() {
    let pending = self.pendingTotpUserJwt()?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let pending, !pending.isEmpty else { return }
    self.warn("ClientAuth: PortalAuth was rebuilt and the pending TOTP step discarded; the user has to start sign-in again.")
  }

  /// The production factory: a real `PortalAuth`. Performs no Keychain or network I/O.
  static func defaultFactory(_ params: PortalAuthParams) throws -> PortalAuth {
    try PortalAuth(
      authEnvironmentId: params.authEnvironmentId,
      redirectUrl: params.redirectUrl,
      apiHost: params.apiHost,
      magicLink: params.magicLink,
      isAccountAbstracted: params.isAccountAbstracted
    )
  }
}

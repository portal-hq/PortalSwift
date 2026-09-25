//
//  Settings.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 05/12/2024.
//  Copyright © 2024 Portal. All rights reserved.
//

import Foundation
import os.log
import PortalSwift

struct ApplicationConfiguration {
  let alchemyApiKey: String
  let apiUrl: String
  let custodianServerUrl: String
  /// API key sent as the `x-api-key` header on every custodian server request.
  /// Empty means no header is sent, which is the case for `.localHost`.
  let custodianApiKey: String
  let googleClientId: String
  let mpcUrl: String
  let webAuthnHost: String
  let relyingParty: String
  let enclaveMPCHost: String
}

enum Environment: String, Equatable {
  case production
  case staging
  case localHost
}

// MARK: - Portal Hosts

/// Portal API hosts, one per environment.
///
/// Promoted out of `loadApplicationConfig()` because `PortalAuth` needs the same value: an
/// `authEnvironmentId` minted on staging does not exist on production, and a session has to be
/// spent against the backend that issued it, so both must follow one `ENV` switch.
enum PortalHosts {
  static let production = "api.portalhq.io"
  static let staging = "api.portalhq.dev"
  static let localHost = "localhost:3001"
}

extension Environment {
  /// The Portal API host for this environment, shared by `Portal` and `PortalAuth`.
  var portalApiHost: String {
    switch self {
    case .production:
      return PortalHosts.production
    case .staging:
      return PortalHosts.staging
    case .localHost:
      return PortalHosts.localHost
    }
  }
}

struct PortalConfig {
  var environment: Environment = {
    if let env = Bundle.main.infoDictionary?["ENV"] as? String {
      switch env.trimmingCharacters(in: .whitespaces).lowercased() {
      case "local", "localhost":
        return .localHost
      case "staging":
        return .staging
      default:
        return .production
      }
    }
    return .production
  }()

  var gdriveBackupOption: GDriveBackupOption = .appDataFolder
  var appConfig: ApplicationConfiguration?
}

class Settings: ObservableObject {
  static let shared = Settings()
  private let logger = Logger()

  private init() {
    loadApplicationConfig()
  }

  var portalConfig: PortalConfig = .init()

  /// The four `AUTH_*` values for this build's environment, all blank unless `Secrets.xcconfig`
  /// defines them.
  ///
  /// Which of the four key sets is read follows `ENV` and `BACKUP_WITH_PORTAL`; see
  /// `ClientAuthKeys`.
  ///
  /// Populated by `loadApplicationConfig()` before the other keys are validated, so Client Auth
  /// stays readable even when an unrelated secret is missing.
  private(set) var clientAuthConfig: ClientAuthConfig = .init()

  /// Whether this build was compiled against the backup-with-Portal PortalEx instance.
  ///
  /// A build-time choice (`BACKUP_WITH_PORTAL` picks the custodian server URL and its
  /// `x-api-key`), while the register/backup gate is the runtime
  /// `client.environment?.backupWithPortalEnabled`. The two can disagree, which is why the flag
  /// is exposed rather than kept local to `loadApplicationConfig()`.
  private(set) var isBuiltWithBackupWithPortal: Bool = false

  var isAccountAbstracted: Bool = false
  var useEnclaveMPC: Bool = false
  var usePresignatures: Bool = false
  var usePreGeneratedWallet: Bool = true
}

// MARK: - Custodian Server Configuration

/// Environment-specific values for the PortalEx custodian server.
///
/// These live here rather than inline in `loadApplicationConfig()` so every URL and Secrets key
/// name has a single home.
private enum CustodianServer {
  /// Base URL of the custodian server backing each environment.
  enum Url {
    static let production = "https://portalex-mpc.portalhq.io"
    static let productionBackupWithPortal = "https://prod-portalex-backup-with-portal.onrender.com"
    static let staging = "https://staging-portalex-mpc-service.onrender.com"
    static let stagingBackupWithPortal = "https://staging-portalex-backup-with-portal.onrender.com"
    static let localHost = "http://localhost:3010"
  }

  /// Info.plist keys (fed from Secrets.xcconfig) holding the `x-api-key` for each environment.
  /// `.localHost` has none: the custodian server it runs doesn't check the header.
  enum ApiKeyPlistKey {
    static let production = "PORTAL_EX_PROD_API_KEY"
    static let productionBackupWithPortal = "PORTAL_EX_BACKUP_WITH_PORTAL_PROD_API_KEY"
    static let staging = "PORTAL_EX_STAGING_API_KEY"
    static let stagingBackupWithPortal = "PORTAL_EX_BACKUP_WITH_PORTAL_STAGING_API_KEY"
  }
}

// MARK: - Client Auth Configuration

/// Info.plist key prefixes (fed from Secrets.xcconfig) for the four `AUTH_*` values, one set per
/// `ENV` × `BACKUP_WITH_PORTAL` combination.
///
/// Client Auth follows the same switch as the custodian API key because an auth environment id
/// exists on exactly one backend, and the magic-link template it sends belongs to that
/// environment, so the four values only make sense as a set.
private enum ClientAuthKeys {
  static let production = "AUTH_PROD"
  static let productionBackupWithPortal = "AUTH_BACKUP_WITH_PORTAL_PROD"
  static let staging = "AUTH_STAGING"
  static let stagingBackupWithPortal = "AUTH_BACKUP_WITH_PORTAL_STAGING"

  /// `.localHost` has no set of its own and reuses staging's: a local backend is the closest
  /// thing to staging, and a locally minted auth environment would need its own keys here.
  static func plistKeyPrefix(for environment: Environment, isBackupWithPortal: Bool) -> String {
    switch environment {
    case .production:
      return isBackupWithPortal ? self.productionBackupWithPortal : self.production
    case .staging, .localHost:
      return isBackupWithPortal ? self.stagingBackupWithPortal : self.staging
    }
  }
}

// MARK: - App Configuration

extension Settings {
  func loadApplicationConfig() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        self.logger.error("Settings - Couldn't load info.plist dictionary.")
        throw PortalExampleAppError.cantLoadInfoPlist()
      }
      // Read before the required keys are validated: Client Auth is optional, and a missing
      // ALCHEMY_API_KEY must not leave `clientAuthConfig` unpopulated. `BACKUP_WITH_PORTAL` is
      // therefore read tolerantly here — the strict guard below still rejects a missing flag for
      // the custodian config, and for key selection a missing flag reads as `false`, which is
      // what that guard's `== "true"` does with any unexpected value too.
      let clientAuthKeyPrefix = ClientAuthKeys.plistKeyPrefix(
        for: self.portalConfig.environment,
        isBackupWithPortal: optionalSecret("BACKUP_WITH_PORTAL", from: infoDictionary) == "true"
      )
      self.clientAuthConfig = ClientAuthConfig(
        authEnvironmentId: optionalSecret("\(clientAuthKeyPrefix)_ENVIRONMENT_ID", from: infoDictionary),
        redirectUrl: optionalSecret("\(clientAuthKeyPrefix)_REDIRECT_URL", from: infoDictionary),
        magicLinkFromEmail: optionalSecret("\(clientAuthKeyPrefix)_MAGIC_LINK_FROM_EMAIL", from: infoDictionary),
        magicLinkTemplateId: optionalSecret("\(clientAuthKeyPrefix)_MAGIC_LINK_TEMPLATE_ID", from: infoDictionary),
        keyPrefix: clientAuthKeyPrefix
      )
      // Flags and fixed key names only: the four values are configuration secrets, and the
      // unified log is persistent.
      self.logger.info("Settings - Client Auth isConfigured: \(self.clientAuthConfig.isConfigured, privacy: .public), isMagicLinkConfigured: \(self.clientAuthConfig.isMagicLinkConfigured, privacy: .public), missingKeys: \(self.clientAuthConfig.missingKeys.joined(separator: ", "), privacy: .public)")

      guard let ALCHEMY_API_KEY: String = infoDictionary["ALCHEMY_API_KEY"] as? String else {
        self.logger.error("Settings - Error: Do you have `ALCHEMY_API_KEY=$(ALCHEMY_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }
      guard let GOOGLE_CLIENT_ID: String = infoDictionary["GDRIVE_CLIENT_ID"] as? String else {
        self.logger.error("Settings - Error: Do you have `GDRIVE_CLIENT_ID=$(GDRIVE_CLIENT_ID)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }
      guard let BACKUP_WITH_PORTAL: String = infoDictionary["BACKUP_WITH_PORTAL"] as? String else {
        self.logger.error("Settings - Error: The environment variable `BACKUP_WITH_PORTAL` is not set or is empty. Please ensure that `BACKUP_WITH_PORTAL=true` or `BACKUP_WITH_PORTAL=false` is included in your Secrets.xcconfig file, and that `BACKUP_WITH_PORTAL=$(BACKUP_WITH_PORTAL)` is referenced correctly in your App's info.plist.")
        throw PortalExampleAppError.environmentNotSet()
      }

      let isBackupWithPortal = BACKUP_WITH_PORTAL == "true"
      self.isBuiltWithBackupWithPortal = isBackupWithPortal

      switch portalConfig.environment {
      case .production:
        logger.info("Settings - configuring for production")

        let custodianServerUrl = isBackupWithPortal ? CustodianServer.Url.productionBackupWithPortal : CustodianServer.Url.production
        let custodianApiKeyPlistKey = isBackupWithPortal ? CustodianServer.ApiKeyPlistKey.productionBackupWithPortal : CustodianServer.ApiKeyPlistKey.production
        let custodianApiKey = try requireSecret(custodianApiKeyPlistKey, from: infoDictionary)

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: PortalHosts.production,
          custodianServerUrl: custodianServerUrl,
          custodianApiKey: custodianApiKey,
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.io",
          webAuthnHost: "backup.web.portalhq.io",
          relyingParty: "portalhq.io",
          enclaveMPCHost: "mpc-client.portalhq.io"
        )
      case .staging:
        logger.info("Settings - configuring for staging")

        let custodianServerUrl = isBackupWithPortal ? CustodianServer.Url.stagingBackupWithPortal : CustodianServer.Url.staging
        let custodianApiKeyPlistKey = isBackupWithPortal ? CustodianServer.ApiKeyPlistKey.stagingBackupWithPortal : CustodianServer.ApiKeyPlistKey.staging
        let custodianApiKey = try requireSecret(custodianApiKeyPlistKey, from: infoDictionary)

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: PortalHosts.staging,
          custodianServerUrl: custodianServerUrl,
          custodianApiKey: custodianApiKey,
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.dev",
          webAuthnHost: "backup.portalhq.dev",
          relyingParty: "portalhq.dev",
          enclaveMPCHost: "mpc-client.portalhq.dev"
        )
      case .localHost:
        logger.info("Settings - configuring for localhost")

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: PortalHosts.localHost,
          custodianServerUrl: CustodianServer.Url.localHost,
          custodianApiKey: "",
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "localhost:3002",
          webAuthnHost: "localhost:8080",
          relyingParty: "localhost",
          enclaveMPCHost: "localhost:8081"
        )
      }

    } catch {
      self.logger.error("Settings - Error loading application config: \(error)")
    }
  }

  /// Reads a required value from the Info.plist, trimmed of surrounding whitespace.
  ///
  /// Note the `isEmpty` check: Xcode expands an undefined `$(VAR)` to an empty string, so the
  /// Info.plist key still exists and a plain `as? String` cast would succeed. Without this check a
  /// missing Secrets.xcconfig entry would silently produce `""` instead of an error.
  ///
  /// The trimmed value is what gets returned, so a stray space in Secrets.xcconfig can't leak into
  /// a request header and cause an authentication failure that's hard to trace back to here.
  private func requireSecret(_ key: String, from infoDictionary: [String: Any]) throws -> String {
    let value = (infoDictionary[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let value, !value.isEmpty else {
      self.logger.error("Settings - Error: Do you have `\(key)=<your key>` in your Secrets.xcconfig, and `\(key)=$(\(key))` referenced in your App's info.plist?")
      throw PortalExampleAppError.environmentNotSet()
    }

    return value
  }
}

// MARK: - Optional Secrets

/// Reads an optional value from the Info.plist, trimmed of surrounding whitespace.
///
/// The tolerant sibling of `requireSecret`: an undefined `$(VAR)` expands to an empty string, so
/// a missing key and a blank one are the same thing and both mean "the feature is off". Returns
/// `""` rather than throwing, and logs nothing — the caller decides whether blank is a problem,
/// and the values these keys hold never belong in a log line.
func optionalSecret(_ key: String, from infoDictionary: [String: Any]) -> String {
  (infoDictionary[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

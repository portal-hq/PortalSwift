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

  var isAccountAbstracted: Bool = false
  var useEnclaveMPC: Bool = false
  var usePresignatures: Bool = false
  var usePreGeneratedWallet: Bool = true
}

// MARK: - App Configuration

extension Settings {
  func loadApplicationConfig() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else {
        self.logger.error("Settings - Couldn't load info.plist dictionary.")
        throw PortalExampleAppError.cantLoadInfoPlist()
      }
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

      switch portalConfig.environment {
      case .production:
        logger.info("Settings - configuring for production")

        let custodianServerUrl = isBackupWithPortal ? "https://prod-portalex-backup-with-portal.onrender.com" : "https://portalex-mpc.portalhq.io"
        let custodianApiKey = try requireSecret(isBackupWithPortal ? "PORTAL_EX_BACKUP_WITH_PORTAL_PROD_API_KEY" : "PORTAL_EX_PROD_API_KEY", from: infoDictionary)

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.io",
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

        let custodianServerUrl = isBackupWithPortal ? "https://staging-portalex-backup-with-portal.onrender.com" : "https://staging-portalex-mpc-service.onrender.com"
        let custodianApiKey = try requireSecret(isBackupWithPortal ? "PORTAL_EX_BACKUP_WITH_PORTAL_STAGING_API_KEY" : "PORTAL_EX_STAGING_API_KEY", from: infoDictionary)

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.dev",
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
          apiUrl: "localhost:3001",
          custodianServerUrl: "http://localhost:3010",
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

  /// Reads a required value from the Info.plist.
  ///
  /// Note the `isEmpty` check: Xcode expands an undefined `$(VAR)` to an empty string, so the
  /// Info.plist key still exists and a plain `as? String` cast would succeed. Without this check a
  /// missing Secrets.xcconfig entry would silently produce `""` instead of an error.
  private func requireSecret(_ key: String, from infoDictionary: [String: Any]) throws -> String {
    guard let value: String = infoDictionary[key] as? String, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
      self.logger.error("Settings - Error: Do you have `\(key)=<your key>` in your Secrets.xcconfig, and `\(key)=$(\(key))` referenced in your App's info.plist?")
      throw PortalExampleAppError.environmentNotSet()
    }

    return value
  }
}

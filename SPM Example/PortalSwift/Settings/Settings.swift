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
  var environment: Environment = .production
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

      switch portalConfig.environment {
      case .production:
        logger.info("Settings - configuring for production")

        let custodianServerUrl = BACKUP_WITH_PORTAL == "true" ? "https://prod-portalex-backup-with-portal.onrender.com" : "https://portalex-mpc.portalhq.io"

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.io",
          custodianServerUrl: custodianServerUrl,
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "mpc.portalhq.io",
          webAuthnHost: "backup.web.portalhq.io",
          relyingParty: "portalhq.io",
          enclaveMPCHost: "mpc-client.portalhq.io"
        )
      case .staging:
        logger.info("Settings - configuring for staging")

        let custodianServerUrl = BACKUP_WITH_PORTAL == "true" ? "https://staging-portalex-backup-with-portal.onrender.com" : "https://staging-portalex-mpc-service.onrender.com"

        portalConfig.appConfig = ApplicationConfiguration(
          alchemyApiKey: ALCHEMY_API_KEY,
          apiUrl: "api.portalhq.dev",
          custodianServerUrl: custodianServerUrl,
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
          googleClientId: GOOGLE_CLIENT_ID,
          mpcUrl: "localhost:3002",
          webAuthnHost: "backup.portalhq.dev",
          relyingParty: "portalhq.dev",
          enclaveMPCHost: "mpc-client.portalhq.dev"
        )
      }

    } catch {
      self.logger.error("Settings - Error loading application config: \(error)")
    }
  }
}

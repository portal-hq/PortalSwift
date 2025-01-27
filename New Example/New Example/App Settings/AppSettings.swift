//
//  AppSettings.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation
import PortalSwift

class AppSettings {
  static let shared = AppSettings()

    var env: AppEnv = {
        guard let envStr = AppSettings.infoDictionary[Keys.env] as? String else {
            fatalError("New Example: ENV not found in Info.plist.")
        }
        if envStr.lowercased().contains("prod") {
            return .production
        } else if envStr.lowercased().contains("stag") {
            return .staging
        } else {
            return .staging
        }
    }()

  private init() {}

  var gdriveBackupOption: GDriveBackupOption = .appDataFolder
}

// MARK: - App configs from Secrets file helpers
extension AppSettings {
    private enum Keys {
        static let env = "ENV"
        static let gdriveClientId = "GDRIVE_CLIENT_ID"
        static let alchemyApiKey = "ALCHEMY_API_KEY"
    }

    private static let infoDictionary: [String: Any] =  {
        guard let dictionary = Bundle.main.infoDictionary else {
            fatalError("New Example: Plist not found.")
        }
        return dictionary
    }()
}

extension AppSettings {
    enum Config {
      static var alchemyApiKey: String {
          guard let key = AppSettings.infoDictionary[Keys.alchemyApiKey] as? String else {
              fatalError("New Example: ALCHEMY_API_KEY not found in Info.plist.")
          }
        return key
      }

      static var apiUrl: String {
        switch AppSettings.shared.env {
        case .localhost:
          return "localhost:3001"
        case .staging:
          return "api.portalhq.dev"
        case .production:
          return "api.portalhq.io"
        }
      }

      static var shouldBackupWithPortal: Bool {
        return true
      }

      static var custodianServerUrl: String {
        switch AppSettings.shared.env {
        case .localhost:
          return "http://localhost:3010"
        case .staging:
          if Config.shouldBackupWithPortal {
            return "https://staging-portalex-backup-with-portal.onrender.com"
          } else {
            return "https://staging-portalex-mpc-service.onrender.com"
          }
        case .production:
          if Config.shouldBackupWithPortal {
            return "https://prod-portalex-backup-with-portal.onrender.com"
          } else {
            return "https://portalex-mpc.portalhq.io"
          }
        }
      }

      static var googleClientId: String {
          guard let clientId = AppSettings.infoDictionary[Keys.gdriveClientId] as? String else {
              fatalError("New Example: GDrive Client ID not found in Info.plist.")
          }
        return clientId
      }

      static var mpcUrl: String {
        switch AppSettings.shared.env {
        case .localhost:
          return "localhost:3002"
        case .staging:
          return "mpc.portalhq.dev"
        case .production:
          return "mpc.portalhq.io"
        }
      }

      static var webAuthnHost: String {
        switch AppSettings.shared.env {
        case .localhost:
          return "backup.portalhq.dev"
        case .staging:
          return "backup.portalhq.dev"
        case .production:
          return "backup.web.portalhq.io"
        }
      }

      static var relyingParty: String {
        switch AppSettings.shared.env {
        case .localhost:
          return "portalhq.dev"
        case .staging:
          return "portalhq.dev"
        case .production:
          return "portalhq.io"
        }
      }
    }
}

//
//  AppConfigViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation
import UIKit

final class AppConfigViewModel: ObservableObject {
  @Published var appConfig = AppSettings.Config.toArrayOfTuple()
    
    func copyToClipboard(for key: String) {
        let value = appConfig.first { $0.key == key }?.value ?? ""
        UIPasteboard.general.string = value
    }
}

fileprivate extension AppSettings.Config {
  static func toArrayOfTuple() -> [(key: String, value: String)] {
    return [
      (key: "Env", value: AppSettings.shared.env.rawValue),
      (key: "alchemyApiKey", value: AppSettings.Config.alchemyApiKey),
      (key: "apiUrl", value: AppSettings.Config.apiUrl),
      (key: "shouldBackupWithPortal", value: AppSettings.Config.shouldBackupWithPortal.description),
      (key: "custodianServerUrl", value: AppSettings.Config.custodianServerUrl),
      (key: "googleClientId", value: AppSettings.Config.googleClientId),
      (key: "mpcUrl", value: AppSettings.Config.mpcUrl),
      (key: "webAuthnHost", value: AppSettings.Config.webAuthnHost),
      (key: "relyingParty", value: AppSettings.Config.relyingParty)
    ]
  }
}

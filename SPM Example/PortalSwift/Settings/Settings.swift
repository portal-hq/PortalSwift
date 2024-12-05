//
//  Settings.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 05/12/2024.
//  Copyright © 2024 Portal. All rights reserved.
//

import PortalSwift

struct PortalConfig {
  var gdriveBackupOption: GDriveBackupOption = .appDataFolder
  var appConfig: ApplicationConfiguration?
}

class Settings {
  static let shared = Settings()

  private init() {}

  var portalConfig: PortalConfig = .init()
}

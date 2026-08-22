//
//  GDriveBackupOption+Drive.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa on 8/22/26.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

extension GDriveBackupOption {
  /// Raw Google OAuth scope strings. Single definition — no other GDrive code
  /// should hardcode these.
  enum DriveScope {
    static let file = "https://www.googleapis.com/auth/drive.file"
    static let appData = "https://www.googleapis.com/auth/drive.appdata"
  }

  /// The scopes requested when no backup option has been configured (the
  /// legacy configuration path): such integrations write to the user-visible
  /// folder while reads default to the app-data space, so both scopes are
  /// genuinely required.
  static let legacyDriveScopes = [DriveScope.file, DriveScope.appData]

  /// The Drive OAuth scopes this backup option actually needs. Exhaustive
  /// switch on purpose — a new option must declare its own scopes.
  var requiredDriveScopes: [String] {
    switch self {
    case .appDataFolder:
      return [DriveScope.appData]
    case .appDataFolderWithFallback:
      // New backups go to the app data folder, but reads fall back to the
      // user-visible folder so older backups remain recoverable.
      return [DriveScope.file, DriveScope.appData]
    case .gdriveFolder:
      return [DriveScope.file]
    }
  }

  /// Where new backups are written — not the same question as which scopes
  /// are needed, since fallback reads can touch the other space.
  var usesAppDataFolder: Bool {
    switch self {
    case .appDataFolder, .appDataFolderWithFallback:
      return true
    case .gdriveFolder:
      return false
    }
  }

  /// Whether any code path for this option touches the user-visible corpus.
  /// Invariant (test-enforced): equals `requiredDriveScopes.contains(DriveScope.file)`,
  /// because without `drive.file` user-corpus queries return empty rather than
  /// failing. No production call site yet — kept for parity with the Android
  /// SDK so future user-visible-folder work is gated on it.
  var usesUserVisibleFolder: Bool {
    switch self {
    case .appDataFolder:
      return false
    case .appDataFolderWithFallback, .gdriveFolder:
      return true
    }
  }
}

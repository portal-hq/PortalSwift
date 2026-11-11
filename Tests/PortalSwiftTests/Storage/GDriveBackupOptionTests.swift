//
//  GDriveBackupOptionTests.swift
//
//
//  Created by Ahmed Ragab Issa on 8/22/26.
//

@testable import PortalSwift
import XCTest

final class GDriveBackupOptionTests: XCTestCase {
  private let allOptions: [GDriveBackupOption] = [
    .appDataFolder,
    .appDataFolderWithFallback,
    .gdriveFolder(folderName: "test-folder")
  ]
}

// MARK: - requiredDriveScopes tests

extension GDriveBackupOptionTests {
  func test_appDataFolder_requestsOnlyAppDataScope() {
    XCTAssertEqual(
      GDriveBackupOption.appDataFolder.requiredDriveScopes,
      [GDriveBackupOption.DriveScope.appData]
    )
  }

  func test_appDataFolderWithFallback_requestsBothScopes() {
    XCTAssertEqual(
      GDriveBackupOption.appDataFolderWithFallback.requiredDriveScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }

  func test_gdriveFolder_requestsOnlyDriveFileScope() {
    XCTAssertEqual(
      GDriveBackupOption.gdriveFolder(folderName: "any-folder").requiredDriveScopes,
      [GDriveBackupOption.DriveScope.file]
    )
  }

  func test_appDataScope_isNeverRequestedForGdriveFolder() {
    XCTAssertFalse(
      GDriveBackupOption.gdriveFolder(folderName: "any-folder").requiredDriveScopes
        .contains(GDriveBackupOption.DriveScope.appData)
    )
  }

  func test_driveScopeConstants_matchGoogleOAuthUrls() {
    XCTAssertEqual(GDriveBackupOption.DriveScope.file, "https://www.googleapis.com/auth/drive.file")
    XCTAssertEqual(GDriveBackupOption.DriveScope.appData, "https://www.googleapis.com/auth/drive.appdata")
  }

  func test_legacyDriveScopes_requestBothScopes() {
    XCTAssertEqual(
      GDriveBackupOption.legacyDriveScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }
}

// MARK: - folder flag tests

extension GDriveBackupOptionTests {
  func test_usesAppDataFolder_coversBothAppDataVariants() {
    XCTAssertTrue(GDriveBackupOption.appDataFolder.usesAppDataFolder)
    XCTAssertTrue(GDriveBackupOption.appDataFolderWithFallback.usesAppDataFolder)
    XCTAssertFalse(GDriveBackupOption.gdriveFolder(folderName: "any-folder").usesAppDataFolder)
  }

  func test_usesUserVisibleFolder_excludesPlainAppDataFolder() {
    XCTAssertFalse(GDriveBackupOption.appDataFolder.usesUserVisibleFolder)
    XCTAssertTrue(GDriveBackupOption.appDataFolderWithFallback.usesUserVisibleFolder)
    XCTAssertTrue(GDriveBackupOption.gdriveFolder(folderName: "any-folder").usesUserVisibleFolder)
  }

  func test_invariant_usesUserVisibleFolder_matchesDriveFileScope() {
    // Without drive.file, user-corpus queries return empty instead of failing,
    // so any option touching the user-visible folder must request it.
    for option in self.allOptions {
      XCTAssertEqual(
        option.requiredDriveScopes.contains(GDriveBackupOption.DriveScope.file),
        option.usesUserVisibleFolder,
        "Option \(option) requests drive.file iff it uses the user-visible folder"
      )
    }
  }
}

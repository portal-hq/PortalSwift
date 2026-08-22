//
//  GoogleAuthTests.swift
//
//
//  Created by Ahmed Ragab Issa on 8/22/26.
//

import GoogleSignIn
@testable import PortalSwift
import XCTest

final class GoogleAuthTests: XCTestCase {}

// MARK: - missingScopes tests

extension GoogleAuthTests {
  func test_missingScopes_returnsAllRequired_whenNothingGranted() {
    XCTAssertEqual(
      GoogleAuth.missingScopes(required: ["a", "b"], granted: nil),
      ["a", "b"]
    )
    XCTAssertEqual(
      GoogleAuth.missingScopes(required: ["a", "b"], granted: []),
      ["a", "b"]
    )
  }

  func test_missingScopes_returnsEmpty_whenGrantMatchesExactly() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a", "b"], granted: ["a", "b"]), [])
  }

  func test_missingScopes_returnsEmpty_whenGrantIsSuperset() {
    // A user who consented under a wider backup option must not be re-prompted.
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a"], granted: ["a", "b", "c"]), [])
  }

  func test_missingScopes_returnsOnlyTheGap_whenGrantIsPartial() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: ["a", "b", "c"], granted: ["b"]), ["a", "c"])
  }

  func test_missingScopes_returnsEmpty_whenNothingRequired() {
    XCTAssertEqual(GoogleAuth.missingScopes(required: [], granted: nil), [])
  }
}

// MARK: - scopesProvider tests

extension GoogleAuthTests {
  func test_defaultScopesProvider_requestsBothDriveScopes() {
    let auth = GoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))

    XCTAssertEqual(
      auth.requiredScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }

  func test_scopesProvider_isResolvedAtCallTime() {
    var currentOption: GDriveBackupOption = .appDataFolder
    let auth = GoogleAuth(
      config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId),
      scopesProvider: { currentOption.requiredDriveScopes }
    )

    XCTAssertEqual(auth.requiredScopes, [GDriveBackupOption.DriveScope.appData])

    currentOption = .gdriveFolder(folderName: "test-folder")

    XCTAssertEqual(auth.requiredScopes, [GDriveBackupOption.DriveScope.file])
  }
}

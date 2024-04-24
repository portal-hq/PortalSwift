//
//  MockGDriveAuth.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation
import GoogleSignIn

class MockGoogleAuth: GoogleAuth {
  override func getAccessToken() async -> String {
    return MockConstants.mockGoogleAccessToken
  }

  override func getCurrentUser() -> GIDGoogleUser? {
    return nil
  }

  override func hasPreviousSignIn() -> Bool {
    return true
  }

  override func signOut() {}
}

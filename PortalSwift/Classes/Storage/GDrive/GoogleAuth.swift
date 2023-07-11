//
//  GoogleAuth.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

public enum GoogleAuthError: Error {
  case noUserFound
  case unableToReadAccessToken
}

class GoogleAuth {
  public var auth: GIDSignIn
  public var config: GIDConfiguration
  private var view: UIViewController

  init(config: GIDConfiguration, view: UIViewController) {
    auth = GIDSignIn.sharedInstance
    self.config = config
    self.view = view
  }

  func getAccessToken(callback: @escaping (Result<String>) -> Void) {
    if hasPreviousSignIn() {
      // Attempt to sign in silently
      restorePreviousSignIn { result in
        if result.error != nil {
          // Handle error
          callback(Result(error: result.error!))
        } else if let user = result.data {
          // Handle successful sign-in
          callback(Result(data: user.authentication.accessToken))
        }
      }
    } else {
      // User has not signed in before, prompt for sign-in
      signIn { result in
        if result.error != nil {
          // Handle error
          callback(Result(error: result.error!))
        } else if let user = result.data {
          // Handle successful sign-in
          callback(Result(data: user.authentication.accessToken))
        }
      }
    }
  }

  func getCurrentUser() -> GIDGoogleUser? {
    return auth.currentUser
  }

  func hasPreviousSignIn() -> Bool {
    return auth.hasPreviousSignIn()
  }

  func restorePreviousSignIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    auth.restorePreviousSignIn { user, error in
      if error != nil {
        // Handle error
        callback(Result(error: error!))
      } else if let user = user {
        // Handle successful sign-in
        callback(Result(data: user))
      }
    }
  }

  func signIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    auth.signIn(with: config, presenting: view) {
      user, error in
      if error != nil {
        callback(Result(error: error! as Error))
      } else {
        self.auth.addScopes(["https://www.googleapis.com/auth/drive.file"], presenting: self.view)
        callback(Result(data: user!))
      }
    }
  }

  func signOut() {
    auth.signOut()
  }
}

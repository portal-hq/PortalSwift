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
    self.auth = GIDSignIn.sharedInstance
    self.config = config
    self.view = view
  }

  func getAccessToken(callback: @escaping (Result<String>) -> Void) {
    if self.hasPreviousSignIn() {
      // Attempt to sign in silently
      self.restorePreviousSignIn { result in
        if result.error != nil {
          // Handle error
          callback(Result(error: result.error!))
        } else if let user = result.data {
          // Handle successful sign-in
          callback(Result(data: user.accessToken.tokenString))
        }
      }
    } else {
      // User has not signed in before, prompt for sign-in
      self.signIn { result in
        if result.error != nil {
          // Handle error
          callback(Result(error: result.error!))
        } else if let user = result.data {
          // Handle successful sign-in
          callback(Result(data: user.accessToken.tokenString))
        }
      }
    }
  }

  func getCurrentUser() -> GIDGoogleUser? {
    self.auth.currentUser
  }

  func hasPreviousSignIn() -> Bool {
    self.auth.hasPreviousSignIn()
  }

  func restorePreviousSignIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    self.auth.restorePreviousSignIn { user, error in
      if error != nil {
        // Handle error
        callback(Result(error: error!))
      } else if let user {
        // Handle successful sign-in
        callback(Result(data: user))
      }
    }
  }

  func signIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    self.auth.configuration = self.config

    self.auth.signIn(withPresenting: self.view) {
      user, error in
      if error != nil {
        callback(Result(error: error! as Error))
      } else {
        guard let user else {
          callback(Result(error: GoogleAuthError.noUserFound))
          return
        }

        user.user.addScopes(["https://www.googleapis.com/auth/drive.file"], presenting: self.view)

        callback(Result(data: user.user))
      }
    }
  }

  func signOut() {
    self.auth.signOut()
  }
}

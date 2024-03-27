//
//  GoogleAuth.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn
import UIKit

class GoogleAuth {
  public var auth: GIDSignIn
  public var config: GIDConfiguration
  public var view: UIViewController?

  init(config: GIDConfiguration, view: UIViewController? = nil) {
    self.auth = GIDSignIn.sharedInstance
    self.config = config
    self.view = view
  }

  func getAccessToken() async -> String {
    do {
      if self.hasPreviousSignIn() {
        // Attempt to sign in silently
        let user = try await self.restorePreviousSignIn()
        return user.authentication.accessToken
      } else {
        // User has not signed in before, prompt for sign-in
        let user = try await self.signIn()
        return user.authentication.accessToken
      }
    } catch {
      return ""
    }
  }

  func getCurrentUser() -> GIDGoogleUser? {
    self.auth.currentUser
  }

  func hasPreviousSignIn() -> Bool {
    self.auth.hasPreviousSignIn()
  }

  func restorePreviousSignIn() async throws -> GIDGoogleUser {
    let user = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
      self.auth.restorePreviousSignIn { user, error in
        if error != nil {
          return continuation.resume(throwing: error!)
        }

        guard let user else {
          return continuation.resume(throwing: GoogleAuthError.noUserFound)
        }

        continuation.resume(returning: user)
      }
    }

    return user
  }

  func signIn() async throws -> GIDGoogleUser {
    let user = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
      guard let view = self.view else {
        continuation.resume(throwing: GoogleAuthError.noViewFound)
        return
      }

      self.auth.signIn(with: self.config, presenting: view) { user, error in
        if error != nil {
          continuation.resume(throwing: error! as Error)
          return
        }

        guard let user else {
          continuation.resume(throwing: GoogleAuthError.noUserFound)
          return
        }

        self.auth.addScopes(["https://www.googleapis.com/auth/drive.file"], presenting: view)

        continuation.resume(returning: user)
      }
    }

    if let user = auth.currentUser {
      return user
    }

    throw GoogleAuthError.noUserFound
  }

  func signOut() {
    self.auth.signOut()
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  @available(*, deprecated, renamed: "getAccessToken", message: "Please use the async/await implementation of getAccessToken().")
  func getAccessToken(callback: @escaping (Result<String>) -> Void) {
    if self.hasPreviousSignIn() {
      // Attempt to sign in silently
      self.restorePreviousSignIn { result in
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
      self.signIn { result in
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

  @available(*, deprecated, renamed: "restorePreviousSignIn", message: "Please use the async/await implementation of restorePreviousSignIn().")
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

  @available(*, deprecated, renamed: "signIn", message: "Please use the async/await implementation of signIn().")
  func signIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    guard let view = self.view else {
      return callback(Result(
        error: GoogleAuthError.viewMustBeProvidedAtInitialization("When using deprecated completion handler implementations of Portal, a value must be provided for `viewController` on initialization of GDriveStorage.")
      ))
    }
    self.auth.signIn(with: self.config, presenting: view) {
      user, error in
      if error != nil {
        callback(Result(error: error! as Error))
      } else {
        self.auth.addScopes(["https://www.googleapis.com/auth/drive.file"], presenting: view)
        callback(Result(data: user!))
      }
    }
  }
}

public enum GoogleAuthError: Error, Equatable {
  case noUserFound
  case noViewFound
  case unableToReadAccessToken
  case viewMustBeProvidedAtInitialization(_ message: String)
}

//
//  GoogleAuth.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn
import UIKit

public class GoogleAuth {
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
        return user.accessToken.tokenString
      } else {
        // User has not signed in before, prompt for sign-in
        let user = try await self.signIn()
        return user.accessToken.tokenString
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

      self.auth.configuration = self.config

      self.auth.signIn(withPresenting: view) { user, error in
        if error != nil {
          continuation.resume(throwing: error! as Error)
          return
        }

        guard let user else {
          continuation.resume(throwing: GoogleAuthError.noUserFound)
          return
        }

        user.user.addScopes(["https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/drive.appdata"], presenting: view)

        continuation.resume(returning: user.user)
      }
    }

    return user
  }

  func signOut() {
    self.auth.signOut()
  }
}

public enum GoogleAuthError: Error, Equatable {
  case noUserFound
  case noViewFound
  case unableToReadAccessToken
  case viewMustBeProvidedAtInitialization(_ message: String)
}

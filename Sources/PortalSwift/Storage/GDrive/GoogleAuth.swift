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

  private let logger = PortalLogger.shared

  /// Resolves the OAuth scopes to request at the moment of each auth call, so
  /// `backupOption` changes made after this object was built are always honored.
  private let scopesProvider: () -> [String]

  /// The Drive OAuth scopes this instance would request right now.
  var requiredScopes: [String] {
    self.scopesProvider()
  }

  init(
    config: GIDConfiguration,
    view: UIViewController? = nil,
    scopesProvider: @escaping () -> [String] = { GDriveBackupOption.legacyDriveScopes }
  ) {
    self.auth = GIDSignIn.sharedInstance
    self.config = config
    self.view = view
    self.scopesProvider = scopesProvider
  }

  func getAccessToken() async -> String {
    do {
      let user: GIDGoogleUser
      if self.hasPreviousSignIn() {
        // Attempt to sign in silently, upgrading the granted scopes if the
        // configured backup option now requires more than was consented to.
        let restored = try await self.restorePreviousSignIn()
        user = try await self.ensureRequiredScopes(on: restored)
      } else {
        // User has not signed in before, prompt for sign-in
        user = try await self.signIn()
      }
      return user.accessToken.tokenString
    } catch {
      // Contract: callers detect failure via the empty string and map it to
      // GDriveClientError.userNotAuthenticated.
      self.logger.error("GoogleAuth.getAccessToken() - Unable to get an access token: \(error)")
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
    let requiredScopes = self.requiredScopes
    guard let view = self.view else {
      throw GoogleAuthError.noViewFound
    }

    // Request the Drive scopes in the sign-in sheet itself and resume only
    // once the user has answered, so the first Drive call can never race an
    // unanswered consent prompt.
    let user = try await self.awaitSignInResult { completion in
      self.auth.configuration = self.config
      self.auth.signIn(withPresenting: view, hint: nil, additionalScopes: requiredScopes, completion: completion)
    }

    // Google's granular consent screen lets the user untick individual scopes
    // while still completing sign-in.
    try Self.requireScopes(requiredScopes, grantedTo: user)

    return user
  }

  func signOut() {
    self.auth.signOut()
  }

  /// Silently restored sessions were consented under whatever backup option was
  /// configured at the time, so their grant must be re-checked and, when the
  /// current option needs more, upgraded with an awaited incremental consent.
  private func ensureRequiredScopes(on user: GIDGoogleUser) async throws -> GIDGoogleUser {
    let required = self.requiredScopes
    let missing = Self.missingScopes(required: required, granted: user.grantedScopes)
    if missing.isEmpty {
      return user
    }

    guard let view = self.view else {
      self.logger.error("GoogleAuth.ensureRequiredScopes() - Signed-in user is missing scopes \(missing) and no view is configured to present the consent prompt.")
      throw GoogleAuthError.noViewFound
    }

    let upgraded: GIDGoogleUser
    do {
      upgraded = try await self.awaitSignInResult { completion in
        user.addScopes(missing, presenting: view, completion: completion)
      }
    } catch let error as GIDSignInError where error.code == .scopesAlreadyGranted {
      // Another flow granted the scopes concurrently; re-read the current user.
      upgraded = self.auth.currentUser ?? user
    }

    try Self.requireScopes(required, grantedTo: upgraded)

    return upgraded
  }

  /// Bridges a GIDSignIn completion into async/await on the main thread —
  /// GIDSignIn's presentation APIs are main-thread-only — resuming with the
  /// resulting user only after the consent sheet has been answered.
  private func awaitSignInResult(
    _ start: @escaping (@escaping (GIDSignInResult?, Error?) -> Void) -> Void
  ) async throws -> GIDGoogleUser {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
      Task { @MainActor in
        start { result, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }

          guard let user = result?.user else {
            continuation.resume(throwing: GoogleAuthError.noUserFound)
            return
          }

          continuation.resume(returning: user)
        }
      }
    }
  }

  private static func requireScopes(_ required: [String], grantedTo user: GIDGoogleUser) throws {
    let missing = missingScopes(required: required, granted: user.grantedScopes)
    guard missing.isEmpty else {
      throw GoogleAuthError.scopesNotGranted(missing: missing)
    }
  }

  static func missingScopes(required: [String], granted: [String]?) -> [String] {
    let grantedSet = Set(granted ?? [])
    return required.filter { !grantedSet.contains($0) }
  }
}

public enum GoogleAuthError: LocalizedError, Equatable {
  case noUserFound
  case noViewFound
  case scopesNotGranted(missing: [String])
  case unableToReadAccessToken
  case viewMustBeProvidedAtInitialization(_ message: String)
}

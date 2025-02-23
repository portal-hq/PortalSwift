//
//  AuthViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//
import PortalSwift
import UIKit

final class AuthViewModel: ObservableObject {
  enum AuthState {
    case none
    case loading
    case loggedIn(user: UserData)
    case signedUp(user: UserData)
    case error(errorMessage: String)
  }

  enum Destination {
    case mainTabBar
  }

  // MARK: - Properties

  private var portalRepository = PortalRepository()

  // MARK: - UI Properties

  @Published private(set) var authState: AuthState = .none
  @Published private(set) var destination: Destination?
}

// MARK: - Presentation Helpers

private extension AuthViewModel {
  /// set the ``state`` property on the ``MainThread`` to change it safely from any ``Async`` context.
  func setState(_ state: AuthState) {
    Task { @MainActor in
      self.authState = state
    }
  }

  func navigateToMainTabBar() {
    Task { @MainActor in
      AppState.shared.sessionMode = .authorized
    }
  }
}

// MARK: - Sign in

extension AuthViewModel {
  func signIn(username: String) {
    Task {
      do {
        setState(.loading)
        let userData = try await self.postSingIn(username)
        UserSession.shared.user = userData
        try await PortalInstance.shared.initializePortal(clientAPIKey: userData.clientApiKey)
        setState(.loggedIn(user: userData))
        navigateToMainTabBar()
      } catch {
        setState(.error(errorMessage: error.localizedDescription))
      }
    }
  }

  private func postSingIn(_ username: String) async throws -> UserData {
    let payload = ["username": username]
    return try await portalRepository.post("/mobile/login", andPayload: payload, mappingInResponse: UserData.self)
  }
}

// MARK: - Sign up

extension AuthViewModel {
  func signUp(username: String) {
    Task {
      do {
        setState(.loading)
        let userData = try await self.postSingUp(username)
        UserSession.shared.user = userData
        try await PortalInstance.shared.initializePortal(clientAPIKey: userData.clientApiKey)
        setState(.signedUp(user: userData))
        navigateToMainTabBar()
      } catch {
        setState(.error(errorMessage: error.localizedDescription))
      }
    }
  }

  private func postSingUp(_ username: String) async throws -> UserData {
    let payload = ["username": username]
    return try await portalRepository.post("/mobile/signup", andPayload: payload, mappingInResponse: UserData.self)
  }
}

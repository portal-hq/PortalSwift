//
//  ProfileViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation
import UIKit

final class ProfileViewModel: ObservableObject {
  @Published var userData: UserData? = UserSession.shared.user
}

// MARK: - Logout

extension ProfileViewModel {
  func logout() {
    UserSession.shared.user = nil
    PortalInstance.shared.portal = nil
    AppState.shared.sessionMode = .anonymous
  }
}

// MARK: - Copy helpers

extension ProfileViewModel {
  func copyUsernameToClipboard() {
    copyToClipboard(text: userData?.username)
  }

  func copyClientApiKeyToClipboard() {
    copyToClipboard(text: userData?.clientApiKey)
  }

  func copyClientIdToClipboard() {
    copyToClipboard(text: userData?.clientId)
  }

  func copyExchangeUserIdToClipboard() {
    copyToClipboard(text: userData?.exchangeUserId.description)
  }

  private func copyToClipboard(text: String?) {
    UIPasteboard.general.string = text
  }
}

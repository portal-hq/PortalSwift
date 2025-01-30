//
//  AuthView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct AuthView: View {
  // ViewModel
  @ObservedObject private var viewModel = AuthViewModel()

  // Properties
  @State private var username: String = ""

  var body: some View {
    VStack {
      Image("portal-logo")
        .resizable()
        .frame(width: 100, height: 100)
        .padding([.top, .bottom], 50)

      PortalTextField(placeholder: "username", text: $username)

      HStack {
        PortalButton(title: "Sign In", isEnabled: username.count >= 4) {
          viewModel.signIn(username: username)
        }

        PortalButton(title: "Sign Up", isEnabled: username.count >= 4) {
          viewModel.signUp(username: username)
        }
      }
      .frame(height: 40)

      switch viewModel.authState {
      case .none:
        EmptyView()
      case .loading:
        ProgressView()
      case .signedUp(user: let user):
        Text("Signed up as \(user.username)")
      case let .loggedIn(user: userData):
        Text("Logged in as \(userData.username)")
      case .error(errorMessage: let errorMessage):
        Text(errorMessage)
      }

      Spacer()
    }
    .padding([.leading, .trailing])
  }
}

#Preview {
  AuthView()
}

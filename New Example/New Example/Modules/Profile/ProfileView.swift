//
//  ProfileView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct ProfileView: View {
  @ObservedObject private var viewModel = ProfileViewModel()

  var body: some View {
    VStack {
      HStack {
        Text("username:")
          .font(.headline)
          .bold()
        Text(viewModel.userData?.username ?? "")
        Spacer()
        Button {
          viewModel.copyUsernameToClipboard()
        } label: {
          Image(systemName: "doc.on.doc")
        }
      }

      Rectangle()
        .frame(height: 1)

      HStack {
        Text("clientApiKey:")
          .font(.headline)
          .bold()
        Text(viewModel.userData?.clientApiKey ?? "")
        Spacer()
        Button {
          viewModel.copyClientApiKeyToClipboard()
        } label: {
          Image(systemName: "doc.on.doc")
        }
      }

      Rectangle()
        .frame(height: 1)

      HStack {
        Text("clientId:")
          .font(.headline)
          .bold()
        Text(viewModel.userData?.clientId ?? "")
        Spacer()
        Button {
          viewModel.copyClientIdToClipboard()
        } label: {
          Image(systemName: "doc.on.doc")
        }
      }

      Rectangle()
        .frame(height: 1)

      HStack {
        Text("exchangeUserId:")
          .font(.headline)
          .bold()
        Text("\(viewModel.userData?.exchangeUserId ?? 0)")
        Spacer()
        Button {
          viewModel.copyExchangeUserIdToClipboard()
        } label: {
          Image(systemName: "doc.on.doc")
        }
      }

      PortalButton(title: "logout", style: .negative) {
        viewModel.logout()
      }
      .frame(height: 40)
      .padding(.top)

      Spacer()
    }
    .padding()
  }
}

#Preview {
  ProfileView()
}

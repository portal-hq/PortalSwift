//
//  MainTabBar.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct MainTabBar: View {
  var body: some View {
    TabView {
      Tab("Home", systemImage: "wallet.bifold.fill") {
        HomeView()
      }

      Tab("Transaction", systemImage: "paperplane.fill") {
        TransactionsView()
      }

      Tab("Profile", systemImage: "person.crop.circle") {
        ProfileView()
      }

      Tab("Settings", systemImage: "gear") {
        SettingsView()
      }
    }
  }
}

#Preview {
  MainTabBar()
}

//
//  SettingsView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct SettingsView: View {
  // ViewModel
  @ObservedObject private var viewModel = SettingsViewModel()

  var body: some View {
    NavigationView {
      List {
        NavigationLink("App Configuration") {
          AppConfigView()
        }

        NavigationLink("GDrive Settings") {
          GDriveSettings()
        }

        Text("More settings coming soon...")
          .multilineTextAlignment(.center)
      }
    }
  }
}

#Preview {
  SettingsView()
}

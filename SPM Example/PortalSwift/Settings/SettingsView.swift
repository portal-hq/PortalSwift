//
//  SettingsView.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 05/12/2024.
//  Copyright © 2024 Portal. All rights reserved.
//

import PortalSwift
import SwiftUI

@available(iOS 17.0, *)
struct SettingsView: View {
  var portal: PortalProtocol?

  @State var gdriveBackupOption: Int = 0
  @State var environment: Environment = .staging

  var body: some View {
    VStack(spacing: 8) {
      VStack {
        HStack {
          Text("GDrive Option:")

          Spacer()

          Picker("GDrive Backup Option", selection: self.$gdriveBackupOption) {
            Text("appDataFolder").tag(0)
            Text("appDataFolderWithFallback").tag(1)
            Text("gdriveFolder").tag(2)
          }
          .pickerStyle(DefaultPickerStyle())
          .padding([.horizontal, .top])
        }

        if self.portal == nil {
          Text("Please init Portal to change the GDrive Option.")
            .foregroundColor(.red)
            .font(.caption)
        }
      }
      .disabled(self.portal == nil)
      .padding(.bottom, 20)

      VStack {
        HStack {
          Text("Environment:")

          Spacer()

          Picker("Environment", selection: self.$environment) {
            Text("Production").tag(Environment.production)
            Text("Staging").tag(Environment.staging)
            Text("Localhost").tag(Environment.localHost)
          }
          .pickerStyle(DefaultPickerStyle())
          .padding([.horizontal, .top])
        }

        if self.portal != nil {
          Text("Please sign out to be able to change the Environment.")
            .foregroundColor(.red)
            .font(.caption)
        }
      }
      .disabled(self.portal != nil)
      .padding(.bottom, 20)

      Toggle("Is Account Abstracted", isOn: Binding(
        get: { Settings.shared.isAccountAbstracted },
        set: { Settings.shared.isAccountAbstracted = $0 }
      ))

      Spacer()
    }
    .padding(.horizontal)
    .onAppear {
      if Settings.shared.portalConfig.gdriveBackupOption == .appDataFolder {
        gdriveBackupOption = 0
      } else if Settings.shared.portalConfig.gdriveBackupOption == .appDataFolderWithFallback {
        gdriveBackupOption = 1
      } else {
        gdriveBackupOption = 2
      }
      environment = Settings.shared.portalConfig.environment
    }
    .onChange(of: self.gdriveBackupOption) { oldValue, newValue in
      do {
        let gdriveClientId = Settings.shared.portalConfig.appConfig?.googleClientId ?? ""
        if newValue == 0 { // appDataFolder
          try portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .appDataFolder)
          Settings.shared.portalConfig.gdriveBackupOption = .appDataFolder
        } else if newValue == 1 { // appDataFolderWithFallback
          try portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .appDataFolderWithFallback)
          Settings.shared.portalConfig.gdriveBackupOption = .appDataFolderWithFallback
        } else if newValue == 2 { // gdriveFolder
          try portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .gdriveFolder(folderName: "_PORTAL_MPC_DO_NOT_DELETE_"))
          Settings.shared.portalConfig.gdriveBackupOption = .gdriveFolder(folderName: "_PORTAL_MPC_DO_NOT_DELETE_")
        }
      } catch {
        print("App Settings: failed to config GDrive")
        self.gdriveBackupOption = oldValue
      }
    }
    .onChange(of: self.environment) { oldValue, newValue in
      print("Environment changed from: \(oldValue) to \(newValue)")
      Settings.shared.portalConfig.environment = newValue
      Settings.shared.loadApplicationConfig() // To refresh the Example App Environment Config
    }
  }
}

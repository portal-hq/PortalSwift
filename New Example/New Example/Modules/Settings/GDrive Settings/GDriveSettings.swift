//
//  GDriveSettings.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct GDriveSettings: View {
    @State var gdriveBackupOption: Int = 0

    var body: some View {
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
          .padding()
        }

        Spacer()
      }
      .onAppear {
        if AppSettings.shared.gdriveBackupOption == .appDataFolder {
          gdriveBackupOption = 0
        } else if AppSettings.shared.gdriveBackupOption == .appDataFolderWithFallback {
          gdriveBackupOption = 1
        } else {
          gdriveBackupOption = 2
        }
      }
      .onChange(of: self.gdriveBackupOption) { oldValue, newValue in
        do {
            let gdriveClientId = AppSettings.Config.googleClientId
          if newValue == 0 { // appDataFolder
            try PortalInstance.shared.portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .appDataFolder)
              AppSettings.shared.gdriveBackupOption = .appDataFolder
          } else if newValue == 1 { // appDataFolderWithFallback
            try PortalInstance.shared.portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .appDataFolderWithFallback)
              AppSettings.shared.gdriveBackupOption = .appDataFolderWithFallback
          } else if newValue == 2 { // gdriveFolder
            try PortalInstance.shared.portal?.setGDriveConfiguration(clientId: gdriveClientId, backupOption: .gdriveFolder(folderName: "_PORTAL_MPC_DO_NOT_DELETE_"))
              AppSettings.shared.gdriveBackupOption = .gdriveFolder(folderName: "_PORTAL_MPC_DO_NOT_DELETE_")
          }
        } catch {
          print("App Settings: failed to config GDrive")
          self.gdriveBackupOption = oldValue
        }
      }
    }
  }

#Preview {
    GDriveSettings()
}

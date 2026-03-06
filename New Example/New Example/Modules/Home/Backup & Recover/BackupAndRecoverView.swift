//
//  BackupAndRecoverView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct BackupAndRecoverView: View {
  /// <#Description#>
  var body: some View {
    VStack {
      HStack {
        PortalButton(title: "Password Backup") {
          print("Password Backup")
        }

        PortalButton(title: "Password Recover") {
          print("Password Recover")
        }
      }
      .frame(height: 40)

      HStack {
        PortalButton(title: "Passkey Backup") {
          print("Passkey Backup")
        }

        PortalButton(title: "Passkey Recover") {
          print("Passkey Recover")
        }
      }
      .frame(height: 40)

      HStack {
        PortalButton(title: "GDrive Backup") {
          print("GDrive Backup")
        }

        PortalButton(title: "GDrive Recover") {
          print("GDrive Recover")
        }
      }
      .frame(height: 40)

      HStack {
        PortalButton(title: "iCloud Backup") {
          print("iCloud Backup")
        }

        PortalButton(title: "iCloud Recover") {
          print("iCloud Recover")
        }
      }
      .frame(height: 40)

      HStack {
        PortalButton(title: "Firebase Backup") {
          print("Firebase Backup")
          // To use Firebase backup:
          // 1. Add FirebaseAuth SDK to your project
          // 2. Register FirebaseStorage with a getToken callback:
          //
          //    portal.registerBackupMethod(.Firebase, withStorage: FirebaseStorage(
          //      getToken: {
          //        return try await Auth.auth().currentUser?.getIDToken()
          //      }
          //    ))
          //
          // 3. Call portal.backupWallet(.Firebase)
        }

        PortalButton(title: "Firebase Recover") {
          print("Firebase Recover")
          // To use Firebase recovery:
          // 1. Ensure FirebaseStorage is registered (same as backup setup)
          // 2. Call portal.recoverWallet(.Firebase)
          // 3. The SDK will fetch the encryption key from TBS using Firebase auth
        }
      }
      .frame(height: 40)

      HStack {
        PortalButton(title: "Firebase Eject") {
          print("Firebase Eject")
          // To use Firebase eject:
          // 1. Ensure FirebaseStorage is registered (same as backup setup)
          // 2. Call portal.eject(.Firebase)
          // 3. The SDK will fetch the encryption key from TBS, decrypt the backup,
          //    and return the private key
        }
        Spacer()
      }
      .frame(height: 40)
    }
  }
}

#Preview {
  BackupAndRecoverView()
}

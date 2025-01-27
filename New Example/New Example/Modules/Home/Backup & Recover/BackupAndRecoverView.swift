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
        }
    }
}

#Preview {
    BackupAndRecoverView()
}

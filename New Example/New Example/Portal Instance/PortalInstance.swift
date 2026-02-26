//
//  PortalInstance.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import PortalSwift

class PortalInstance {
  static let shared = PortalInstance()

  var portal: Portal?

  private init() {}
}

// MARK: - Initialize Portal

extension PortalInstance {
  func initializePortal(clientAPIKey: String) async throws {
    // Initialize Portal SDK
    portal = try Portal(
      clientAPIKey,
      featureFlags: FeatureFlags(isMultiBackupEnabled: true),
      apiHost: AppSettings.Config.apiUrl,
      mpcHost: AppSettings.Config.mpcUrl
    )

    portal?.on(event: Events.PortalSigningRequested.rawValue, callback: { [weak portal] data in
      portal?.emit(Events.PortalSigningApproved.rawValue, data: data)
    })

    // MARK: - Firebase Backup Setup (Example)
    //
    // To enable Firebase backup, register FirebaseStorage with a getToken callback
    // that returns a fresh Firebase ID token from the currently signed-in user.
    //
    // Prerequisites:
    // 1. Add FirebaseAuth SDK to your project (via SPM or CocoaPods)
    // 2. Configure your Firebase project in the Portal dashboard
    //    (POST /api/v1/custodians/{id}/jwt-provider with provider: "firebase")
    // 3. Ensure users sign in with Firebase before performing backup/recovery
    //
    // Example registration:
    //
    //   import FirebaseAuth
    //
    //   portal?.registerBackupMethod(.Firebase, withStorage: FirebaseStorage(
    //     getToken: {
    //       // This callback is called before each TBS request.
    //       // It should return a fresh Firebase ID token.
    //       // Firebase SDKs cache tokens and auto-refresh them.
    //       return try await Auth.auth().currentUser?.getIDToken()
    //     }
    //   ))
    //
    // Then use backup/recovery/eject:
    //   let backup = try await portal?.backupWallet(.Firebase)
    //   let recovery = try await portal?.recoverWallet(.Firebase)
    //   let privateKeys = try await portal?.ejectPrivateKeys(.Firebase)
  }
}

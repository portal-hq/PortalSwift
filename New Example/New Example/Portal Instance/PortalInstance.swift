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
  }
}

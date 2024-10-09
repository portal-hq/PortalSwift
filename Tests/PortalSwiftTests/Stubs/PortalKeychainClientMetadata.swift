//
//  PortalKeychainClientMetadata.swift
//
//
//  Created by Ahmed Ragab on 07/09/2024.
//

import Foundation
@testable import PortalSwift

// Stub for PortalKeychainClientMetadata
extension PortalKeychainClientMetadata {
  static func stub(
    id: String = "stub-id",
    addresses: [PortalNamespace: String?]? = [.eip155: "stub-address"],
    custodian: ClientResponseCustodian = .stub(),
    wallets: [PortalCurve: PortalKeychainClientMetadataWallet]? = [.ED25519: .stub()]
  ) -> PortalKeychainClientMetadata {
    return PortalKeychainClientMetadata(
      id: id,
      addresses: addresses,
      custodian: custodian,
      wallets: wallets
    )
  }
}

// Stub for PortalKeychainClientMetadataWallet
extension PortalKeychainClientMetadataWallet {
  static func stub(
    id: String = "stub-wallet-id",
    curve: PortalCurve = .ED25519,
    publicKey: String = "stub-public-key",
    backupShares: [PortalKeychainClientMetadataWalletBackupShare] = [.stub()],
    signingShares: [PortalKeychainClientMetadataWalletShare] = [.stub()]
  ) -> PortalKeychainClientMetadataWallet {
    return PortalKeychainClientMetadataWallet(
      id: id,
      curve: curve,
      publicKey: publicKey,
      backupShares: backupShares,
      signingShares: signingShares
    )
  }
}

// Stub for PortalKeychainClientMetadataWalletBackupShare
extension PortalKeychainClientMetadataWalletBackupShare {
  static func stub(
    backupMethod: BackupMethods = .GoogleDrive,
    createdAt: String = "2024-09-07T00:00:00Z",
    id: String = "stub-backup-id",
    status: PortalSharePairStatus = .completed
  ) -> PortalKeychainClientMetadataWalletBackupShare {
    return PortalKeychainClientMetadataWalletBackupShare(
      backupMethod: backupMethod,
      createdAt: createdAt,
      id: id,
      status: status
    )
  }
}

// Stub for PortalKeychainClientMetadataWalletShare
extension PortalKeychainClientMetadataWalletShare {
  static func stub(
    createdAt: String = "2024-09-07T00:00:00Z",
    id: String = "stub-signing-share-id",
    status: PortalSharePairStatus = .completed
  ) -> PortalKeychainClientMetadataWalletShare {
    return PortalKeychainClientMetadataWalletShare(
      createdAt: createdAt,
      id: id,
      status: status
    )
  }
}

// Stub for PortalMpcGeneratedShare
extension PortalMpcGeneratedShare {
  static func stub(
    id: String = "stub-share-id",
    share: String = "stub-share-data"
  ) -> PortalMpcGeneratedShare {
    return PortalMpcGeneratedShare(
      id: id,
      share: share
    )
  }
}

// Stub for PortalMpcGenerateResponse
extension PortalMpcGenerateResponse where Value == PortalMpcGeneratedShare {
  static func stub() -> PortalMpcGenerateResponse {
    return ["stub-key": PortalMpcGeneratedShare.stub()]
  }
}

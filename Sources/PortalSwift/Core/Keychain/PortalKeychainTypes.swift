public struct PortalKeychainClientMetadata: Codable {
  public var id: String
  public var addresses: [PortalNamespace: String?]?
  public var custodian: ClientResponseCustodian
  public var wallets: [PortalCurve: PortalKeychainClientMetadataWallet]?
}

public struct PortalKeychainClientMetadataWallet: Codable {
  public let id: String
  public let curve: PortalCurve
  public let publicKey: String
  public let backupShares: [PortalKeychainClientMetadataWalletBackupShare]
  public let signingShares: [PortalKeychainClientMetadataWalletShare]
}

public struct PortalKeychainClientMetadataWalletBackupShare: Codable {
  public let backupMethod: BackupMethods
  public let createdAt: String
  public let id: String
  public let status: PortalSharePairStatus
}

public struct PortalKeychainClientMetadataWalletShare: Codable {
  public let createdAt: String
  public let id: String
  public let status: PortalSharePairStatus
}

typealias PortalKeychainClientShares = PortalMpcGenerateResponse

public struct PortalKeychainMetadata {
  public var namespaces: [PortalNamespace: PortalCurve]
}

import Foundation

public struct AnyEncodable: Encodable {
  let value: Encodable

  public init(_ value: Encodable) {
    self.value = value
  }

  public init(_ value: Any) throws {
    guard let encodableValue = value as? Encodable else {
      throw AnyEncodableError.typeNotEncodable(type(of: value))
    }
    self.value = encodableValue
  }

  public func encode(to encoder: Encoder) throws {
    try self.value.encode(to: encoder)
  }
}

public enum AnyEncodableError: LocalizedError {
  case typeNotEncodable(Any.Type)
}

public typealias PortalCreateWalletResponse = (ethereum: String, solana: String)
public typealias PortalRecoverWalletResponse = (ethereum: String, solana: String?)

public struct PortalBackupWalletResponse {
  public let cipherText: String
  public let storageCallback: () async throws -> Void
}

/*********************************************
 * Legacy stuff - consider replacing these
 *********************************************/
public struct FeatureFlags {
  public var isMultiBackupEnabled: Bool?
  public var useEnclaveMPCApi: Bool?

  public init(
    isMultiBackupEnabled: Bool? = nil,
    useEnclaveMPCApi: Bool? = nil
  ) {
    self.isMultiBackupEnabled = isMultiBackupEnabled
    self.useEnclaveMPCApi = useEnclaveMPCApi
  }
}

public struct BackupConfigs {
  public var passwordStorage: PasswordStorageConfig?

  public init(passwordStorage: PasswordStorageConfig? = nil) {
    self.passwordStorage = passwordStorage
  }
}

public struct PasswordStorageConfig {
  public var password: String

  public enum PasswordStorageError: LocalizedError {
    case invalidLength
  }

  public init(password: String) throws {
    if password.count < 4 {
      throw PasswordStorageError.invalidLength
    }
    self.password = password
  }
}

/// A struct with the backup options (gdrive and/or icloud) initialized.
public struct BackupOptions {
  public var gdrive: GDriveStorage?
  public var icloud: ICloudStorage?
  public var passwordStorage: PasswordStorage?
  public var local: LocalFileStorage?

  public var _passkeyStorage: Any?

  @available(iOS 16, *)
  var passkeyStorage: PasskeyStorage? {
    get { return self._passkeyStorage as? PasskeyStorage }
    set { self._passkeyStorage = newValue }
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  @available(iOS 16, *)
  public init(gdrive: GDriveStorage? = nil, icloud: ICloudStorage? = nil, passwordStorage: PasswordStorage? = nil, passkeyStorage: PasskeyStorage? = nil) {
    self.gdrive = gdrive
    self.icloud = icloud
    self.passwordStorage = passwordStorage
    self.passkeyStorage = passkeyStorage
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(gdrive: GDriveStorage? = nil, icloud: ICloudStorage? = nil, passwordStorage: PasswordStorage? = nil) {
    self.gdrive = gdrive
    self.icloud = icloud
    self.passwordStorage = passwordStorage
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  public init(gdrive: GDriveStorage) {
    self.gdrive = gdrive
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(icloud: ICloudStorage) {
    self.icloud = icloud
  }

  public init(local: LocalFileStorage) {
    self.local = local
  }

  public init(passwordStorage: PasswordStorage) {
    self.passwordStorage = passwordStorage
  }

  /// Create the backup options for PortalSwift.
  /// - Parameter gdrive: The instance of GDriveStorage to use for backup.
  /// - Parameter icloud: The instance of ICloudStorage to use for backup.
  public init(gdrive: GDriveStorage, icloud: ICloudStorage, passwordStorage: PasswordStorage) {
    self.gdrive = gdrive
    self.icloud = icloud
    self.passwordStorage = passwordStorage
  }

  subscript(key: String) -> Any? {
    switch key {
    case BackupMethods.GoogleDrive.rawValue:
      return self.gdrive
    case BackupMethods.iCloud.rawValue:
      return self.icloud
    case BackupMethods.local.rawValue:
      return self.local
    case BackupMethods.Password.rawValue:
      return self.passwordStorage
    case BackupMethods.Passkey.rawValue:
      return self._passkeyStorage
    default:
      return nil
    }
  }
}

// Define the structure for the header of the message
public struct SolanaHeader: Codable {
  public var numRequiredSignatures: Int
  public var numReadonlySignedAccounts: Int
  public var numReadonlyUnsignedAccounts: Int
}

public struct SendAssetParams: Codable {
  /// to: The recipient's address
  public let to: String
  /// amount: The amount to send as a string
  public let amount: String
  /// token: The token to send (use "NATIVE" for chain's native token)
  public let token: String
  /// signatureApprovalMemo: Optional signature approval memo to use for the request.
  public let signatureApprovalMemo: String?
  /// sponsorGas: Optional flag to `enable/disable` sponsor the gas,  to be used for the send asset request.
  public var sponsorGas: Bool?

  /// Initializes parameters for sending an asset.
  /// - Parameters:
  ///   - to: The recipient's address
  ///   - amount: The amount to send as a string
  ///   - token: The token to send (use "NATIVE" for chain's native token)
  ///   - signatureApprovalMemo: Optional signature approval memo to use for the request.
  ///   - sponsorGas: Optional flag to `enable/disable` sponsor the gas, to be used for the send asset request.
  public init(
    to: String,
    amount: String,
    token: String,
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil
  ) {
    self.to = to
    self.amount = amount
    self.token = token
    self.signatureApprovalMemo = signatureApprovalMemo
    self.sponsorGas = sponsorGas
  }
}

public struct SendAssetResponse: Codable {
  public let txHash: String
}

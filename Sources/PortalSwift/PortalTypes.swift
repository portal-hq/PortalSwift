import Foundation
import SolanaSwift

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
  public var useEnclaveSigner: Bool?

  public init(
    isMultiBackupEnabled: Bool? = nil,
    useEnclaveSigner: Bool? = nil
  ) {
    self.isMultiBackupEnabled = isMultiBackupEnabled
    self.useEnclaveSigner = useEnclaveSigner
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

// Solana Types
public struct SolanaRequest: Codable {
  public var signatures: [String]?
  public var message: SolanaMessage
}

// Define the structure for the header of the message
public struct SolanaHeader: Codable {
  public var numRequiredSignatures: Int
  public var numReadonlySignedAccounts: Int
  public var numReadonlyUnsignedAccounts: Int
}

// Define the structure for an instruction within the message
public struct SolanaInstruction: Codable {
  public var programIdIndex: UInt8
  public var accounts: [Int]
  public var data: String

  public init(from instruction: SolanaSwift.CompiledInstruction) {
    self.accounts = instruction.accounts
    self.data = SolanaSwift.Base58.encode(instruction.data)
    self.programIdIndex = instruction.programIdIndex
  }
}

// Define the main structure of the message
public struct SolanaMessage: Codable {
  public var accountKeys: [String]
  public var header: SolanaHeader
  public var recentBlockhash: String
  public var instructions: [SolanaInstruction]
}

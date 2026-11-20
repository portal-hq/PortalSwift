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
  public var usePresignatures: Bool?
  public var usePreGeneratedWallet: Bool?

  public init(
    isMultiBackupEnabled: Bool? = nil,
    useEnclaveMPCApi: Bool? = nil,
    usePresignatures: Bool? = nil,
    usePreGeneratedWallet: Bool? = nil
  ) {
    self.isMultiBackupEnabled = isMultiBackupEnabled
    self.useEnclaveMPCApi = useEnclaveMPCApi
    self.usePresignatures = usePresignatures
    self.usePreGeneratedWallet = usePreGeneratedWallet
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
  /// traceId: Optional trace ID for request tracing. If not provided, a trace ID is generated
  /// at the start of `sendAsset` and shared across all underlying build/sign/broadcast requests.
  public var traceId: String?
  /// idempotencyKey: Optional key that stops Portal from broadcasting the same transfer twice, on
  /// EVM and Solana chains. It is forwarded to the underlying `eth_sendTransaction` or
  /// `sol_signAndSendTransaction` and follows the rules of `RequestOptions.idempotencyKey`:
  /// surrounding whitespace is trimmed, and the key must then be 1–255 characters of
  /// `A-Z a-z 0-9 . _ ~ -`, otherwise `sendAsset` throws `PortalIdempotencyError.invalidKey` before
  /// the transaction is built. On a Bitcoin chain, whose broadcast cannot be protected yet, a key
  /// throws `PortalIdempotencyError.unsupportedTarget` before anything is built or signed.
  ///
  /// `sendAsset` builds the transaction again on every call, and Portal compares the transaction
  /// it is asked to send with the one first sent under the key. When the rebuilt transaction
  /// differs, a retry with the same key is rejected with `IDEMPOTENCY_KEY_REUSED`
  /// (`PortalMpcError.isIdempotencyKeyReused`) whatever state the first request is in, so that
  /// answer does not tell you whether the first request is still in progress, completed or failed.
  /// On Solana this is the usual outcome, because each build carries a new recent blockhash. An
  /// EVM build normally matches the first one, so the retry gets the first request's status
  /// instead. Either way the transfer is not broadcast twice under this key.
  ///
  /// No rejection returns the original transaction hash. Before retrying with a new key, confirm
  /// on-chain that the first transfer did not land. On Solana, wait until the first transfer is
  /// confirmed or its recent blockhash has expired, about 60–90 seconds after the transaction was
  /// built, because a transfer that is still in flight can land after you check. On EVM, wait until
  /// the first transfer is confirmed or the account nonce has moved past it. For the most
  /// predictable retries, build the transaction once and call `request` with `eth_sendTransaction`
  /// or `sol_signAndSendTransaction` and the same key on every attempt: a retry then gets the first
  /// request's status, including `IDEMPOTENT_REQUEST_IN_PROGRESS`.
  ///
  /// Where Portal enforces the key, and how long it remembers it, is described on
  /// `RequestOptions.idempotencyKey`.
  public var idempotencyKey: String?

  /// Initializes parameters for sending an asset.
  /// - Parameters:
  ///   - to: The recipient's address
  ///   - amount: The amount to send as a string
  ///   - token: The token to send (use "NATIVE" for chain's native token)
  ///   - signatureApprovalMemo: Optional signature approval memo to use for the request.
  ///   - sponsorGas: Optional flag to `enable/disable` sponsor the gas, to be used for the send asset request.
  ///   - traceId: Optional trace ID for request tracing. If not provided, one is generated automatically.
  ///   - idempotencyKey: Optional key that stops Portal from broadcasting the same transfer twice
  ///     (EVM and Solana only). See `idempotencyKey` for how retries behave.
  public init(
    to: String,
    amount: String,
    token: String,
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    traceId: String? = nil,
    idempotencyKey: String? = nil
  ) {
    self.to = to
    self.amount = amount
    self.token = token
    self.signatureApprovalMemo = signatureApprovalMemo
    self.sponsorGas = sponsorGas
    self.traceId = traceId
    self.idempotencyKey = idempotencyKey
  }
}

public struct SendAssetResponse: Codable {
  public let txHash: String
}

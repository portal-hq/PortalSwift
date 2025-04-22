//
//  PortalProtocol.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 31/01/2025.
//
import AuthenticationServices
import UIKit

public protocol PortalProtocol {
  // Properties
  var addresses: [PortalNamespace: String?] { get async throws }
  var client: ClientResponse? { get async throws }
  var chainId: Int? { get }
  var api: PortalApiProtocol { get }
  var autoApprove: Bool { get }
  var gatewayConfig: [Int: String] { get set }
  var provider: PortalProviderProtocol { get }
  var rpcConfig: [String: String] { get set }
  var apiKey: String { get }

  // Deprecated Properties
  @available(*, deprecated, renamed: "addresses", message: "Please use the async getter for `addresses`")
  var address: String? { get }

  // Initializers
  init(
    _ apiKey: String,
    withRpcConfig: [String: String],
    autoApprove: Bool,
    featureFlags: FeatureFlags?,
    version: String,
    apiHost: String,
    mpcHost: String,
    enclaveMPCHost: String,
    api: PortalApiProtocol?,
    binary: Mobile?,
    gDrive: GDriveStorage?,
    iCloud: ICloudStorage?,
    keychain: PortalKeychainProtocol?,
    mpc: PortalMpcProtocol?,
    passwords: PasswordStorage?
  ) throws

  // Deprecated Initializer
  @available(*, deprecated, renamed: "Portal", message: "We've updated our constructor to be more streamlined and support multiple wallets. Please see the migration guide at https://docs.portalhq.io/resources/migrating-from-v3-to-v4/")
  init(
    apiKey: String,
    backup: BackupOptions,
    chainId: Int,
    keychain: PortalKeychainProtocol,
    gatewayConfig: [Int: String],
    isSimulator: Bool,
    version: String,
    autoApprove: Bool,
    apiHost: String,
    mpcHost: String,
    featureFlags: FeatureFlags?
  ) throws

  // Public functions
  func registerBackupMethod(_ method: BackupMethods, withStorage: PortalStorage)
  func setGDriveConfiguration(clientId: String, backupOption: GDriveBackupOption) throws
  func setGDriveView(_ view: UIViewController) throws
  @available(iOS 16, *)
  func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws
  @available(iOS 16, *)
  func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws
  func setPassword(_ value: String) throws
  func backupWallet(_ method: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> (cipherText: String, storageCallback: () async throws -> Void)
  func createWallet(usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> PortalCreateWalletResponse
  func createSolanaWallet(usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> String
  func eject(_ method: BackupMethods, withCipherText: String?, andOrganizationBackupShare: String?) async throws -> String
  func ejectPrivateKeys(_ method: BackupMethods, withCipherText: String?, andOrganizationBackupShare: String?, andOrganizationSolanaBackupShare: String?) async throws -> [PortalNamespace: String]
  func recoverWallet(_ method: BackupMethods, withCipherText: String?, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> PortalRecoverWalletResponse
  func generateSolanaWalletAndBackupShares(_ method: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> (solanaAddress: String, cipherText: String, storageCallback: () async throws -> Void)
  func deleteShares() async throws
  func getAddress(_ forChainId: String) async -> String?
  func getAddresses() async throws -> [PortalNamespace: String?]
  func emit(_ event: Events, data: Any)
  func on(event: Events, callback: @escaping (Any) -> Void)
  func once(event: Events, callback: @escaping (Any) -> Void)
  func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [Any]) async throws -> PortalProviderResult
  func getRpcUrl(forChainId: String) async -> String?
  func availableRecoveryMethods(_ forChainId: String?) async throws -> [BackupMethods]
  func doesWalletExist(_ forChainId: String?) async throws -> Bool
  func isWalletBackedUp(_ forChainId: String?) async throws -> Bool
  func isWalletOnDevice(_ forChainId: String?) async throws -> Bool
  func isWalletRecoverable(_ forChainId: String?) async throws -> Bool
  func getBalances(_ chainId: String) async throws -> [FetchedBalance]
  func getAssets(_ chainId: String) async throws -> AssetsResponse
  func getBackupShares(_ chainId: String?) async throws -> [FetchedSharePair]
  func getNftAssets(_ chainId: String) async throws -> [NftAsset]
  func getSigningShares(_ chainId: String?) async throws -> [FetchedSharePair]
  func getTransactions(_ chainId: String, limit: Int?, offset: Int?, order: TransactionOrder?) async throws -> [FetchedTransaction]
  func evaluateTransaction(chainId: String, transaction: EvaluateTransactionParam, operationType: EvaluateTransactionOperationType?) async throws -> BlockaidValidateTrxRes
  func buildEip155Transaction(chainId: String, params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse
  func buildSolanaTransaction(chainId: String, params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse
  func getWalletCapabilities() async throws -> WalletCapabilitiesResponse
  func provisionWallet(cipherText: String, method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  func ethEstimateGas(transaction: ETHTransactionParam, completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func ethGasPrice(completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func ethGetBalance(completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func ethSendTransaction(transaction: ETHTransactionParam, completion: @escaping (Result<TransactionCompletionResult>) -> Void)
  func ethSign(message: String, completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func ethSignTransaction(transaction: ETHTransactionParam, completion: @escaping (Result<TransactionCompletionResult>) -> Void)
  func ethSignTypedDataV3(message: String, completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func ethSignTypedData(message: String, completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func personalSign(message: String, completion: @escaping (Result<RequestCompletionResult>) -> Void)
  func rawSign(message: String, chainId: String) async throws -> PortalProviderResult
  func createPortalConnectInstance(webSocketServer: String) throws -> PortalConnect
  func receiveTestnetAsset(chainId: String, params: FundParams) async throws -> FundResponse
  func sendAsset(chainId: String, params: SendAssetParams) async throws -> SendAssetResponse

  // Deprecated functions
  @available(*, deprecated, renamed: "request", message: "Please use the async/await implementation of request().")
  func request(method: ETHRequestMethods.RawValue, params: [Any], completion: @escaping (Result<RequestCompletionResult>) -> Void)
  @available(*, deprecated, message: "Use setGDriveConfiguration(clientId:backupOption:) instead.")
  func setGDriveConfiguration(clientId: String, folderName: String) throws
  @available(*, deprecated, renamed: "evaluateTransaction", message: "Please use evaluateTransaction().")
  func simulateTransaction(_ chainId: String, from: Any) async throws -> SimulatedTransaction
  @available(*, deprecated, renamed: "backupWallet", message: "Please use the async implementation of backupWallet()")
  func backupWallet(method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  @available(*, deprecated, renamed: "createWallet", message: "Please use the async implementation of createWallet()")
  func createWallet(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  @available(*, deprecated, renamed: "recoverWallet", message: "Please use the async implementation of recoverWallet()")
  func recoverWallet(cipherText: String, method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  @available(*, deprecated, renamed: "eject", message: "Please use the async implementation of eject()")
  func ejectPrivateKey(clientBackupCiphertext: String, method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, orgBackupShare: String, completion: @escaping (Result<String>) -> Void)
  @available(*, deprecated, message: "Use request(_:withMethod:andParams:) with a default value for andParams instead.")
  func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [Any]?) async throws -> PortalProviderResult
  @available(*, deprecated, message: "Use request(_:withMethod:andParams:) with PortalRequestMethod instead of String.")
  func request(_ chainId: String, withMethod: String, andParams: [Any]) async throws -> PortalProviderResult
  @available(*, deprecated, renamed: "REMOVED", message: "The PortalProvider class will be chain agnostic very soon. Please update to the chainId-specific implementations of all Provider helper methods as this function will be removed in the future.")
  func setChainId(to: Int) throws
  @available(*, deprecated, renamed: "REMOVED", message: "The PortalKeychain now manages metadata internally based on Portal's server state. This function will be removed in the future.")
  func deleteAddress() throws
  @available(*, deprecated, renamed: "deleteShares", message: "The Portal SDK is now multi-wallet. Please update to the multi-wallet-compatible deleteShares() as this function will be removed in the future.")
  func deleteSigningShare() throws
  @available(*, deprecated, renamed: "sendAsset", message: "Please use sendAsset().")
  func sendSol(_ lamports: UInt64, to: String, withChainId chainId: String) async throws -> String
  @available(*, deprecated, message: "Use emit(_ event: Events, data: Any) instead")
  func emit(_ event: Events.RawValue, data: Any)
  @available(*, deprecated, message: "Use on(event: Events, callback: @escaping (Any) -> Void) instead")
  func on(event: Events.RawValue, callback: @escaping (Any) -> Void)
  @available(*, deprecated, message: "Use once(event: Events, callback: @escaping (Any) -> Void) instead")
  func once(event: Events.RawValue, callback: @escaping (Any) -> Void)
}

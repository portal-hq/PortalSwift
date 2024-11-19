//
//  PortalMpcSpy.swift
//
//
//  Created by Ahmed Ragab on 21/08/2024.
//

import AuthenticationServices
@testable import PortalSwift

class PortalMpcSpy: PortalMpcProtocol {
  // Backup method tracking
  var backupCallsCount: Int = 0
  var backupMethodParam: PortalSwift.BackupMethods?
  var backupUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Eject method tracking
  var ejectCallsCount: Int = 0
  var ejectMethodParam: PortalSwift.BackupMethods?
  var ejectCipherTextParam: String?
  var ejectOrganizationBackupShareParam: String?
  var ejectOrganizationSolanaBackupShareParam: String?
  var ejectUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Generate method tracking
  var generateCallsCount: Int = 0
  var generateUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?
  var generateResponse: [PortalSwift.PortalNamespace: String?] = [
    .eip155: MockConstants.mockEip155Address,
    .solana: MockConstants.mockSolanaAddress
  ]

  // Recover method tracking
  var recoverCallsCount: Int = 0
  var recoverMethodParam: PortalSwift.BackupMethods?
  var recoverCipherTextParam: String?
  var recoverUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Generate Solana Wallet method tracking
  var generateSolanaWalletCallsCount: Int = 0
  var generateSolanaWalletUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Generate Solana Wallet and Backup Shares method tracking
  var generateSolanaWalletAndBackupSharesCallsCount: Int = 0
  var generateSolanaWalletAndBackupSharesBackupMethodParam: PortalSwift.BackupMethods?
  var generateSolanaWalletAndBackupSharesUsingProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Register Backup Method tracking
  var registerBackupMethodCallsCount: Int = 0
  var registerBackupMethodParam: PortalSwift.BackupMethods?
  var registerBackupMethodStorageParam: PortalSwift.PortalStorage?

  // GDrive Configuration tracking
  var setGDriveConfigurationCallsCount: Int = 0
  var setGDriveConfigurationClientIdParam: String?
  var setGDriveConfigurationFolderNameParam: String?

  // GDrive View tracking
  var setGDriveViewCallsCount: Int = 0
  var setGDriveViewParam: UIViewController?

  // Passkey Authentication Anchor tracking
  var setPasskeyAuthenticationAnchorCallsCount: Int = 0
  var setPasskeyAuthenticationAnchorParam: ASPresentationAnchor?

  // Passkey Configuration tracking
  var setPasskeyConfigurationCallsCount: Int = 0
  var setPasskeyConfigurationRelyingPartyParam: String?
  var setPasskeyConfigurationWebAuthnHostParam: String?

  // Password setting tracking
  var setPasswordCallsCount: Int = 0
  var setPasswordParam: String?

  // Backup method tracking
  var backupWithCompletionCallsCount: Int = 0
  var backupWithCompletionMethodParam: PortalSwift.BackupMethods.RawValue?
  var backupWithCompletionBackupConfigsParam: PortalSwift.BackupConfigs?
  var backupWithCompletionProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Generate with completion tracking
  var generateWithCompletionCallsCount: Int = 0
  var generateWithCompletionProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  // Eject Private Key tracking
  var ejectPrivateKeyCallsCount: Int = 0
  var ejectPrivateKeyCipherTextParam: String?
  var ejectPrivateKeyMethodParam: PortalSwift.BackupMethods.RawValue?
  var ejectPrivateKeyBackupConfigsParam: PortalSwift.BackupConfigs?
  var ejectPrivateKeyOrgBackupShareParam: String?

  // Recover with completion tracking
  var recoverWithCompletionCallsCount: Int = 0
  var recoverWithCompletionCipherTextParam: String?
  var recoverWithCompletionMethodParam: PortalSwift.BackupMethods.RawValue?
  var recoverWithCompletionBackupConfigsParam: PortalSwift.BackupConfigs?
  var recoverWithCompletionProgressCallbackParam: ((PortalSwift.MpcStatus) -> Void)?

  func backup(_ method: PortalSwift.BackupMethods, usingProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> PortalSwift.PortalMpcBackupResponse {
    backupCallsCount += 1
    backupMethodParam = method
    backupUsingProgressCallbackParam = usingProgressCallback
    return PortalMpcBackupResponse(
      cipherText: MockConstants.mockCiphertext,
      shareIds: [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId]
    )
  }

  func eject(_ method: PortalSwift.BackupMethods, withCipherText: String?, andOrganizationBackupShare: String?, andOrganizationSolanaBackupShare: String?, usingProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> [PortalSwift.PortalNamespace: String] {
    ejectCallsCount += 1
    ejectMethodParam = method
    ejectCipherTextParam = withCipherText
    ejectOrganizationBackupShareParam = andOrganizationBackupShare
    ejectOrganizationSolanaBackupShareParam = andOrganizationSolanaBackupShare
    ejectUsingProgressCallbackParam = usingProgressCallback
    return [.eip155: MockConstants.mockEip155Address]
  }

  func generate(withProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> [PortalSwift.PortalNamespace: String?] {
    generateCallsCount += 1
    generateUsingProgressCallbackParam = withProgressCallback
    return generateResponse
  }

  func recover(_ method: PortalSwift.BackupMethods, withCipherText: String?, usingProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> [PortalSwift.PortalNamespace: String?] {
    recoverCallsCount += 1
    recoverMethodParam = method
    recoverCipherTextParam = withCipherText
    recoverUsingProgressCallbackParam = usingProgressCallback
    return [.eip155: MockConstants.mockEip155Address]
  }

  func generateSolanaWallet(usingProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> String {
    generateSolanaWalletCallsCount += 1
    generateSolanaWalletUsingProgressCallbackParam = usingProgressCallback
    return ""
  }

  func generateSolanaWalletAndBackupShares(backupMethod: PortalSwift.BackupMethods, usingProgressCallback: ((PortalSwift.MpcStatus) -> Void)?) async throws -> (solanaAddress: String, backupResponse: PortalSwift.PortalMpcBackupResponse) {
    generateSolanaWalletAndBackupSharesCallsCount += 1
    generateSolanaWalletAndBackupSharesBackupMethodParam = backupMethod
    generateSolanaWalletAndBackupSharesUsingProgressCallbackParam = usingProgressCallback
    return (
      "",
      PortalMpcBackupResponse(
        cipherText: MockConstants.mockCiphertext,
        shareIds: [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId]
      )
    )
  }

  func registerBackupMethod(_ method: PortalSwift.BackupMethods, withStorage: any PortalSwift.PortalStorage) {
    registerBackupMethodCallsCount += 1
    registerBackupMethodParam = method
    registerBackupMethodStorageParam = withStorage
  }

  func setGDriveConfiguration(clientId: String, folderName: String) throws {
    setGDriveConfigurationCallsCount += 1
    setGDriveConfigurationClientIdParam = clientId
    setGDriveConfigurationFolderNameParam = folderName
  }

  func setGDriveView(_ view: UIViewController) throws {
    setGDriveViewCallsCount += 1
    setGDriveViewParam = view
  }

  func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws {
    setPasskeyAuthenticationAnchorCallsCount += 1
    setPasskeyAuthenticationAnchorParam = anchor
  }

  func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws {
    setPasskeyConfigurationCallsCount += 1
    setPasskeyConfigurationRelyingPartyParam = relyingParty
    setPasskeyConfigurationWebAuthnHostParam = webAuthnHost
  }

  func setPassword(_ value: String) throws {
    setPasswordCallsCount += 1
    setPasswordParam = value
  }

  func backup(method: PortalSwift.BackupMethods.RawValue, backupConfigs: PortalSwift.BackupConfigs?, completion _: @escaping (PortalSwift.Result<String>) -> Void, progress: ((PortalSwift.MpcStatus) -> Void)?) {
    backupWithCompletionCallsCount += 1
    backupWithCompletionMethodParam = method
    backupWithCompletionBackupConfigsParam = backupConfigs
    backupWithCompletionProgressCallbackParam = progress
  }

  func generate(completion _: @escaping (PortalSwift.Result<String>) -> Void, progress: ((PortalSwift.MpcStatus) -> Void)?) {
    generateWithCompletionCallsCount += 1
    generateWithCompletionProgressCallbackParam = progress
  }

  func ejectPrivateKey(clientBackupCiphertext: String, method: PortalSwift.BackupMethods.RawValue, backupConfigs: PortalSwift.BackupConfigs?, orgBackupShare: String, completion _: @escaping (PortalSwift.Result<String>) -> Void) {
    ejectPrivateKeyCallsCount += 1
    ejectPrivateKeyCipherTextParam = clientBackupCiphertext
    ejectPrivateKeyMethodParam = method
    ejectPrivateKeyBackupConfigsParam = backupConfigs
    ejectPrivateKeyOrgBackupShareParam = orgBackupShare
  }

  func recover(cipherText: String, method: PortalSwift.BackupMethods.RawValue, backupConfigs: PortalSwift.BackupConfigs?, completion _: @escaping (PortalSwift.Result<String>) -> Void, progress: ((PortalSwift.MpcStatus) -> Void)?) {
    recoverWithCompletionCallsCount += 1
    recoverWithCompletionCipherTextParam = cipherText
    recoverWithCompletionMethodParam = method
    recoverWithCompletionBackupConfigsParam = backupConfigs
    recoverWithCompletionProgressCallbackParam = progress
  }
}

//
//  MockPortalMpc.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import AuthenticationServices
import Foundation

public class MockPortalMpc: PortalMpcProtocol {
  public func backup(
    _: BackupMethods,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> PortalMpcBackupResponse {
    usingProgressCallback?(MpcStatus(status: .done, done: true))
    return PortalMpcBackupResponse(
      cipherText: MockConstants.mockCiphertext,
      shareIds: [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId]
    )
  }

  public func eject(
    _: BackupMethods,
    withCipherText _: String? = nil,
    andOrganizationBackupShare _: String? = nil,
    andOrganizationSolanaBackupShare _: String? = nil
  ) async throws -> [PortalNamespace: String] {
    return [
      .eip155: MockConstants.mockEip155EjectedPrivateKey,
      .solana: MockConstants.mockSolanaPrivateKey
    ]
  }

  public func generate(withProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> [PortalNamespace: String?] {
    withProgressCallback?(MpcStatus(status: .done, done: true))
    return [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress
    ]
  }

  public func recover(
    _: BackupMethods,
    withCipherText _: String? = nil,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> [PortalNamespace: String?] {
    usingProgressCallback?(MpcStatus(status: .done, done: true))
    return [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress
    ]
  }

  public func generateSolanaWallet(usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> String {
    MockConstants.mockSolanaAddress
  }

  public func generateSolanaWalletAndBackupShares(backupMethod _: BackupMethods, usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> (solanaAddress: String, backupResponse: PortalMpcBackupResponse) {
    return (
      solanaAddress: MockConstants.mockSolanaAddress,
      backupResponse:
      PortalMpcBackupResponse(
        cipherText: MockConstants.mockCiphertext,
        shareIds: [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId]
      )
    )
  }

  public func backup(method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, completion _: @escaping (Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}

  public func generate(completion _: @escaping (Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}

  public func ejectPrivateKey(clientBackupCiphertext _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, orgBackupShare _: String, completion _: @escaping (Result<String>) -> Void) {}

  public func recover(cipherText _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs?, completion _: @escaping (Result<String>) -> Void, progress _: ((MpcStatus) -> Void)?) {}

  public func registerBackupMethod(_: BackupMethods, withStorage _: PortalStorage) {}

  public func setPassword(_: String) throws {}

  public func setGDriveView(_: UIViewController) throws {}

  public func setGDriveConfiguration(clientId _: String, backupOption _: GDriveBackupOption) throws {}

  public func setPasskeyAuthenticationAnchor(_: ASPresentationAnchor) throws {}

  public func setPasskeyConfiguration(relyingParty _: String, webAuthnHost _: String) throws {}
}

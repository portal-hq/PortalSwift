//
//  MockPortalMpc.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import AuthenticationServices
import Foundation

public class MockPortalMpc: PortalMpc {
  override public func backup(
    _: BackupMethods,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> PortalMpcBackupResponse {
    usingProgressCallback?(MpcStatus(status: .done, done: true))
    return PortalMpcBackupResponse(
      cipherText: MockConstants.mockCiphertext,
      shareIds: [MockConstants.mockMpcShareId, MockConstants.mockMpcShareId]
    )
  }

    override public func ejectPrivateKeys(
        _ method: BackupMethods,
        with cipherText: String,
        and organizationBackupShare: [PortalCurve : String]
    ) async throws -> EjectedKeys {
        return EjectedKeys(secp256k1Key: MockConstants.mockEip155EjectedPrivateKey, ed25519Key: MockConstants.mockSolonaEjectedPrivateKey)
    }

  override public func generate(withProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> [PortalNamespace: String?] {
    withProgressCallback?(MpcStatus(status: .done, done: true))
    return [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress,
    ]
  }

  override public func recover(
    _: BackupMethods,
    withCipherText _: String,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> [PortalNamespace: String?] {
    usingProgressCallback?(MpcStatus(status: .done, done: true))
    return [
      .eip155: MockConstants.mockEip155Address,
      .solana: MockConstants.mockSolanaAddress,
    ]
  }

  override public func registerBackupMethod(_: BackupMethods, withStorage _: PortalStorage) {}

  override public func setPassword(_: String) throws {}

  override public func setGDriveView(_: UIViewController) throws {}

  override public func setGDriveConfiguration(clientId _: String, folderName _: String) throws {}

  override public func setPasskeyAuthenticationAnchor(_: ASPresentationAnchor) throws {}

  override public func setPasskeyConfiguration(relyingParty _: String, webAuthnHost _: String) throws {}
}

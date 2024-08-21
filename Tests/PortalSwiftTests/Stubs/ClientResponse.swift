//
//  ClientResponse.swift
//
//
//  Created by Ahmed Ragab on 22/08/2024.
//

import Foundation
@testable import PortalSwift

extension ClientResponse {
    static func stub(
        id: String = "default_id",
        custodian: ClientResponseCustodian = .stub(),
        createdAt: String = "default_created_at",
        environment: ClientResponseEnvironment? = .stub(),
        ejectedAt: String? = nil,
        isAccountAbstracted: Bool = false,
        metadata: ClientResponseMetadata = .stub(),
        wallets: [ClientResponseWallet] = [.stub()]
    ) -> Self {
        return ClientResponse(
            id: id,
            custodian: custodian,
            createdAt: createdAt,
            environment: environment,
            ejectedAt: ejectedAt,
            isAccountAbstracted: isAccountAbstracted,
            metadata: metadata,
            wallets: wallets
        )
    }
}

extension ClientResponseCustodian {
    static func stub(
        id: String = "default_custodian_id",
        name: String = "default_custodian_name"
    ) -> Self {
        return ClientResponseCustodian(id: id, name: name)
    }
}

extension ClientResponseEnvironment {
    static func stub(
        id: String = "default_env_id",
        name: String = "default_env_name",
        backupWithPortalEnabled: Bool? = true
    ) -> Self {
        return ClientResponseEnvironment(id: id, name: name, backupWithPortalEnabled: backupWithPortalEnabled)
    }
}

extension ClientResponseMetadata {
    static func stub(
        namespaces: ClientResponseMetadataNamespaces = .stub()
    ) -> Self {
        return ClientResponseMetadata(namespaces: namespaces)
    }
}

extension ClientResponseMetadataNamespaces {
    static func stub(
        eip155: ClientResponseNamespaceMetadataItem? = .stub(),
        solana: ClientResponseNamespaceMetadataItem? = .stub()
    ) -> Self {
        return ClientResponseMetadataNamespaces(eip155: eip155, solana: solana)
    }
}

extension ClientResponseNamespaceMetadataItem {
    static func stub(
        address: String = "default_address",
        curve: PortalCurve = .SECP256K1
    ) -> Self {
        return ClientResponseNamespaceMetadataItem(address: address, curve: curve)
    }
}

extension ClientResponseBackupSharePair {
    static func stub(
        backupMethod: BackupMethods = .iCloud,
        createdAt: String = "default_created_at",
        id: String = "default_id",
        status: PortalSharePairStatus = .completed
    ) -> Self {
        return ClientResponseBackupSharePair(backupMethod: backupMethod, createdAt: createdAt, id: id, status: status)
    }
}

extension ClientResponseSharePair {
    static func stub(
        id: String = "default_share_pair_id",
        createdAt: String = "default_created_at",
        status: PortalSharePairStatus = .completed
    ) -> Self {
        return ClientResponseSharePair(id: id, createdAt: createdAt, status: status)
    }
}

extension ClientResponseWallet {
    static func stub(
        id: String = "default_wallet_id",
        createdAt: String = "default_created_at",
        backupSharePairs: [ClientResponseBackupSharePair] = [.stub()],
        curve: PortalCurve = .SECP256K1,
        ejectableUntil: String? = nil,
        publicKey: String = "default_public_key",
        signingSharePairs: [ClientResponseSharePair] = [.stub()]
    ) -> Self {
        return ClientResponseWallet(
            id: id,
            createdAt: createdAt,
            backupSharePairs: backupSharePairs,
            curve: curve,
            ejectableUntil: ejectableUntil,
            publicKey: publicKey,
            signingSharePairs: signingSharePairs
        )
    }
}


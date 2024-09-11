//
//  MobileSpy.swift
//
//
//  Created by Ahmed Ragab on 11/09/2024.
//

import Foundation
@testable import PortalSwift

final class MobileSpy: Mobile {
    // MARK: - MobileGenerate Spy Properties
    var mobileGenerateCallsCount = 0
    private(set) var mobileGenerateApiKeyParam: String?
    private(set) var mobileGenerateHostParam: String?
    private(set) var mobileGenerateApiHostParam: String?
    private(set) var mobileGenerateMetadataParam: String?
    var mobileGenerateReturnValue: String = ""

    public func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileGenerateCallsCount += 1
        mobileGenerateApiKeyParam = apiKey
        mobileGenerateHostParam = host
        mobileGenerateApiHostParam = apiHost
        mobileGenerateMetadataParam = metadata
        return mobileGenerateReturnValue
    }

    // MARK: - MobileGenerateEd25519 Spy Properties
    var mobileGenerateEd25519CallsCount = 0
    private(set) var mobileGenerateEd25519ApiKeyParam: String?
    private(set) var mobileGenerateEd25519HostParam: String?
    private(set) var mobileGenerateEd25519ApiHostParam: String?
    private(set) var mobileGenerateEd25519MetadataParam: String?
    var mobileGenerateEd25519ReturnValue: String = ""

    public func MobileGenerateEd25519(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileGenerateEd25519CallsCount += 1
        mobileGenerateEd25519ApiKeyParam = apiKey
        mobileGenerateEd25519HostParam = host
        mobileGenerateEd25519ApiHostParam = apiHost
        mobileGenerateEd25519MetadataParam = metadata
        return mobileGenerateEd25519ReturnValue
    }

    // MARK: - MobileGenerateSecp256k1 Spy Properties
    var mobileGenerateSecp256k1CallsCount = 0
    private(set) var mobileGenerateSecp256k1ApiKeyParam: String?
    private(set) var mobileGenerateSecp256k1HostParam: String?
    private(set) var mobileGenerateSecp256k1ApiHostParam: String?
    private(set) var mobileGenerateSecp256k1MetadataParam: String?
    var mobileGenerateSecp256k1ReturnValue: String = ""

    public func MobileGenerateSecp256k1(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileGenerateSecp256k1CallsCount += 1
        mobileGenerateSecp256k1ApiKeyParam = apiKey
        mobileGenerateSecp256k1HostParam = host
        mobileGenerateSecp256k1ApiHostParam = apiHost
        mobileGenerateSecp256k1MetadataParam = metadata
        return mobileGenerateSecp256k1ReturnValue
    }

    // MARK: - MobileBackup Spy Properties
    var mobileBackupCallsCount = 0
    private(set) var mobileBackupApiKeyParam: String?
    private(set) var mobileBackupHostParam: String?
    private(set) var mobileBackupSigningShareParam: String?
    private(set) var mobileBackupApiHostParam: String?
    private(set) var mobileBackupMetadataParam: String?
    var mobileBackupReturnValue: String = ""

    public func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileBackupCallsCount += 1
        mobileBackupApiKeyParam = apiKey
        mobileBackupHostParam = host
        mobileBackupSigningShareParam = signingShare
        mobileBackupApiHostParam = apiHost
        mobileBackupMetadataParam = metadata
        return mobileBackupReturnValue
    }

    // MARK: - MobileBackupEd25519 Spy Properties
    var mobileBackupEd25519CallsCount = 0
    private(set) var mobileBackupEd25519ApiKeyParam: String?
    private(set) var mobileBackupEd25519HostParam: String?
    private(set) var mobileBackupEd25519SigningShareParam: String?
    private(set) var mobileBackupEd25519ApiHostParam: String?
    private(set) var mobileBackupEd25519MetadataParam: String?
    var mobileBackupEd25519ReturnValue: String = ""

    public func MobileBackupEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileBackupEd25519CallsCount += 1
        mobileBackupEd25519ApiKeyParam = apiKey
        mobileBackupEd25519HostParam = host
        mobileBackupEd25519SigningShareParam = signingShare
        mobileBackupEd25519ApiHostParam = apiHost
        mobileBackupEd25519MetadataParam = metadata
        return mobileBackupEd25519ReturnValue
    }

    // MARK: - MobileBackupSecp256k1 Spy Properties
    var mobileBackupSecp256k1CallsCount = 0
    private(set) var mobileBackupSecp256k1ApiKeyParam: String?
    private(set) var mobileBackupSecp256k1HostParam: String?
    private(set) var mobileBackupSecp256k1SigningShareParam: String?
    private(set) var mobileBackupSecp256k1ApiHostParam: String?
    private(set) var mobileBackupSecp256k1MetadataParam: String?
    var mobileBackupSecp256k1ReturnValue: String = ""

    public func MobileBackupSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileBackupSecp256k1CallsCount += 1
        mobileBackupSecp256k1ApiKeyParam = apiKey
        mobileBackupSecp256k1HostParam = host
        mobileBackupSecp256k1SigningShareParam = signingShare
        mobileBackupSecp256k1ApiHostParam = apiHost
        mobileBackupSecp256k1MetadataParam = metadata
        return mobileBackupSecp256k1ReturnValue
    }

    // MARK: - MobileRecoverSigning Spy Properties
    var mobileRecoverSigningCallsCount = 0
    private(set) var mobileRecoverSigningApiKeyParam: String?
    private(set) var mobileRecoverSigningHostParam: String?
    private(set) var mobileRecoverSigningSigningShareParam: String?
    private(set) var mobileRecoverSigningApiHostParam: String?
    private(set) var mobileRecoverSigningMetadataParam: String?
    var mobileRecoverSigningReturnValue: String = ""

    public func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileRecoverSigningCallsCount += 1
        mobileRecoverSigningApiKeyParam = apiKey
        mobileRecoverSigningHostParam = host
        mobileRecoverSigningSigningShareParam = signingShare
        mobileRecoverSigningApiHostParam = apiHost
        mobileRecoverSigningMetadataParam = metadata
        return mobileRecoverSigningReturnValue
    }

    // MARK: - MobileRecoverSigningEd25519 Spy Properties
    var mobileRecoverSigningEd25519CallsCount = 0
    private(set) var mobileRecoverSigningEd25519ApiKeyParam: String?
    private(set) var mobileRecoverSigningEd25519HostParam: String?
    private(set) var mobileRecoverSigningEd25519SigningShareParam: String?
    private(set) var mobileRecoverSigningEd25519ApiHostParam: String?
    private(set) var mobileRecoverSigningEd25519MetadataParam: String?
    var mobileRecoverSigningEd25519ReturnValue: String = ""

    public func MobileRecoverSigningEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileRecoverSigningEd25519CallsCount += 1
        mobileRecoverSigningEd25519ApiKeyParam = apiKey
        mobileRecoverSigningEd25519HostParam = host
        mobileRecoverSigningEd25519SigningShareParam = signingShare
        mobileRecoverSigningEd25519ApiHostParam = apiHost
        mobileRecoverSigningEd25519MetadataParam = metadata
        return mobileRecoverSigningEd25519ReturnValue
    }

    // MARK: - MobileRecoverSigningSecp256k1 Spy Properties
    var mobileRecoverSigningSecp256k1CallsCount = 0
    private(set) var mobileRecoverSigningSecp256k1ApiKeyParam: String?
    private(set) var mobileRecoverSigningSecp256k1HostParam: String?
    private(set) var mobileRecoverSigningSecp256k1SigningShareParam: String?
    private(set) var mobileRecoverSigningSecp256k1ApiHostParam: String?
    private(set) var mobileRecoverSigningSecp256k1MetadataParam: String?
    var mobileRecoverSigningSecp256k1ReturnValue: String = ""

    public func MobileRecoverSigningSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileRecoverSigningSecp256k1CallsCount += 1
        mobileRecoverSigningSecp256k1ApiKeyParam = apiKey
        mobileRecoverSigningSecp256k1HostParam = host
        mobileRecoverSigningSecp256k1SigningShareParam = signingShare
        mobileRecoverSigningSecp256k1ApiHostParam = apiHost
        mobileRecoverSigningSecp256k1MetadataParam = metadata
        return mobileRecoverSigningSecp256k1ReturnValue
    }

    // MARK: - MobileRecoverBackup Spy Properties
    var mobileRecoverBackupCallsCount = 0
    private(set) var mobileRecoverBackupApiKeyParam: String?
    private(set) var mobileRecoverBackupHostParam: String?
    private(set) var mobileRecoverBackupSigningShareParam: String?
    private(set) var mobileRecoverBackupApiHostParam: String?
    private(set) var mobileRecoverBackupMetadataParam: String?
    var mobileRecoverBackupReturnValue: String = ""

    public func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String {
        mobileRecoverBackupCallsCount += 1
        mobileRecoverBackupApiKeyParam = apiKey
        mobileRecoverBackupHostParam = host
        mobileRecoverBackupSigningShareParam = signingShare
        mobileRecoverBackupApiHostParam = apiHost
        mobileRecoverBackupMetadataParam = metadata
        return mobileRecoverBackupReturnValue
    }

    // MARK: - MobileDecrypt Spy Properties
    var mobileDecryptCallsCount = 0
    private(set) var mobileDecryptKeyParam: String?
    private(set) var mobileDecryptDkgCipherTextParam: String?
    var mobileDecryptReturnValue: String =  MockConstants.mockDecryptResult

    public func MobileDecrypt(_ key: String, _ dkgCipherText: String) async -> String {
        mobileDecryptCallsCount += 1
        mobileDecryptKeyParam = key
        mobileDecryptDkgCipherTextParam = dkgCipherText
        return mobileDecryptReturnValue
    }

    // MARK: - MobileEncrypt Spy Properties
    var mobileEncryptCallsCount = 0
    private(set) var mobileEncryptValueParam: String?
    var mobileEncryptReturnValue: String = MockConstants.mockEncryptResult

    public func MobileEncrypt(_ value: String) async -> String {
        mobileEncryptCallsCount += 1
        mobileEncryptValueParam = value
        return mobileEncryptReturnValue
    }

    // MARK: - MobileEncryptWithPassword Spy Properties
    var mobileEncryptWithPasswordCallsCount = 0
    private(set) var mobileEncryptWithPasswordValueParam: String?
    private(set) var mobileEncryptWithPasswordPasswordParam: String?
    var mobileEncryptWithPasswordReturnValue: String = MockConstants.mockEncryptWithPasswordResult

    public func MobileEncryptWithPassword(data value: String, password: String) async -> String {
        mobileEncryptWithPasswordCallsCount += 1
        mobileEncryptWithPasswordValueParam = value
        mobileEncryptWithPasswordPasswordParam = password
        return mobileEncryptWithPasswordReturnValue
    }

    // MARK: - MobileDecryptWithPassword Spy Properties
    var mobileDecryptWithPasswordCallsCount = 0
    private(set) var mobileDecryptWithPasswordKeyParam: String?
    private(set) var mobileDecryptWithPasswordDkgCipherTextParam: String?
    var mobileDecryptWithPasswordReturnValue: String = MockConstants.mockDecryptResult

    public func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) async -> String {
        mobileDecryptWithPasswordCallsCount += 1
        mobileDecryptWithPasswordKeyParam = key
        mobileDecryptWithPasswordDkgCipherTextParam = dkgCipherText
        return mobileDecryptWithPasswordReturnValue
    }

    // MARK: - MobileGetMe Spy Properties
    var mobileGetMeCallsCount = 0
    private(set) var mobileGetMeUrlParam: String?
    private(set) var mobileGetMeTokenParam: String?
    var mobileGetMeReturnValue: String = ""

    public func MobileGetMe(_ url: String, _ token: String) -> String {
        mobileGetMeCallsCount += 1
        mobileGetMeUrlParam = url
        mobileGetMeTokenParam = token
        return mobileGetMeReturnValue
    }

    // MARK: - MobileGetVersion Spy Properties
    var mobileGetVersionCallsCount = 0
    var mobileGetVersionReturnValue: String = "4.0.1"

    public func MobileGetVersion() -> String {
        mobileGetVersionCallsCount += 1
        return mobileGetVersionReturnValue
    }

    // MARK: - MobileSign Spy Properties
    var mobileSignCallsCount = 0
    private(set) var mobileSignApiKeyParam: String?
    private(set) var mobileSignHostParam: String?
    private(set) var mobileSignSigningShareParam: String?
    private(set) var mobileSignMethodParam: String?
    private(set) var mobileSignParamsParam: String?
    private(set) var mobileSignRpcURLParam: String?
    private(set) var mobileSignChainIdParam: String?
    private(set) var mobileSignMetadataParam: String?
    var mobileSignReturnValue: String = MockConstants.mockSignatureResponse

    public func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ metadata: String?) async -> String {
        mobileSignCallsCount += 1
        mobileSignApiKeyParam = apiKey
        mobileSignHostParam = host
        mobileSignSigningShareParam = signingShare
        mobileSignMethodParam = method
        mobileSignParamsParam = params
        mobileSignRpcURLParam = rpcURL
        mobileSignChainIdParam = chainId
        mobileSignMetadataParam = metadata
        return mobileSignReturnValue
    }

    // MARK: - MobileEjectWalletAndDiscontinueMPC Spy Properties
    var mobileEjectWalletAndDiscontinueMPCCallsCount = 0
    private(set) var mobileEjectWalletAndDiscontinueMPCClientDkgCipherTextParam: String?
    private(set) var mobileEjectWalletAndDiscontinueMPCServerDkgCipherTextParam: String?
    var mobileEjectWalletAndDiscontinueMPCReturnValue: String = MockConstants.mockEip155EjectResponse

    public func MobileEjectWalletAndDiscontinueMPC(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
        mobileEjectWalletAndDiscontinueMPCCallsCount += 1
        mobileEjectWalletAndDiscontinueMPCClientDkgCipherTextParam = clientDkgCipherText
        mobileEjectWalletAndDiscontinueMPCServerDkgCipherTextParam = serverDkgCipherText
        return mobileEjectWalletAndDiscontinueMPCReturnValue
    }

    // MARK: - MobileEjectWalletAndDiscontinueMPCEd25519 Spy Properties
    var mobileEjectWalletAndDiscontinueMPCEd25519CallsCount = 0
    private(set) var mobileEjectWalletAndDiscontinueMPCEd25519ClientDkgCipherTextParam: String?
    private(set) var mobileEjectWalletAndDiscontinueMPCEd25519ServerDkgCipherTextParam: String?
    var mobileEjectWalletAndDiscontinueMPCEd25519ReturnValue: String = MockConstants.mockSolanaEjectResponse

    public func MobileEjectWalletAndDiscontinueMPCEd25519(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
        mobileEjectWalletAndDiscontinueMPCEd25519CallsCount += 1
        mobileEjectWalletAndDiscontinueMPCEd25519ClientDkgCipherTextParam = clientDkgCipherText
        mobileEjectWalletAndDiscontinueMPCEd25519ServerDkgCipherTextParam = serverDkgCipherText
        return mobileEjectWalletAndDiscontinueMPCEd25519ReturnValue
    }
}

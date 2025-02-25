//
//  Constants.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import GoogleSignIn

enum MockConstantsError: LocalizedError {
  case unableToEncodeMockValue
}

public enum MockConstants {
  public static let backupProgressCallbacks: Set<MpcStatuses> = [
    .readingShare,
    .generatingShare,
    .parsingShare,
    .encryptingShare,
    .storingShare,
    .done
  ]
  public static let generateProgressCallbacks: Set<MpcStatuses> = [
    .generatingShare,
    .parsingShare,
    .storingShare,
    .done
  ]
  public static let recoverProgressCallbacks: Set<MpcStatuses> = [
    .readingShare,
    .decryptingShare,
    .parsingShare,
    .generatingShare,
    .parsingShare,
    .storingShare,
    .done
  ]

  public static let mockApiKey = "test-api-key"
  public static let mockBackupPath = "test-backup-path"
  public static let mockCiphertext = "test-cipher-text"
  public static let mockClientId = "test-client-id"
  public static let mockCloudBackupPath = "test-cloud-backup-path"
  public static let mockCreatedAt = "test-created-at"
  public static let mockCustodian = ClientResponseCustodian(
    id: "test-custodian-id",
    name: "test-custodian-name"
  )
  public static let mockDecryptResult = "{\"data\":{\"plaintext\":\"\(mockDecryptedShare)\"},\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockDecryptedShare = "test-decrypted-share"
  public static let mockED25519KeychainWallet = PortalKeychainClientMetadataWallet(
    id: mockMpcShareId,
    curve: .ED25519,
    publicKey: mockPublicKey,
    backupShares: [mockKeychainBackupShare],
    signingShares: [mockKeychainShare]
  )
  public static let mockED25519Wallet = ClientResponseWallet(
    id: mockWalletId,
    createdAt: mockCreatedAt,
    backupSharePairs: [mockWalletBackupShare],
    curve: .ED25519,
    ejectableUntil: nil,
    publicKey: mockPublicKey,
    signingSharePairs: [mockWalletSigningShare]
  )
  public static let mockED25519NotBackedUpWallet = ClientResponseWallet(
    id: mockWalletId,
    createdAt: mockCreatedAt,
    backupSharePairs: [],
    curve: .ED25519,
    ejectableUntil: nil,
    publicKey: mockPublicKey,
    signingSharePairs: [mockWalletSigningShare]
  )
  public static let mockEip155Address = "0x73574d235573574d235573574d235573574d2355"
  public static let mockEip155EjectResponse = "{\"privateKey\":\"\(mockEip155EjectedPrivateKey)\",\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockEip155EjectedPrivateKey = "099cabf8c65c81e629d59e72f04a549aafa531329e25685a5b8762b926597209"
  public static let mockEip155Transaction = [
    "from": mockEip155Address,
    "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
    "value": "0x9184e72a",
    "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
  ]
  public static let mockEjectResponse = "test-eject-response"
  public static let mockEncryptData = EncryptData(key: mockEncryptionKey, cipherText: mockCiphertext)
  public static let mockEncryptResult = "{\"data\":{\"key\":\"\(mockEncryptionKey)\",\"cipherText\":\"\(mockCiphertext)\"},\"error\":{\"code\":0,\"message\":\"\"}}"

  public static let mockEncryptWithPasswordResult = "{\"data\":{\"cipherText\":\"\(mockCiphertext)\"},\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockEncryptionKey = "test-encryption-key"
  public static let mockedFetchedBalance = FetchedBalance(contractAddress: mockEip155Address, balance: "test-balance")
  public static let mockFetchedShairPair = FetchedSharePair(
    id: mockMpcShareId,
    createdAt: mockCreatedAt,
    status: .completed
  )
  public static let mockFetchedTransaction = FetchedTransaction(
    blockNum: "test-block-number",
    uniqueId: "test-unique-id",
    hash: mockTransactionHash,
    from: mockEip155Address,
    to: mockEip155Address,
    value: 0.1,
    asset: "test-transaction-asset",
    category: "test-transaction-category",
    rawContract: FetchedTransactionRawContract(value: "test-value", address: mockEip155Address, decimal: "test-decimal"),
    metadata: FetchedTransaction.FetchedTransactionMetadata(blockTimestamp: "test-block-timestamp"),
    chainId: 11_155_111
  )
  public static let mockFundResponse = FundResponse(
    data: FundResponseData(
      explorerUrl: "https://sepolia.etherscan.io/tx/0x13aebe28e9661959f73e06c48123d67d47e8e24a3833f626d2fcaa6ef640d0de",
      txHash: "0x13aebe28e9661959f73e06c48123d67d47e8e24a3833f626d2fcaa6ef640d0de"
    ),
    metadata: FundResponseMetadata(
      amount: "0.01",
      chainId: "eip155:11155111",
      clientId: "clientId",
      custodianId: "custodianId",
      environmentId: "environmentId",
      token: "ETH"
    ),
    error: FundResponseError(id: "id", message: "message")
  )
  public static let mockGDriveClientId = "test-mock-gdrive-client-id"
  public static let mockGDriveFile = GDriveFile(
    kind: "test-gdrive-file-kind",
    id: mockGDriveFileId,
    name: mockGDriveFileName,
    mimeType: "test-gdrive-mime-type"
  )
  public static let mockGDriveFileContents = "test-gdrive-private-key"
  public static let mockGDriveFileId = "test-gdrive-file-id"
  public static let mockGDriveFileName = "test-gdrive-file-name"
  public static let mockGDriveFolderId = "test-gdrive-folder-id"
  public static let mockGoogleAccessToken = "test-google-access-token"
  public static let mockGoogleUserId = "test-google-user-id"
  public static let mockHost = "example.com"
  public static let mockKeychainBackupShare = PortalKeychainClientMetadataWalletBackupShare(
    backupMethod: .Password,
    createdAt: mockCreatedAt,
    id: mockMpcShareId,
    status: .completed
  )
  public static let mockKeychainClientMetadata = PortalKeychainClientMetadata(
    id: MockConstants.mockClientId,
    addresses: [
      .eip155: mockEip155Address,
      .solana: mockSolanaAddress
    ],
    custodian: mockCustodian,
    wallets: [
      .ED25519: mockED25519KeychainWallet,
      .SECP256K1: mockED25519KeychainWallet
    ]
  )
  public static let mockKeychainShare = PortalKeychainClientMetadataWalletShare(
    createdAt: mockCreatedAt,
    id: mockMpcShareId,
    status: .completed
  )
  public static let mockMetricsResponse = MetricsResponse(status: true)
  public static let mockMpcShare: MpcShare = {
    let mockData: [String: Any] = [
      "clientId": "",
      "backupSharePairId": "test-share-id",
      "signingSharePairId": "test-share-id",
      "share": "mock-share-data",
      "ssid": "mock-ssid",
      "pubkey": [
        "X": "mock-pubkey-x",
        "Y": "mock-pubkey-y"
      ],
      "partialPubkey": [
        "client": ["X": "mock-partial-client-x", "Y": "mock-partial-client-y"],
        "server": ["X": "mock-partial-server-x", "Y": "mock-partial-server-y"]
      ],
      "allY": [
        "client": ["X": "mock-all-y-client-x", "Y": "mock-all-y-client-y"],
        "server": ["X": "mock-all-y-server-x", "Y": "mock-all-y-server-y"]
      ],
      "p": "mock-p",
      "q": "mock-q",
      "pederson": [
        "client": ["n": "mock-pederson-client-n", "s": "mock-pederson-client-s", "t": "mock-pederson-client-t"],
        "server": ["n": "mock-pederson-server-n", "s": "mock-pederson-server-s", "t": "mock-pederson-server-t"]
      ],
      "bks": [
        "client": ["X": "mock-bks-client-x", "Rank": 0],
        "server": ["X": "mock-bks-server-x", "Rank": 1]
      ],
      "partialPublicKey": [
        "client": ["X": "mock-partial-public-key-client-x", "Y": "mock-partial-public-key-client-y"],
        "server": ["X": "mock-partial-public-key-server-x", "Y": "mock-partial-public-key-server-y"]
      ],
      "partialPubKey": [
        ["X": "mock-partial-pub-key-1-x", "Y": "mock-partial-pub-key-1-y"],
        ["X": "mock-partial-pub-key-2-x", "Y": "mock-partial-pub-key-2-y"]
      ]
    ]

    let jsonData = try! JSONSerialization.data(withJSONObject: mockData, options: [])
    return try! JSONDecoder().decode(MpcShare.self, from: jsonData)
  }()

  public static let mockMpcShareId = "test-share-id"
  public static let mockMpcShareShare = "test-mpc-share-share"
  public static let mocMpcShareSsid = "test-mpc-share-ssid"
  public static let mockMpcShareP = "test-mpc-share-p"
  public static let mockMpcShareQ = "test-mpc-share-q"
  public static let mockPasskeyAssertion = "test-passkey-assertion"
  public static let mockPasskeyAttestation = "test-passkey-attestation"
  public static let mockPasskeyAuthenticationOptions = WebAuthnAuthenticationOption(
    options: AuthenticationOptions(
      publicKey: AuthenticationOptions.PublicKey(
        challenge: "test-authentication-challenge",
        timeout: 999_999,
        rpId: "test-relying-party-id",
        allowCredentials: [AuthenticationOptions.Credential(
          type: "test-authentication-credential-type",
          id: "test-authentication-credential-id"
        )],
        userVerification: "test-user-verification"
      )
    ),
    sessionId: "test-session-id"
  )
  public static let mockPasskeyReadResponse = PasskeyLoginReadResponse(encryptionKey: mockEncryptionKey)
  public static let mockPasskeyRegistrationOptions = WebAuthnRegistrationOptions(
    options: RegistrationOptions(
      publicKey: PublicKeyOptions(
        rp: RelyingParty(name: "test-relying-party-name", id: "test-relying-party-id"),
        user: User(name: "test-user-name", displayName: "test-user-display-name", id: "test-user-id"),
        challenge: "test-registration-challenge",
        pubKeyCredParams: [CredentialParameter(type: "test-credential-parameter", alg: 99)],
        timeout: 999_999,
        authenticatorSelection: nil,
        attestation: mockPasskeyAttestation
      )
    ),
    sessionId: "test-session-id"
  )
  public static let mockPasskeyStatus = PasskeyStatusResponse(status: .RegisteredWithCredential)
  public static let mockProviderRequestId = "test-provider-request-id"
  public static let mockPublicKey = "{\"X\":\"test-public-key-x\",\"Y\":\"test-public-key-y\"}"
  public static let mockRpcResponse = PortalProviderRpcResponse(jsonrpc: "2.0", id: 0, result: "test")
  public static let mockSECP256K1KeychainWallet = PortalKeychainClientMetadataWallet(
    id: mockMpcShareId,
    curve: .SECP256K1,
    publicKey: mockPublicKey,
    backupShares: [mockKeychainBackupShare],
    signingShares: [mockKeychainShare]
  )
  public static let mockSECP256K1Wallet = ClientResponseWallet(
    id: mockWalletId,
    createdAt: mockCreatedAt,
    backupSharePairs: [mockWalletBackupShare],
    curve: .SECP256K1,
    ejectableUntil: nil,
    publicKey: mockPublicKey,
    signingSharePairs: [mockWalletSigningShare]
  )
  public static let mockSECP256K1NotBackedUpWallet = ClientResponseWallet(
    id: mockWalletId,
    createdAt: mockCreatedAt,
    backupSharePairs: [],
    curve: .SECP256K1,
    ejectableUntil: nil,
    publicKey: mockPublicKey,
    signingSharePairs: [mockWalletSigningShare]
  )
  public static let mockSignResult = "{\"data\":\"\(mockSignature)\",\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockSignResultWithError = "{\"data\":\"\",\"error\":{\"code\":108,\"message\":\"This error is thrown if there is an issue completing the signing process.\"}}"
  public static let mockSignTypedDataMessage =
    "{\"types\":{\"PermitSingle\":[{\"name\":\"details\",\"type\":\"PermitDetails\"},{\"name\":\"spender\",\"type\":\"address\"},{\"name\":\"sigDeadline\",\"type\":\"uint256\"}],\"PermitDetails\":[{\"name\":\"token\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint160\"},{\"name\":\"expiration\",\"type\":\"uint48\"},{\"name\":\"nonce\",\"type\":\"uint48\"}],\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},{\"name\":\"verifyingContract\",\"type\":\"address\"}]},\"domain\":{\"name\":\"Permit2\",\"chainId\":\"5\",\"verifyingContract\":\"0x000000000022d473030f116ddee9f6b43ac78ba3\"},\"primaryType\":\"PermitSingle\",\"message\":{\"details\":{\"token\":\"0x1f9840a85d5af5bf1d1762f925bdaddc4201f984\",\"amount\":\"1461501637330902918203684832716283019655932542975\",\"expiration\":\"1685053478\",\"nonce\":\"0\"},\"spender\":\"0x4648a43b2c14da09fdf82b161150d3f634f40491\",\"sigDeadline\":\"1682463278\"}}"
  public static let mockSignature = "54cdc8c44437159f524268bdf257d88743eb550def55171f9418c5abd9a994467aa000b3213e6cc1ae950b31631450faffbac7319c7ec096898314d1f289646900"
  public static let mockSignatureResponse = "{\"data\":\"\(mockSignature)\",\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockSimulatedTransaction = SimulatedTransaction(
    changes: []
  )
  public static let mockSolanaAddress = "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT"
  public static let mockSolanaEjectResponse = "{\"privateKey\":\"\(mockSolanaPrivateKey)\",\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockSolanaPrivateKey = "099cabf8c65c81e629d59e72f04a549aafa531329e25685a5b8762b926597209"
  public static let mockTransactionHash = "0x926c5168c5646425d5dcf8e3dac7359ddb77e9ff95884393a6a9a8e3de066fc1"
  public static let mockTransactionHashResponse = "{\"data\":\"\(mockTransactionHash)\",\"error\":{\"code\":0,\"message\":\"\"}}"
  public static let mockWalletBackupShare = ClientResponseBackupSharePair(
    backupMethod: .Password,
    createdAt: mockCreatedAt,
    id: mockMpcShareId,
    status: .completed
  )
  public static let mockWalletId = "test-wallet-id"
  public static let mockWalletSigningShare = ClientResponseSharePair(
    id: mockMpcShareId,
    createdAt: mockCreatedAt,
    status: .completed
  )

  // Dynamically generated constants
  public static var mockClient: ClientResponse {
    ClientResponse(
      id: mockClientId,
      custodian: mockCustodian,
      createdAt: mockCreatedAt,
      environment: ClientResponseEnvironment(
        id: "test-environment-id",
        name: "test-environment-name",
        backupWithPortalEnabled: false
      ),
      ejectedAt: "test-ejected-at",
      isAccountAbstracted: false,
      metadata: ClientResponseMetadata(
        namespaces: ClientResponseMetadataNamespaces(
          eip155: ClientResponseNamespaceMetadataItem(
            address: mockEip155Address,
            curve: .SECP256K1
          ),
          solana: nil
        )
      ),
      wallets: [
        mockED25519Wallet,
        mockSECP256K1Wallet
      ]
    )
  }

  public static var mockNotBackedUpClient: ClientResponse {
    ClientResponse(
      id: mockClientId,
      custodian: mockCustodian,
      createdAt: mockCreatedAt,
      environment: ClientResponseEnvironment(
        id: "test-environment-id",
        name: "test-environment-name",
        backupWithPortalEnabled: false
      ),
      ejectedAt: "test-ejected-at",
      isAccountAbstracted: false,
      metadata: ClientResponseMetadata(
        namespaces: ClientResponseMetadataNamespaces(
          eip155: ClientResponseNamespaceMetadataItem(
            address: mockEip155Address,
            curve: .SECP256K1
          ),
          solana: nil
        )
      ),
      wallets: [
        mockED25519NotBackedUpWallet,
        mockSECP256K1NotBackedUpWallet
      ]
    )
  }

  public static var mockClientResponseString: String {
    get async throws {
      let mockClient = mockClient
      let mockClientData = try JSONEncoder().encode(mockClient)
      guard let mockClientResponseString = String(data: mockClientData, encoding: .utf8) else {
        throw MockConstantsError.unableToEncodeMockValue
      }

      return mockClientResponseString
    }
  }

  public static var mockGeneratedShare: PortalMpcGeneratedShare {
    get throws {
      let mockMpcShareData = try JSONEncoder().encode(mockMpcShare)
      guard let mockMpcShareString = String(data: mockMpcShareData, encoding: .utf8) else {
        throw MockConstantsError.unableToEncodeMockValue
      }

      return PortalMpcGeneratedShare(
        id: mockMpcShareId,
        share: mockMpcShareString
      )
    }
  }

  public static var mockGenerateResponse: PortalMpcGenerateResponse {
    get throws {
      let mockGeneratedShare = try mockGeneratedShare

      let mockGenerateResponse: PortalMpcGenerateResponse = [
        "ED25519": mockGeneratedShare,
        "SECP256K1": mockGeneratedShare
      ]

      return mockGenerateResponse
    }
  }

  public static var mockRotateResult: String {
    get throws {
      let rotateResult = RotateResult(
        data: RotateData(share: mockMpcShare),
        error: PortalError(code: 0, message: "")
      )
      let rotateResultData = try JSONEncoder().encode(rotateResult)
      guard let result = String(data: rotateResultData, encoding: .utf8) else {
        throw MockConstantsError.unableToEncodeMockValue
      }

      return result
    }
  }

  public static var mockCreateWalletResponse: PortalCreateWalletResponse {
    let mockCreateWalletResponse: PortalCreateWalletResponse = (
      ethereum: mockEip155Address,
      solana: mockSolanaAddress
    )

    return mockCreateWalletResponse
  }

  public static var mockMpcShareString: String {
    get throws {
      let mockMpcShareData = try JSONEncoder().encode(mockMpcShare)
      guard let mockMpcShareString = String(data: mockMpcShareData, encoding: .utf8) else {
        throw MockConstantsError.unableToEncodeMockValue
      }

      return mockMpcShareString
    }
  }

  public static var mockConnectData: ConnectData {
    ConnectData(id: "test-mock-connect-data-id", topic: "test-mock-connect-data-topic", params: SessionProposal(id: 1, params: Params(id: -1, pairingTopic: "", expiry: 1, requiredNamespaces: Namespaces(), relays: [], proposer: Proposer(publicKey: "", metadata: Metadata(description: "", url: "", icons: [], name: "")), verifyContext: nil)))
  }

  public static var mockConnectedData: ConnectedData {
    ConnectedData(id: "test-mock-connected-data-id", topic: "test-mock-connected-data-topic", params: Pairing(active: true, expiry: nil, peerMetadata: PeerMetadata(name: "test-mock-connected-data-peer-metadata-name", description: "test-mock-connected-data-peer-metadata-description", url: "test-mock-connected-data-peer-metadata-url", icons: []), relay: nil, topic: "test-mock-connected-data-peer-metadata-topic"))
  }

  public static var mockDicConnectedData: DisconnectData {
    DisconnectData(id: "test-mock-dis-connected-data-id", topic: "test-mock-dis-connected-data-topic")
  }

  public static var mockSessionRequestData: SessionRequestData {
    SessionRequestData(id: "test-mock-session-request-data-id", params: ProviderRequestParams(chainId: 11_155_111, request: ProviderRequestData(method: "eth_sign", params: ["0x1234"])), topic: "test-mock-session-request-data-topic")
  }

  public static var mockSessionRequestAddressData: SessionRequestAddressData {
    SessionRequestAddressData(id: "test-mock-session-request-data-id", params: ProviderRequestAddressParams(chainId: 11_155_111, request: ProviderRequestAddressData(method: "eth_sign", params: [ETHAddressParam(address: mockEip155Address)])), topic: "test-mock-session-request-data-topic")
  }

  public static var mockSessionRequestTransactionData: SessionRequestTransactionData {
    SessionRequestTransactionData(id: "test-mock-session-request-data-id", params: ProviderRequestTransactionParams(chainId: 11_155_111, request: ProviderRequestTransactionData(method: "eth_sign", params: [ETHTransactionParam(from: mockEip155Address, to: "0xd46e8dd67c5d32be8058bb8eb970870f07244567")])), topic: "test-mock-session-request-data-topic")
  }
}

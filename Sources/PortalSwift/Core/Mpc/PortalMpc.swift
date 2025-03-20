//
//  PortalMpc.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import Security

public protocol PortalMpcProtocol {
  func backup(_ method: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> PortalMpcBackupResponse
  func eject(_ method: BackupMethods, withCipherText: String?, andOrganizationBackupShare: String?, andOrganizationSolanaBackupShare: String?, usingProgressCallback _: ((MpcStatus) -> Void)?) async throws -> [PortalNamespace: String]
  func generate(withProgressCallback: ((MpcStatus) -> Void)?) async throws -> [PortalNamespace: String?]
  func recover(_ method: BackupMethods, withCipherText: String?, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> [PortalNamespace: String?]
  func generateSolanaWallet(usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> String
  func generateSolanaWalletAndBackupShares(backupMethod: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)?) async throws -> (solanaAddress: String, backupResponse: PortalMpcBackupResponse)
  func registerBackupMethod(_ method: BackupMethods, withStorage: PortalStorage)
  func setGDriveConfiguration(clientId: String, backupOption: GDriveBackupOption) throws
  func setGDriveView(_ view: UIViewController) throws
  @available(iOS 16, *)
  func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws
  @available(iOS 16, *)
  func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws
  func setPassword(_ value: String) throws

  // Deprecated functions
  @available(*, deprecated, renamed: "backup", message: "Please use the async/await implementation of backup().")
  func backup(method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  @available(*, deprecated, renamed: "backup", message: "Please use the async/await implementation of generate().")
  func generate(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
  @available(*, deprecated, renamed: "ejectPrivateKey", message: "Please use eject() instead.")
  func ejectPrivateKey(clientBackupCiphertext: String, method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, orgBackupShare: String, completion: @escaping (Result<String>) -> Void)
  @available(*, deprecated, renamed: "recover", message: "Please use the async/await implementation of recover().")
  func recover(cipherText: String, method: BackupMethods.RawValue, backupConfigs: BackupConfigs?, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)?)
}

/// The main interface with Portal's MPC service.
public class PortalMpc: PortalMpcProtocol {
  private var address: String? {
    do {
      return try self.keychain?.getAddress()
    } catch {
      return nil
    }
  }

  private var signingShare: String? {
    do {
      return try self.keychain?.getSigningShare()
    } catch {
      return nil
    }
  }

  private weak var api: PortalApiProtocol?
  private let apiHost: String
  private let apiKey: String
  private var backupOptions: [BackupMethods: PortalStorage] = [:]
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private let featureFlags: FeatureFlags?
  private let host: String
  private let isSimulator: Bool
  private weak var keychain: PortalKeychainProtocol?
  private let logger = PortalLogger()
  private let mobile: Mobile
  private let version: String

  private let rsaHeader = "-----BEGIN RSA KEY-----\n"
  private let rsaFooter = "\n-----END RSA KEY-----"
  private var isWalletModificationInProgress: Bool = false
  private var isMock: Bool = false
  private var mpcMetadata: MpcMetadata

  /// Create an instance of Portal's MPC service.
  public init(
    apiKey: String,
    api: PortalApiProtocol,
    keychain: PortalKeychainProtocol,
    host: String = "mpc.portalhq.io",
    isSimulator: Bool = false,
    version: String = "v6",
    mobile: Mobile,
    apiHost: String = "api.portalhq.io",
    featureFlags: FeatureFlags? = nil
  ) {
    // Basic setup
    self.api = api
    self.apiKey = apiKey
    self.host = host
    self.keychain = keychain
    self.version = version
    self.mobile = mobile
    self.apiHost = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"

    // Other stuff
    self.featureFlags = featureFlags
    self.isSimulator = isSimulator
    self.mpcMetadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      clientPlatformVersion: SDK_VERSION,
      isMultiBackupEnabled: featureFlags?.isMultiBackupEnabled,
      mpcServerVersion: self.version
    )
  }

  /*******************************************
   * Public functions
   *******************************************/

  /// Creates a backup share, encrypts it, and stores the private key in cloud storage.
  /// - Parameters:
  ///   - method: Either gdrive or icloud.
  ///   - completion: The callback which includes the cipherText of the backed up share.
  public func backup(
    _ method: BackupMethods,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> PortalMpcBackupResponse {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    do {
      // Obtain the signing share.
      let shares = try await keychain?.getShares() ?? [:]
      usingProgressCallback?(MpcStatus(status: .readingShare, done: false))

      // Derive the storage and throw an error if none was provided.
      guard let storage = self.backupOptions[method] else {
        throw MpcError.unsupportedStorageMethod
      }
      guard try await storage.validateOperations() else {
        throw MpcError.unexpectedErrorOnBackup("Could not validate operations.")
      }

      usingProgressCallback?(MpcStatus(status: MpcStatuses.generatingShare, done: false))
      // Generate both backup shares in parallel
      let generateResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PortalMpcGenerateResponse, Error>) in
        Task {
          var generateResponse: PortalMpcGenerateResponse = [:]

          // Run both backups in parallel
          if let ed25519SigningShare = shares[PortalCurve.ED25519.rawValue] {
            do {
              async let mpcShare = try getBackupShare(.ED25519, withMethod: method, andSigningShare: ed25519SigningShare.share)

              usingProgressCallback?(MpcStatus(status: .parsingShare, done: false))
              let shareData = try await encoder.encode(mpcShare)
              guard let shareString = String(data: shareData, encoding: .utf8) else {
                throw MpcError.unexpectedErrorOnBackup("Unable to stringify ED25519 share.")
              }

              generateResponse["ED25519"] = try await PortalMpcGeneratedShare(
                id: mpcShare.backupSharePairId ?? "",
                share: shareString
              )
            } catch {
              continuation.resume(throwing: error)
              return
            }
          }
          if let secp256k1SigningShare = shares[PortalCurve.SECP256K1.rawValue]?.share {
            do {
              async let mpcShare = try getBackupShare(.SECP256K1, withMethod: method, andSigningShare: secp256k1SigningShare)

              usingProgressCallback?(MpcStatus(status: .parsingShare, done: false))
              let shareData = try await encoder.encode(mpcShare)
              guard let shareString = String(data: shareData, encoding: .utf8) else {
                throw MpcError.unexpectedErrorOnBackup("Unable to stringify SECP256K1 share.")
              }

              generateResponse["SECP256K1"] = try await PortalMpcGeneratedShare(
                id: mpcShare.backupSharePairId ?? "",
                share: shareString
              )
            } catch {
              continuation.resume(throwing: error)
              return
            }
          }

          continuation.resume(returning: generateResponse)
        }
      }

      let responseData = try encoder.encode(generateResponse)
      guard let responseString = String(data: responseData, encoding: .utf8) else {
        throw MpcError.unexpectedErrorOnBackup("Unable to stringify into GenerateResponse")
      }

      usingProgressCallback?(MpcStatus(status: .encryptingShare, done: false))
      let encryptResult = try await storage.encrypt(responseString)

      usingProgressCallback?(MpcStatus(status: .storingShare, done: false))
      let success = try await storage.write(encryptResult.key)
      if !success {
        throw MpcError.unexpectedErrorOnBackup("Unable to write encryption key.")
      }

      // Update the share statuses
      let shareIds = generateResponse.values.map { share in
        share.id
      }
      try await self.api?.updateShareStatus(.backup, status: .STORED_CLIENT_BACKUP_SHARE_KEY, sharePairIds: shareIds)

      guard let client = try await api?.client else {
        throw MpcError.clientInformationUnavailable
      }

      if client.environment?.backupWithPortalEnabled ?? false {
        for share in generateResponse.values {
          let successful = try await api?.storeClientCipherText(share.id, cipherText: encryptResult.cipherText) ?? false

          if !successful {
            self.logger.error("[PortalMpc] Unable to store client cipherText.")
            throw MpcError.unableToStoreClientCipherText
          }
        }
      }

      // Refresh the client
      try await self.api?.refreshClient()
      try await self.keychain?.loadMetadata()

      self.isWalletModificationInProgress = false

      // Send the last progress update
      usingProgressCallback?(MpcStatus(status: .done, done: true))

      // Return the Backup response
      return PortalMpcBackupResponse(cipherText: encryptResult.cipherText, shareIds: shareIds)
    } catch {
      self.isWalletModificationInProgress = false
      throw error
    }
  }

  public func eject(
    _ method: BackupMethods,
    withCipherText: String? = nil,
    andOrganizationBackupShare: String? = nil,
    andOrganizationSolanaBackupShare: String? = nil,
    usingProgressCallback _: ((MpcStatus) -> Void)? = nil
  ) async throws -> [PortalNamespace: String] {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Eject is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    var cipherText = withCipherText
    var organizationShare = andOrganizationBackupShare

    guard let storage = self.backupOptions[method] else {
      throw MpcError.unexpectedErrorOnEject("Backup method \(method.rawValue) not registered.")
    }

    guard let client = try await api?.client else {
      throw MpcError.clientInformationUnavailable
    }

    var backupSharePairId: String?
    var SECP256K1WalletId: String?
    var Ed25519WalletId: String?

    for wallet in client.wallets {
      if wallet.curve == .SECP256K1 {
        // Locate the appropriate wallet for Ethereum
        for backupShare in wallet.backupSharePairs {
          if backupShare.status == .completed, backupShare.backupMethod == method {
            backupSharePairId = backupShare.id
            SECP256K1WalletId = wallet.id
            break
          }
        }
      } else if wallet.curve == .ED25519 {
        // Locate the appropriate wallet for Solana
        for backupShare in wallet.backupSharePairs {
          if backupShare.status == .completed, backupShare.backupMethod == method {
            Ed25519WalletId = wallet.id
            break
          }
        }
      }
    }

    // Always enforce Ethereum values are present
    guard let SECP256K1WalletId else {
      throw MpcError.unableToEjectWallet("No backed up wallet found for curve SECP256K1.")
    }
    guard let backupSharePairId else {
      throw MpcError.unableToEjectWallet("No backup share pair found for curve SECP256K1.")
    }

    let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false
    if backupWithPortal {
      cipherText = try await self.api?.getClientCipherText(backupSharePairId)
      organizationShare = try await self.api?.prepareEject(SECP256K1WalletId, method)

      // Conditionally prepare eject for Solana wallets
      if let Ed25519WalletId {
        _ = try? await self.api?.prepareEject(Ed25519WalletId, method)
      }
    }

    // Always enforce Ethereum values are present
    guard let cipherText else {
      throw MpcError.noBackupCipherTextFound
    }
    guard let organizationShare else {
      throw MpcError.noOrganizationShareFound("No organization share found for Ethereum wallet.")
    }

    let decryptionKey = try await storage.read()
    let decryptedString = try await storage.decrypt(cipherText, withKey: decryptionKey)

    // Use the new formatShares function
    let formattedShares = try await formatShares(sharesJSONString: decryptedString)

    var privateKeys: [PortalNamespace: String] = [:]

    if let secp256k1Share = formattedShares["SECP256K1"] {
      let ejectResponse = await self.mobile.MobileEjectWalletAndDiscontinueMPC(secp256k1Share.share, organizationShare)
      guard let jsonData = ejectResponse.data(using: .utf8) else {
        throw JSONParseError.stringToDataConversionFailed
      }

      let ejectResult: EjectResult = try decoder.decode(EjectResult.self, from: jsonData)

      if let error = ejectResult.error, error.isValid() {
        throw PortalMpcError(error)
      }

      privateKeys[.eip155] = ejectResult.privateKey
    }

    if let ed25519Share = formattedShares["ED25519"],
       let organizationShareEd25519 = andOrganizationSolanaBackupShare
    {
      let ejectResponse = await self.mobile.MobileEjectWalletAndDiscontinueMPCEd25519(ed25519Share.share, organizationShareEd25519)
      guard let jsonData = ejectResponse.data(using: .utf8) else {
        throw JSONParseError.stringToDataConversionFailed
      }

      let ejectResult: EjectResult = try decoder.decode(EjectResult.self, from: jsonData)

      if let error = ejectResult.error, error.isValid() {
        throw PortalMpcError(error)
      }

      privateKeys[.solana] = ejectResult.privateKey
    }

    _ = try await self.api?.eject()

    guard privateKeys[.eip155] != nil else {
      throw MpcError.unexpectedErrorOnEject("Unable to find private key for Ethereum wallet.")
    }

    return privateKeys
  }

  public func generate(withProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> [PortalNamespace: String?] {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Generate is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    do {
      // Generate both backup shares in parallel
      let generateResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PortalMpcGenerateResponse, Error>) in
        Task { [self] in
          do {
            withProgressCallback?(MpcStatus(status: .generatingShare, done: false))

            var generateResponse: PortalMpcGenerateResponse = [:]

            async let ed25519Generate = try self.getSigningShare(.ED25519)
            async let secp256k1Generate = try self.getSigningShare(.SECP256K1)

            let (ed25519MpcShare, secp256k1MpcShare) = try await (ed25519Generate, secp256k1Generate)

            withProgressCallback?(MpcStatus(status: .parsingShare, done: false))

            // Parse ED25519 Share
            let ed25519ShareData = try self.encoder.encode(ed25519MpcShare)
            guard let ed25519ShareString = String(data: ed25519ShareData, encoding: .utf8) else {
              throw MpcError.unexpectedErrorOnGenerate("Unable to stringify ED25519 share.")
            }
            generateResponse["ED25519"] = PortalMpcGeneratedShare(
              id: ed25519MpcShare.signingSharePairId ?? "",
              share: ed25519ShareString
            )

            // Parse SECP256K1 Share
            let secp256k1ShareData = try self.encoder.encode(secp256k1MpcShare)
            guard let secp256k1ShareString = String(data: secp256k1ShareData, encoding: .utf8) else {
              throw MpcError.unexpectedErrorOnGenerate("Unable to stringify ED25519 share.")
            }
            generateResponse["SECP256K1"] = PortalMpcGeneratedShare(
              id: secp256k1MpcShare.signingSharePairId ?? "",
              share: secp256k1ShareString
            )

            continuation.resume(returning: generateResponse)
          } catch {
            continuation.resume(throwing: error)
            return
          }
        }
      }

      withProgressCallback?(MpcStatus(status: .storingShare, done: false))
      try await self.keychain?.setShares(generateResponse)

      // Update share statuses
      let shareIds: [String] = generateResponse.values.map { share in
        share.id
      }
      try await self.api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: shareIds)

      // Reset the metadata in the Keychain
      try await self.api?.refreshClient()
      try await self.keychain?.loadMetadata()

      let addresses = try await keychain?.getAddresses() ?? [:]

      self.isWalletModificationInProgress = false
      withProgressCallback?(MpcStatus(status: .done, done: true))

      return addresses
    } catch {
      self.isWalletModificationInProgress = false
      throw error
    }
  }

  public func recover(
    _ method: BackupMethods,
    withCipherText: String? = nil,
    usingProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> [PortalNamespace: String?] {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    do {
      guard let client = try await api?.client else {
        throw MpcError.clientInformationUnavailable
      }

      var cipherText = withCipherText

      // Fetch the cipherText if necessary
      if client.environment?.backupWithPortalEnabled ?? false {
        var backupSharePairId: String?

        for wallet in client.wallets {
          for backupSharePair in wallet.backupSharePairs {
            if backupSharePair.status == .completed, backupSharePair.backupMethod == method {
              backupSharePairId = backupSharePair.id
            }
          }
        }

        guard let backupSharePairId else {
          throw MpcError.noValidBackupFound
        }

        cipherText = try await self.api?.getClientCipherText(backupSharePairId)
      }

      guard let cipherText else {
        throw MpcError.noBackupCipherTextFound
      }

      guard let storage = self.backupOptions[method] else {
        throw MpcError.unexpectedErrorOnRecover("Storage method \(method.rawValue) not registered.")
      }

      let recoverResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PortalMpcGenerateResponse, Error>) in
        Task {
          do {
            usingProgressCallback?(MpcStatus(status: .readingShare, done: false))
            let decryptionKey = try await storage.read()

            usingProgressCallback?(MpcStatus(status: .decryptingShare, done: false))
            let decryptedSharesString = try await storage.decrypt(cipherText, withKey: decryptionKey)
            usingProgressCallback?(MpcStatus(status: .parsingShare, done: false))
            let shares = try await formatShares(sharesJSONString: decryptedSharesString)

            usingProgressCallback?(MpcStatus(status: .generatingShare, done: false))
            var recoverResponse: PortalMpcGenerateResponse = [:]
            if let shares = try? await keychain?.getShares() {
              recoverResponse = shares
            }

            var recoveredShareCount = 0

            if let ed25519Share = shares[PortalCurve.ED25519.rawValue] {
              //  The share's already been backed up, recover it
              async let ed25519MpcShare = try recoverSigningShare(.ED25519, withMethod: method, andBackupShare: ed25519Share.share)

              let shareData = try await encoder.encode(ed25519MpcShare)
              guard let shareString = String(data: shareData, encoding: .utf8) else {
                throw MpcError.unexpectedErrorOnBackup("Unable to stringify ED25519 share.")
              }

              recoverResponse["ED25519"] = try await PortalMpcGeneratedShare(
                id: ed25519MpcShare.signingSharePairId ?? "",
                share: shareString
              )
              recoveredShareCount += 1
            }

            if let secp256k1Share = shares[PortalCurve.SECP256K1.rawValue] {
              async let secp256k1MpcShare = try recoverSigningShare(.SECP256K1, withMethod: method, andBackupShare: secp256k1Share.share)

              let shareData = try await encoder.encode(secp256k1MpcShare)
              guard let shareString = String(data: shareData, encoding: .utf8) else {
                throw MpcError.unexpectedErrorOnBackup("Unable to stringify SECP256K1 share.")
              }

              recoverResponse["SECP256K1"] = try await PortalMpcGeneratedShare(
                id: secp256k1MpcShare.signingSharePairId ?? "",
                share: shareString
              )
              recoveredShareCount += 1
            }

            // Check if any shares were recovered
            if recoveredShareCount == 0 {
              throw MpcError.unexpectedErrorOnRecover("No valid shares found in the backup data")
            }

            continuation.resume(returning: recoverResponse)
          } catch {
            continuation.resume(throwing: error)
            return
          }
        }
      }

      usingProgressCallback?(MpcStatus(status: .storingShare, done: false))
      try await self.keychain?.setShares(recoverResponse)

      // Update share statuses
      let shareIds: [String] = recoverResponse.values.map { share in
        share.id
      }

      try await self.api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: shareIds)

      // Reset the metadata in the Keychain
      try await self.api?.refreshClient()
      try await self.keychain?.loadMetadata()

      let addresses = try await keychain?.getAddresses() ?? [:]

      self.isWalletModificationInProgress = false
      usingProgressCallback?(MpcStatus(status: .done, done: true))

      return addresses
    } catch {
      self.isWalletModificationInProgress = false
      throw error
    }
  }

  private func generateSolanaWallet(callerFuncName: String, usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> [PortalNamespace: String?] {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Generate is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    var newAddresses: [PortalNamespace: String?]

    do {
      let addresses = try await keychain?.getAddresses() ?? [:]

      guard addresses[.eip155] ?? nil != nil else {
        throw MpcError.unexpectedErrorOnGenerate("\(callerFuncName) - No eip155 wallet found. Please use createWallet() to generate both eip155 and solana wallets for this client.")
      }

      guard addresses[.solana] ?? nil == nil else {
        throw MpcError.unexpectedErrorOnGenerate("\(callerFuncName) - Could not generate Solana wallet as it already exists.")
      }

      usingProgressCallback?(MpcStatus(status: .generatingShare, done: false))

      // generate the ED25519 share
      let ed25519MpcShare = try await self.getSigningShare(.ED25519)

      // create a share object to be stored to keychain
      var generateResponse: PortalMpcGenerateResponse = [:]

      usingProgressCallback?(MpcStatus(status: .parsingShare, done: false))

      let ed25519ShareData = try self.encoder.encode(ed25519MpcShare)
      guard let ed25519ShareString = String(data: ed25519ShareData, encoding: .utf8) else {
        throw MpcError.unexpectedErrorOnGenerate("Unable to stringify ED25519 share.")
      }
      generateResponse["ED25519"] = PortalMpcGeneratedShare(
        id: ed25519MpcShare.signingSharePairId ?? "",
        share: ed25519ShareString
      )

      // Obtain the signing secpk256k1 share
      let shares = try await keychain?.getShares() ?? [:]

      generateResponse["SECP256K1"] = shares["SECP256K1"]

      usingProgressCallback?(MpcStatus(status: .storingShare, done: false))

      // store the shares to keychain
      try await self.keychain?.setShares(generateResponse)

      // Update share statuses
      let shareIds: [String] = generateResponse.values.map { share in
        share.id
      }
      try await self.api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: shareIds)

      // Reset the metadata in the Keychain
      try await self.api?.refreshClient()
      try await self.keychain?.loadMetadata()
      self.isWalletModificationInProgress = false

      // get addresses from the Keychain.
      newAddresses = try await self.keychain?.getAddresses() ?? [:]

    } catch {
      self.isWalletModificationInProgress = false
      throw error
    }

    return newAddresses
  }

  /// You should only call this function if you are upgrading from v3 to v4.
  public func generateSolanaWallet(usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> String {
    let result: [PortalNamespace: String?] = try await generateSolanaWallet(callerFuncName: "PortalMpc.generateSolanaWallet()", usingProgressCallback: usingProgressCallback)
    if let newSolanaAddress = result[PortalNamespace.solana], let unwrappedNewSolanaAddress = newSolanaAddress {
      usingProgressCallback?(MpcStatus(status: .done, done: true))
      return unwrappedNewSolanaAddress
    } else {
      throw MpcError.unexpectedErrorOnGenerate("Unable to get the Solana address from keychain.")
    }
  }

  /// You should only call this function if you are upgrading from v3 to v4.
  public func generateSolanaWalletAndBackupShares(backupMethod: BackupMethods, usingProgressCallback: ((MpcStatus) -> Void)? = nil) async throws -> (solanaAddress: String, backupResponse: PortalMpcBackupResponse) {
    // generate solana wallet
    let generateSolanaResult: [PortalNamespace: String?] = try await generateSolanaWallet(callerFuncName: "PortalMpc.generateSolanaWalletAndBackupShares()", usingProgressCallback: usingProgressCallback)
    var solanaAddress: String
    if let newSolanaAddress = generateSolanaResult[PortalNamespace.solana], let unwrappedNewSolanaAddress = newSolanaAddress {
      solanaAddress = unwrappedNewSolanaAddress
    } else {
      throw MpcError.unexpectedErrorOnGenerate("Unable to get the Solana address from keychain.")
    }

    // backup
    let backupResult = try await self.backup(backupMethod, usingProgressCallback: usingProgressCallback)

    return (solanaAddress, backupResult)
  }

  public func registerBackupMethod(_ method: BackupMethods, withStorage: PortalStorage) {
    var storage = withStorage
    storage.api = self.api

    if #available(iOS 16, *) {
      if method == .Passkey {
        (storage as! PasskeyStorage).apiKey = self.apiKey
      }
    }

    self.backupOptions[method] = storage
  }

  public func setGDriveConfiguration(clientId: String, backupOption: GDriveBackupOption) throws {
    guard let storage = backupOptions[.GoogleDrive] as? GDriveStorage else {
      throw MpcError.backupMethodNotRegistered("PortalMpc.setGDriveConfig() - Could not find an instance of `GDriveStorage`. Please use `portal.registerBackupMethod()`")
    }

    if case .gdriveFolder(let folderName) = backupOption {
      storage.folder = folderName
    }

    storage.backupOption = backupOption
    storage.clientId = clientId
  }

  public func setGDriveView(_ view: UIViewController) throws {
    guard let storage = backupOptions[.GoogleDrive] as? GDriveStorage else {
      throw MpcError.backupMethodNotRegistered("PortalMpc.setGDriveView() - Could not find an instance of `GDriveStorage`. Please use `portal.registerBackupMethod()`")
    }

    storage.view = view
  }

  @available(iOS 16, *)
  public func setPasskeyAuthenticationAnchor(_ anchor: ASPresentationAnchor) throws {
    guard let storage = backupOptions[.Passkey] as? PasskeyStorage else {
      throw MpcError.backupMethodNotRegistered("PortalMpc.setPasskeyAuthenticationAnchor() - Could not find an instance of `PasskeyStorage`. Please use `portal.registerBackupMethod()`")
    }

    storage.anchor = anchor
  }

  @available(iOS 16, *)
  public func setPasskeyConfiguration(relyingParty: String, webAuthnHost: String) throws {
    guard let storage = backupOptions[.Passkey] as? PasskeyStorage else {
      throw MpcError.backupMethodNotRegistered("PortalMpc.setPasskeyConfiguration() - Could not find an instance of `PasskeyStorage`. Please use `portal.registerBackupMethod()`")
    }

    storage.auth.domain = relyingParty
    storage.relyingParty = relyingParty
    storage.webAuthnHost = "https://" + webAuthnHost
  }

  public func setPassword(_ value: String) throws {
    guard let storage = backupOptions[.Password] as? PasswordStorage else {
      throw MpcError.backupMethodNotRegistered("Could not find an instance of `PasswordStorage`. Please use `portal.registerBackupMethod()`")
    }

    storage.password = value
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func getBackupShare(
    _ forCurve: PortalCurve,
    withMethod: BackupMethods,
    andSigningShare: String
  ) async throws -> MpcShare {
    let mpcShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MpcShare, Error>) in
      Task {
        do {
          // Stringify the MPC metadata.
          var metadata = self.mpcMetadata
          metadata.curve = forCurve
          metadata.backupMethod = withMethod.rawValue
          metadata.isMultiBackupEnabled = self.featureFlags?.isMultiBackupEnabled

          let mpcMetadataString = try metadata.jsonString()

          let response = forCurve == .ED25519
            ? await self.mobile.MobileBackupEd25519(self.apiKey, self.host, andSigningShare, self.apiHost, mpcMetadataString)
            : await self.mobile.MobileBackupSecp256k1(self.apiKey, self.host, andSigningShare, self.apiHost, mpcMetadataString)

          // Parse the backup share.
          let jsonData = response.data(using: .utf8)!
          let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: jsonData)

          // Throw if there is an error getting the backup share.
          if let error = rotateResult.error, error.isValid() {
            continuation.resume(throwing: PortalMpcError(error))
            return
          }

          // Attach the backup share to the signing share JSON.
          let backupShare = rotateResult.data!.share

          continuation.resume(returning: backupShare)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return mpcShare
  }

  private func getSigningShare(_ forCurve: PortalCurve) async throws -> MpcShare {
    let mpcShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MpcShare, Error>) in
      Task {
        do {
          // Stringify the MPC metadata.
          var metadata = self.mpcMetadata
          metadata.curve = forCurve

          let mpcMetadataString = try metadata.jsonString()
          let response = forCurve == .ED25519
            ? await self.mobile.MobileGenerateEd25519(self.apiKey, self.host, self.apiHost, mpcMetadataString)
            : await self.mobile.MobileGenerateSecp256k1(self.apiKey, self.host, self.apiHost, mpcMetadataString)

          // Parse the backup share.
          let jsonData = response.data(using: .utf8)!
          let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: jsonData)

          // Throw if there is an error getting the backup share.
          if let error = rotateResult.error, error.isValid() {
            self.logger.error("Error generating \(forCurve.rawValue) share: \(rotateResult.error?.message ?? "")")
            continuation.resume(throwing: PortalMpcError(error))
            return
          }

          let signingShare = rotateResult.data!.share

          continuation.resume(returning: signingShare)
        } catch {
          self.logger.error("Error generating \(forCurve.rawValue) share: \(error.localizedDescription)")
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return mpcShare
  }

  private func formatShares(sharesJSONString: String) async throws -> PortalMpcGenerateResponse {
    let formattedSharesString = self.mobile.MobileFormatShares(sharesJSONString)

    guard let jsonData = formattedSharesString.data(using: .utf8) else {
      throw MpcError.unableToDecodeShare
    }

    do {
      let result = try JSONDecoder().decode(FormatShareResponse.self, from: jsonData)

      if let error = result.error {
        throw MpcError.unexpectedErrorOnRecover("Error formatting shares: \(String(describing: error.message))")
      }

      guard let data = result.data else {
        throw MpcError.unexpectedErrorOnRecover("No data returned from MobileFormatShares")
      }

      return data
    } catch {
      print("Error decoding formatted shares: \(error)")
      throw MpcError.unableToDecodeShare
    }
  }

  private func recoverSigningShare(_ forCurve: PortalCurve, withMethod: BackupMethods, andBackupShare: String) async throws -> MpcShare {
    let mpcShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MpcShare, Error>) in
      Task {
        do {
          // Stringify the MPC metadata.
          var metadata = self.mpcMetadata
          metadata.curve = forCurve
          metadata.backupMethod = withMethod.rawValue
          metadata.isMultiBackupEnabled = self.featureFlags?.isMultiBackupEnabled

          let mpcMetadataString = try metadata.jsonString()

          let response = forCurve == .ED25519
            ? await self.mobile.MobileRecoverSigningEd25519(self.apiKey, self.host, andBackupShare, self.apiHost, mpcMetadataString)
            : await self.mobile.MobileRecoverSigningSecp256k1(self.apiKey, self.host, andBackupShare, self.apiHost, mpcMetadataString)

          // Parse the backup share.
          let jsonData = response.data(using: .utf8)!
          let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: jsonData)

          // Throw if there is an error getting the backup share.
          if let error = rotateResult.error, error.isValid() {
            continuation.resume(throwing: PortalMpcError(error))
            return
          }

          let signingShare = rotateResult.data!.share

          continuation.resume(returning: signingShare)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return mpcShare
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Creates a backup share, encrypts it, and stores the private key in cloud storage.
  /// - Parameters:
  ///   - method: Either gdrive or icloud.
  ///   - completion: The callback which includes the cipherText of the backed up share.
  @available(*, deprecated, renamed: "backup", message: "Please use the async/await implementation of backup().")
  public func backup(
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    Task {
      do {
        let backupMethod = BackupMethods(rawValue: method)!
        if backupMethod == .Password, let storage = backupOptions[backupMethod] as? PasswordStorage {
          storage.password = backupConfigs?.passwordStorage?.password
        }

        let response = try await backup(backupMethod, usingProgressCallback: progress)

        completion(Result(data: response.cipherText))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Generates a MPC wallet and signing share for a client.
  /// - Returns: The address of the newly created MPC wallet.
  @available(*, deprecated, renamed: "backup", message: "Please use the async/await implementation of generate().")
  public func generate(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    Task {
      do {
        _ = try await self.generate(withProgressCallback: progress)
        guard let address = try await keychain?.getAddress("eip155:1") else {
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        completion(Result(data: address))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Uses the org and client backup shares to return the private key
  ///  - Parameters:
  ///    - cipherText: the cipherText of the client's backup share
  ///    - method: The specific backup storage option.
  ///    - orgShare: the stringified version of the organization's backup share
  @available(*, deprecated, renamed: "ejectPrivateKey", message: "Please use eject() instead.")
  public func ejectPrivateKey(
    clientBackupCiphertext: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    orgBackupShare: String,
    completion: @escaping (Result<String>) -> Void
  ) {
    Task {
      do {
        let backupMethod = BackupMethods(rawValue: method)!
        if backupMethod == .Password, let storage = backupOptions[backupMethod] as? PasswordStorage {
          storage.password = backupConfigs?.passwordStorage?.password
        }
        let addresses = try await eject(backupMethod, withCipherText: clientBackupCiphertext, andOrganizationBackupShare: orgBackupShare)

        guard let eip155PrivateKey = addresses[.eip155] else {
          throw MpcError.unableToEjectWallet("No EIP155 private key found.")
        }

        completion(Result(data: eip155PrivateKey))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Uses the backup share to create a new signing share.
  /// - Parameters:
  ///   - cipherText: the cipherText of the backup share (should be passed in from the custodian).
  ///   - method: The specific backup storage option.
  ///   - completion: The callback which includes the wallet's address.
  @available(*, deprecated, renamed: "recover", message: "Please use the async/await implementation of recover().")
  public func recover(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    Task {
      do {
        let backupMethod = BackupMethods(rawValue: method)!
        if backupMethod == .Password, let storage = backupOptions[backupMethod] as? PasswordStorage {
          storage.password = backupConfigs?.passwordStorage?.password
        }

        _ = try await self.recover(backupMethod, withCipherText: cipherText, usingProgressCallback: progress)

        guard let address = try await keychain?.getAddress("eip155:1") else {
          throw PortalKeychain.KeychainError.noAddressesFound
        }
        completion(Result(data: address))
      } catch {
        completion(Result(error: error))
      }
    }
  }
}

public enum MpcStatuses: String {
  case decryptingShare = "Decrypting share"
  case done = "Done"
  case encryptingShare = "Encrypting share"
  case generatingShare = "Generating share"
  case parsingShare = "Parsing share"
  case readingShare = "Reading share"
  case recoveringBackupShare = "Recovering backup share"
  case recoveringSigningShare = "Recovering signing share"
  case storingShare = "Storing share"
}

/// A list of errors MPC can throw.
public enum MpcError: LocalizedError, Equatable {
  case addressNotFound(_ message: String)
  case backupMethodNotRegistered(_ message: String)
  case backupNoLongerSupported(_ message: String)
  case clientInformationUnavailable
  case failedToEncryptClientBackupShare(_ message: String)
  case failedToGetBackupFromStorage
  case failedToRecoverBackup(_ message: String)
  case failedToStoreClientBackupShareKey(_ message: String)
  case failedToValidateBackupMethod
  case generateNoLongerSupported(_ message: String)
  case noBackupCipherTextFound
  case noOrganizationShareFound(_ message: String = "No organization share found.")
  case noSigningSharePresent
  case noValidBackupFound
  case recoverNoLongerSupported(_ message: String)
  case signingRecoveryError(_ message: String)
  case unableToAuthenticate
  case unableToDecodeShare
  case unableToEjectWallet(String)
  case unableToRetrieveClient(String)
  case unableToStoreClientCipherText
  case unableToWriteToKeychain
  case unexpectedErrorOnBackup(_ message: String)
  case unexpectedErrorOnDecrypt(_ message: String)
  case unexpectedErrorOnEject(_ message: String)
  case unexpectedErrorOnEncrypt(_ message: String)
  case unexpectedErrorOnGenerate(_ message: String)
  case unexpectedErrorOnRecover(_ message: String)
  case unexpectedErrorOnSign(_ message: String)
  case unsupportedStorageMethod
  case unwrappingAddress
  case walletModificationAlreadyInProgress
}

/// A list of errors RSA can throw.
public enum RsaError: LocalizedError {
  case unableToCreatePrivateKey(message: String)
  case incompatibleKeyWithAlgorithm
  case dataIsTooLongForKey
  case unableToGetPublicKey
  case incorrectCipherTextFormat
}

public enum JSONParseError: LocalizedError {
  case stringToDataConversionFailed
  case jsonDecodingFailed
}

public enum ReadSigningSharePairIdError: LocalizedError {
  case noSigningSharePairIdFound
}

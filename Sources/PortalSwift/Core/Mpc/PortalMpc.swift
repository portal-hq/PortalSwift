//
//  PortalMpc.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc
import Security

/// The main interface with Portal's MPC service.
public class PortalMpc {
  private var address: String? {
    do {
      return try self.keychain.getAddress()
    } catch {
      return nil
    }
  }

  private var signingShare: String? {
    do {
      return try self.keychain.getSigningShare()
    } catch {
      return nil
    }
  }

  private let api: PortalApi
  private let apiHost: String
  private let apiKey: String
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private let featureFlags: FeatureFlags?
  private let host: String
  private let isSimulator: Bool
  private let keychain: PortalKeychain
  private let mobile: Mobile
  private let storage: BackupOptions
  private let version: String

  private let rsaHeader = "-----BEGIN RSA KEY-----\n"
  private let rsaFooter = "\n-----END RSA KEY-----"
  private var isWalletModificationInProgress: Bool = false
  private var isMock: Bool = false
  private var mpcMetadata: MpcMetadata

  /// Create an instance of Portal's MPC service.
  public init(
    apiKey: String,
    api: PortalApi,
    keychain: PortalKeychain,
    storage: BackupOptions,
    isSimulator: Bool = false,
    host: String = "mpc.portalhq.io",
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
    self.storage = storage
    self.version = version
    self.mobile = mobile
    self.apiHost = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"

    // Other stuff
    self.featureFlags = featureFlags
    self.isSimulator = isSimulator
    self.mpcMetadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      isMultiBackupEnabled: featureFlags?.isMultiBackupEnabled,
      mpcServerVersion: self.version,
      optimized: featureFlags?.optimized ?? false
    )
  }

  public func getBinaryVersion() -> String {
    self.mobile.MobileGetVersion()
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
    withProgressCallback: ((MpcStatus) -> Void)? = nil
  ) async throws -> String {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    do {
      // Obtain the signing share.
      let shares = try await keychain.getShares()
      withProgressCallback?(MpcStatus(status: .readingShare, done: false))

      // Derive the storage and throw an error if none was provided.
      guard let storage = self.storage[method.rawValue] as? PortalStorage else {
        throw MpcError.unsupportedStorageMethod
      }
      guard try await storage.validateOperations() else {
        throw MpcError.unexpectedErrorOnBackup("Could not validate operations.")
      }

      // Generate both backup shares in parallel
      let generateResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PortalMpcGenerateResponse, Error>) in
        Task {
          var generateResponse: PortalMpcGenerateResponse = [:]

          // Run both backups in parallel
          if let ed25519SigningShare = shares[PortalCurve.ED25519.rawValue] {
            do {
              async let mpcShare = try getBackupShare(.ED25519, withMethod: method, andSigningShare: ed25519SigningShare.share)

              withProgressCallback?(MpcStatus(status: .parsingShare, done: false))
              let shareData = try encoder.encode(await mpcShare)
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
          if let secp256k1SigningShare = shares[PortalCurve.SECP256K1.rawValue] {
            do {
              async let mpcShare = try getBackupShare(.SECP256K1, withMethod: method, andSigningShare: secp256k1SigningShare.share)

              withProgressCallback?(MpcStatus(status: .parsingShare, done: false))
              let shareData = try encoder.encode(await mpcShare)
              guard let shareString = String(data: shareData, encoding: .utf8) else {
                throw MpcError.unexpectedErrorOnBackup("Unable to stringify SECP256K1 share.")
              }

              generateResponse["SECP256K1"] = try await PortalMpcGeneratedShare(
                id: mpcShare.backupSharePairId ?? "",
                share: shareString
              )
            } catch {
              continuation.resume(throwing: error)
            }
          }

          continuation.resume(returning: generateResponse)
        }
      }

      let responseData = try encoder.encode(generateResponse)
      guard let responseString = String(data: responseData, encoding: .utf8) else {
        throw MpcError.unexpectedErrorOnBackup("Unable to stringify into GenerateResponse")
      }

      withProgressCallback?(MpcStatus(status: .encryptingShare, done: false))
      let encryptResult = try await storage.encrypt(responseString)

      withProgressCallback?(MpcStatus(status: .storingShare, done: false))
      let success = try await storage.write(encryptResult.key)
      if !success {
        throw MpcError.unexpectedErrorOnBackup("Unable to write encryption key.")
      }

      withProgressCallback?(MpcStatus(status: .done, done: true))
      self.isWalletModificationInProgress = false
      return encryptResult.cipherText
    } catch {
      self.isWalletModificationInProgress = false
      throw error
    }
  }

  private func generate(withProgressCallback: ((MpcStatus) -> Void)? = nil) async throws {
    if self.version != "v6" {
      throw MpcError.backupNoLongerSupported("[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = \"v6\"`.")
    }

    guard !self.isWalletModificationInProgress else {
      throw MpcError.walletModificationAlreadyInProgress
    }

    self.isWalletModificationInProgress = true

    // Generate both backup shares in parallel
    let generateResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PortalMpcGenerateResponse, Error>) in
      Task {
        var generateResponse: PortalMpcGenerateResponse = [:]

        async let ed2551MmpcShare = try getSigningShare(.ED25519, withProgressCallback: withProgressCallback)
        async let secp256K1Share = try getSigningShare(.SECP256K1, withProgressCallback: withProgressCallback)

        let ed25519ShareData = try encoder.encode(await ed2551MmpcShare)
        guard let ed25519ShareString = String(data: ed25519ShareData, encoding: .utf8) else {
          throw MpcError.unexpectedErrorOnBackup("Unable to stringify ED25519 share.")
        }

        generateResponse["ED25519"] = try await PortalMpcGeneratedShare(
          id: mpcShare.backupSharePairId ?? "",
          share: shareString
        )

        continuation.resume(returning: generateResponse)
      }
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func getBackupShare(
    _: PortalCurve,
    withMethod _: BackupMethods,
    andSigningShare: String,
    progress: ((MpcStatus) -> Void)? = nil
  ) async throws -> MpcShare {
    // Call the MPC service to generate a backup share.
    progress?(MpcStatus(status: MpcStatuses.generatingShare, done: false))

    let mpcShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MpcShare, Error>) in
      do {
        // Stringify the MPC metadata.
        let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""
        let response = self.mobile.MobileBackup(self.apiKey, self.host, andSigningShare, self.apiHost, mpcMetadataString)

        // Parse the backup share.
        let jsonData = response.data(using: .utf8)!
        let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: jsonData)

        // Throw if there is an error getting the backup share.
        guard rotateResult.error.code == 0 else {
          continuation.resume(throwing: PortalMpcError(rotateResult.error))
          return
        }

        // Attach the backup share to the signing share JSON.
        let backupShare = rotateResult.data!.dkgResult

        continuation.resume(returning: backupShare)
      } catch {
        continuation.resume(throwing: error)
      }
    }

    return mpcShare
  }

  private func getSigningShare(_: PortalCurve, withProgressCallback _: ((MpcStatus) -> Void)? = nil) async throws -> MpcShare {}

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
    if self.version != "v6" {
      return completion(Result(error: MpcError.backupNoLongerSupported("[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = v6`.")))
    }

    guard !self.isWalletModificationInProgress else {
      print("❌ A wallet modification operation is already in progress.")
      return completion(Result(error: MpcError.walletModificationAlreadyInProgress))
    }

    self.isWalletModificationInProgress = true

    do {
      // Obtain the signing share.
      let signingShare = try keychain.getSigningShare()
      progress?(MpcStatus(status: MpcStatuses.readingShare, done: false))

      // Derive the storage and throw an error if none was provided.
      guard let storage = self.storage[method] as? Storage else {
        self.isWalletModificationInProgress = false
        return completion(Result(error: MpcError.unsupportedStorageMethod))
      }

      // Check if we are authenticated with iCloud or throw an error if we are not.
      if method == BackupMethods.iCloud.rawValue {
        print("Validating iCloud Storage is available...")
        (storage as! ICloudStorage).validateOperations { (result: Result<Bool>) in
          if result.error != nil {
            print("❌ iCloud Storage is not available:")
            print(result)
            self.isWalletModificationInProgress = false
            return completion(Result(error: result.error!))
          }
          print("iCloud Storage is available, continuing...")

          self.executeBackup(storage: storage, signingShare: signingShare, backupMethod: method) { backupResult in
            if backupResult.error != nil {
              self.isWalletModificationInProgress = false
              return completion(Result(error: backupResult.error!))
            }

            progress?(MpcStatus(status: MpcStatuses.done, done: true))

            // Capture analytics.
            do {
              try self.api.identify { _ in }
              self.api.track(event: MetricsEvents.walletBackedUp.rawValue, properties: [:])
            } catch {
              // Do nothing.
            }

            self.isWalletModificationInProgress = false
            return completion(backupResult)
          } progress: { status in
            progress?(status)
          }
        }
      } else if method == BackupMethods.GoogleDrive.rawValue {
        print("Validating Google Drive Storage is available...")
        (storage as! GDriveStorage).validateOperations { (result: Result<Bool>) in
          if result.error != nil {
            print("❌ Google Drive Storage is not available:")
            print(result)
            self.isWalletModificationInProgress = false
            return completion(Result(error: result.error!))
          }
          print("Google Drive Storage is available, starting backup...")

          self.executeBackup(storage: storage, signingShare: signingShare, backupMethod: method) { backupResult in
            self.handleExecuteBackupCompletion(result: backupResult, progress: progress, completion: completion)
          } progress: { status in
            progress?(status)
          }
        }
      } else if method == BackupMethods.Passkey.rawValue {
        print("Validating Passkey Storage is available...")
        // @TODO add a validation method for passkeys
        print("Passkey Storage is available, starting backup...")

        self.executeBackup(storage: storage, signingShare: signingShare, backupMethod: method) { backupResult in
          self.handleExecuteBackupCompletion(result: backupResult, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      } else if method == BackupMethods.Password.rawValue {
        print("Starting Password Storage...")
        // This is validating that password is set before running backup.
        guard (backupConfigs?.passwordStorage?.password) != nil else {
          return completion(Result(error: PasswordStorageError.passwordMissing("Make sure you pass a PasswordStorage Config in backupConfigs when using the password backup method.")))
        }
        self.executeBackup(storage: storage, signingShare: signingShare, backupMethod: method, backupConfigs: backupConfigs) { backupResult in
          self.handleExecuteBackupCompletion(result: backupResult, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      } else if method == BackupMethods.local.rawValue {
        print("Starting backup...")
        self.executeBackup(storage: storage, signingShare: signingShare, backupMethod: method) { backupResult in
          self.handleExecuteBackupCompletion(result: backupResult, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      } else {
        self.isWalletModificationInProgress = false
        return completion(Result(error: MpcError.unsupportedStorageMethod))
      }
    } catch {
      self.isWalletModificationInProgress = false
      return completion(Result(error: MpcError.unexpectedErrorOnBackup("Backup failed")))
    }
  }

  private func handleExecuteBackupCompletion(
    result: Result<String>,
    progress: ((MpcStatus) -> Void)?,
    completion: @escaping (Result<String>) -> Void
  ) {
    if let error = result.error {
      self.isWalletModificationInProgress = false
      return completion(Result(error: error))
    }

    progress?(MpcStatus(status: MpcStatuses.done, done: true))

    // Capture analytics.
    do {
      try self.api.identify { _ in }
      self.api.track(event: MetricsEvents.walletBackedUp.rawValue, properties: [:])
    } catch {
      // Do nothing.
    }

    self.isWalletModificationInProgress = false
    return completion(result)
  }

  /// Generates a MPC wallet and signing share for a client.
  /// - Returns: The address of the newly created MPC wallet.
  @available(*, deprecated, renamed: "backup", message: "Please use the async/await implementation of generate().")
  public func generate(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    DispatchQueue.global(qos: .background).async { [self] in
      if self.version != "v6" {
        let result = Result<String>(error: MpcError.generateNoLongerSupported(
          "[PortalMpc] Generate is no longer supported for this version of MPC. Please use `version = v6`."
        ))
        completion(result)
      }

      guard !self.isWalletModificationInProgress else {
        print("❌ A wallet modification operation is already in progress.")
        return completion(Result(error: MpcError.walletModificationAlreadyInProgress))
      }

      self.isWalletModificationInProgress = true

      print("Validating Keychain is available...")
      self.keychain.validateOperations { result in
        // Handle errors
        if let error = result.error {
          print("❌ Keychain is not available:")
          self.isWalletModificationInProgress = false
          return completion(Result(error: error))
        }
        print("Keychain is available, continuing...")

        do {
          // Stringify the MPC metadata.
          let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

          // Call the MPC service to generate a new wallet.
          progress?(MpcStatus(status: MpcStatuses.generatingShare, done: false))
          let response = self.mobile.MobileGenerate(self.apiKey, self.host, self.apiHost, mpcMetadataString)

          // Parse the share
          progress?(MpcStatus(status: MpcStatuses.parsingShare, done: false))
          guard let jsonData = response.data(using: .utf8) else {
            self.isWalletModificationInProgress = false
            return completion(Result(error: JSONParseError.stringToDataConversionFailed))
          }

          let generateResult: GenerateResult = try JSONDecoder().decode(GenerateResult.self, from: jsonData)

          // Throw if there was an error generating the wallet.
          guard generateResult.error.code == 0 else {
            self.isWalletModificationInProgress = false
            return completion(Result(error: PortalMpcError(generateResult.error)))
          }

          // Set the client's address.
          let address = generateResult.data!.address

          // Set the client's signing share
          let mpcShare = generateResult.data!.dkgResult
          let mpcShareData = try JSONEncoder().encode(mpcShare)
          let mpcShareString = String(data: mpcShareData, encoding: .utf8)!

          progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))

          self.keychain.setSigningShare(signingShare: mpcShareString) { result in
            // Handle errors
            if result.error != nil {
              self.isWalletModificationInProgress = false
              return completion(Result(error: result.error!))
            }

            self.keychain.setAddress(address: address) { result in
              // Handle errors
              if result.error != nil {
                self.isWalletModificationInProgress = false
                return completion(Result(error: result.error!))
              }

              guard let signingSharePairId = mpcShare?.signingSharePairId else {
                return completion(Result(error: ReadSigningSharePairIdError.noSigningSharePairIdFound))
              }

              do {
                try self.api.storedClientSigningShare(signingSharePairId: signingSharePairId) { result in
                  // Handle errors
                  if result.error != nil {
                    self.isWalletModificationInProgress = false
                    return completion(Result(error: result.error!))
                  }

                  progress?(MpcStatus(status: MpcStatuses.done, done: true))

                  // Capture analytics.
                  do {
                    try self.api.identify { _ in }
                    self.api.track(event: MetricsEvents.walletCreated.rawValue, properties: [:])
                  } catch {
                    // Do nothing.
                  }

                  // Return the address.
                  self.isWalletModificationInProgress = false
                  return completion(Result(data: address))
                }
              } catch {
                self.isWalletModificationInProgress = false
                return completion(Result(error: error))
              }
            }
          }
        } catch {
          self.isWalletModificationInProgress = false
          return completion(Result(error: error))
        }
      }
    }
  }

  /// Uses the org and client backup shares to return the private key
  ///  - Parameters:
  ///    - cipherText: the cipherText of the client's backup share
  ///    - method: The specific backup storage option.
  ///    - orgShare: the stringified version of the organization's backup share
  @available(*, deprecated, renamed: "ejectPrivateKey", message: "Please use the async/await implementation of ejectPrivateKey().")
  public func ejectPrivateKey(
    clientBackupCiphertext: String,
    method: BackupMethods.RawValue,
    backupConfigs _: BackupConfigs? = nil,
    orgBackupShare: String,
    completion: @escaping (Result<String>) -> Void
  ) {
    if self.version != "v6" {
      completion(Result(error: MpcError.recoverNoLongerSupported("[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v6`.")))
    }

    self.getBackupShare(cipherText: clientBackupCiphertext, method: method) { (result: Result<String>) in
      guard result.error == nil else {
        completion(Result(error: result.error!))
        return
      }
      if let clientBackupShare = result.data {
        do {
          // Call eject with clientBackupShare and orShare
          let response = self.mobile.MobileEjectWalletAndDiscontinueMPC(clientBackupShare, orgBackupShare)
          guard let jsonData = response.data(using: .utf8) else {
            return completion(Result(error: JSONParseError.stringToDataConversionFailed))
          }

          let ejectResult: EjectResult = try JSONDecoder().decode(EjectResult.self, from: jsonData)

          // Throw if there was an error generating the wallet.
          guard ejectResult.error.code == 0 else {
            return completion(Result(error: PortalMpcError(ejectResult.error)))
          }

          // Set the client's private key.
          let privateKey = ejectResult.privateKey

          // Call API backend to set the client as ejected
          do {
            try self.api.ejectClient { (apiResult: Result<String>) in
              // Throw an error if we can't update the client's ejectedAt.
              if let error = apiResult.error {
                return completion(Result(error: error))
              }

              // Return the privateKey.
              return completion(Result(data: privateKey))
            }
          } catch {
            return completion(Result(error: error))
          }
        } catch {
          return completion(Result(error: error))
        }
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
    if self.version != "v6" {
      return completion(Result(error: MpcError.recoverNoLongerSupported("[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v6`.")))
    }

    guard !self.isWalletModificationInProgress else {
      print("❌ A wallet modification operation is already in progress.")
      return completion(Result(error: MpcError.walletModificationAlreadyInProgress))
    }

    self.isWalletModificationInProgress = true

    // Derive the storage and throw an error if none was provided.
    let storage = self.storage[method] as? Storage
    if storage == nil {
      self.isWalletModificationInProgress = false
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }

    print("Validating Keychain is available...")
    self.keychain.validateOperations { result in
      // Handle errors
      if result.error != nil {
        print("❌ Keychain is not available:")
        self.isWalletModificationInProgress = false
        return completion(Result(error: result.error!))
      }
      print("Keychain is available, continuing...")

      if method == BackupMethods.iCloud.rawValue {
        print("Validating iCloud Storage is available...")
        (storage as! ICloudStorage).validateOperations { (result: Result<Bool>) in
          if result.error != nil {
            print("❌ iCloud Storage is not available:")
            print(result)
            self.isWalletModificationInProgress = false
            return completion(Result(error: result.error!))
          }
          print("iCloud Storage is available, continuing...")

          // Call the MPC service to get the backup share.
          self.executeRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
            if recoveryResult.error != nil {
              self.isWalletModificationInProgress = false
              return completion(Result(error: recoveryResult.error!))
            }
            progress?(MpcStatus(status: MpcStatuses.done, done: true))

            // Capture analytics.
            do {
              try self.api.identify { _ in }
              self.api.track(event: MetricsEvents.walletRecovered.rawValue, properties: [:])
            } catch {
              // Do nothing.
            }

            self.isWalletModificationInProgress = false
            return completion(Result(data: recoveryResult.data!))
          } progress: { status in
            progress?(status)
          }
        }
      } else if method == BackupMethods.GoogleDrive.rawValue {
        print("Validating Google Drive Storage is available...")
        (storage as! GDriveStorage).validateOperations { (result: Result<Bool>) in
          if result.error != nil {
            print("❌ Google Drive Storage is not available:")
            print(result)
            self.isWalletModificationInProgress = false
            return completion(Result(error: result.error!))
          }
          print("Google Drive Storage is available, starting backup...")

          self.executeRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
            if recoveryResult.error != nil {
              self.isWalletModificationInProgress = false
              return completion(Result(error: recoveryResult.error!))
            }
            progress?(MpcStatus(status: MpcStatuses.done, done: true))

            // Capture analytics.
            do {
              try self.api.identify { _ in }
              self.api.track(event: MetricsEvents.walletRecovered.rawValue, properties: [:])
            } catch {
              // Do nothing.
            }

            self.isWalletModificationInProgress = false
            return completion(Result(data: recoveryResult.data!))
          } progress: { status in
            progress?(status)
          }
        }
      } else if method == BackupMethods.Passkey.rawValue {
        print("Validating Passkey Storage is available...")
        // @TODO add a validation method for passkeys
        print("Passkey Storage is available, starting recovery...")
        self.executeRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
          if recoveryResult.error != nil {
            self.isWalletModificationInProgress = false
            return completion(Result(error: recoveryResult.error!))
          }
          progress?(MpcStatus(status: MpcStatuses.done, done: true))
          self.isWalletModificationInProgress = false
          return completion(Result(data: recoveryResult.data!))
        } progress: { status in
          progress?(status)
        }

      } else if method == BackupMethods.local.rawValue || method == BackupMethods.Password.rawValue {
        self.executeRecovery(storage: storage!, method: method, backupConfigs: backupConfigs, cipherText: cipherText) { recoveryResult in
          if recoveryResult.error != nil {
            self.isWalletModificationInProgress = false
            return completion(Result(error: recoveryResult.error!))
          }
          progress?(MpcStatus(status: MpcStatuses.done, done: true))

          // Capture analytics.
          do {
            try self.api.identify { _ in }
            self.api.track(event: MetricsEvents.walletRecovered.rawValue, properties: [:])
          } catch {
            // Do nothing.
          }

          self.isWalletModificationInProgress = false
          return completion(Result(data: recoveryResult.data!))
        } progress: { status in
          progress?(status)
        }
      } else {
        self.isWalletModificationInProgress = false
        return completion(Result(error: MpcError.unsupportedStorageMethod))
      }
    }
  }

  private func decryptShare(cipherText: String, privateKey: String, method: BackupMethods.RawValue, progress: ((MpcStatus) -> Void)? = nil) throws -> String {
    progress?(MpcStatus(status: MpcStatuses.decryptingShare, done: false))
    let result = method == BackupMethods.Password.rawValue ? self.mobile.MobileDecryptWithPassword(privateKey, cipherText) : self.mobile.MobileDecrypt(privateKey, cipherText)

    progress?(MpcStatus(status: MpcStatuses.parsingShare, done: false))
    let jsonResult = result.data(using: .utf8)!
    let decryptResult: DecryptResult = try JSONDecoder().decode(DecryptResult.self, from: jsonResult)

    // Throw if there was an error decrypting the value.
    guard decryptResult.error.code == 0 else {
      throw PortalMpcError(decryptResult.error)
    }

    return decryptResult.data!.plaintext
  }

  /// Encrypts the backup share using a public key that it creates.
  /// - Parameter
  ///   - mpcShare: The share to encrypt.
  /// - Returns: The cipherText and the private key.
  @available(*, deprecated, renamed: "storage.encrypt", message: "Please use storage.encrypt() to encrypt shares.")
  private func encryptShare(
    mpcShare: MpcShare,
    completion: (Result<EncryptData>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
      progress?(MpcStatus(status: MpcStatuses.encryptingShare, done: false))
      let mpcShareData = try JSONEncoder().encode(mpcShare)
      let mpcShareString = String(data: mpcShareData, encoding: .utf8)!

      let result = self.mobile.MobileEncrypt(mpcShareString)
      let jsonResult = result.data(using: .utf8)!
      let encryptResult: EncryptResult = try JSONDecoder().decode(EncryptResult.self, from: jsonResult)

      guard encryptResult.error.code == 0 else {
        return completion(Result(error: PortalMpcError(encryptResult.error)))
      }

      return completion(Result(data: encryptResult.data!))
    } catch {
      return completion(Result(error: error))
    }
  }

  /// Encrypts the backup share using password from the user.
  /// - Parameter
  ///   - mpcShare: The share to encrypt.
  /// - Returns: The cipherText and the private key.
  @available(*, deprecated, renamed: "storage.encrypt", message: "Please use storage.encrypt() to encrypt shares.")
  private func encryptShareWithPassword(
    mpcShare: MpcShare,
    password: String,
    completion: (Result<EncryptDataWithPassword>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
      progress?(MpcStatus(status: MpcStatuses.encryptingShare, done: false))
      let mpcShareData = try JSONEncoder().encode(mpcShare)
      guard let mpcShareString = String(data: mpcShareData, encoding: .utf8) else {
        throw MpcError.unexpectedErrorOnEncrypt("Failed to convert mpc share data to string")
      }

      let result = self.mobile.MobileEncryptWithPassword(data: mpcShareString, password: password)
      guard let jsonResult = result.data(using: .utf8) else {
        throw MpcError.unexpectedErrorOnEncrypt("Failed to convert encrypted string to data")
      }
      let encryptResult: EncryptResultWithPassword = try JSONDecoder().decode(EncryptResultWithPassword.self, from: jsonResult)

      guard encryptResult.error.code == 0 else {
        return completion(Result(error: PortalMpcError(encryptResult.error)))
      }

      return completion(Result(data: encryptResult.data!))
    } catch {
      return completion(Result(error: error))
    }
  }

  private func executeBackup(
    storage: Storage,
    signingShare: String,
    backupMethod: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
      // Add the backup method.
      self.mpcMetadata.backupMethod = backupMethod

      // Stringify the MPC metadata.
      let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

      // Call the MPC service to generate a backup share.
      progress?(MpcStatus(status: MpcStatuses.generatingShare, done: false))
      let response = self.mobile.MobileBackup(self.apiKey, self.host, signingShare, self.apiHost, mpcMetadataString)

      // Parse the backup share.
      progress?(MpcStatus(status: MpcStatuses.parsingShare, done: false))
      let jsonData = response.data(using: .utf8)!
      let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: jsonData)

      // Throw if there is an error getting the backup share.
      guard rotateResult.error.code == 0 else {
        return completion(Result(error: PortalMpcError(rotateResult.error)))
      }

      // Attach the backup share to the signing share JSON.
      let backupShare = rotateResult.data!.dkgResult

      if backupMethod == BackupMethods.Password.rawValue {
        // Encrypt the backup share.
        guard let password = backupConfigs?.passwordStorage?.password else {
          return completion(Result(error: PasswordStorageError.passwordMissing("Make sure you pass a PasswordStorage Config in backupConfigs")))
        }
        self.encryptShareWithPassword(mpcShare: backupShare, password: password) { encryptedResult in
          self.handleEncryptedShareWithPasswordCompletion(encryptedResult: encryptedResult, storage: storage, backupMethod: backupMethod, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      } else {
        // Encrypt the backup share.
        self.encryptShare(mpcShare: backupShare) { encryptedResult in
          self.handleEncryptedShareCompletion(encryptedResult: encryptedResult, storage: storage, backupMethod: backupMethod, backupSharePairId: backupShare.backupSharePairId!, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup("Backup failed")))
    }
  }

  @available(*, deprecated, renamed: "removed", message: "Please use storage.encrypt() to encrypt shares.")
  private func handleStorageWriteCompletion(
    result: Result<Bool>,
    encryptedData: EncryptData,
    backupMethod: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) {
    // Throw an error if we can't write to storage.
    if let error = result.error {
      return completion(Result(error: error))
    }

    do {
      // Call api to update backup status to `STORED_CLIENT_BACKUP_SHARE_KEY`.
      try self.api.storedClientBackupShareKey(success: true, backupMethod: backupMethod) { (apiResult: Result<String>) in
        // Throw an error if we can't update the backup status + save the backup method.
        if let error = apiResult.error {
          return completion(Result(error: error))
        }

        // Return the cipherText.
        return completion(Result(data: encryptedData.cipherText))
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup("Backup failed")))
    }
  }

  @available(*, deprecated, renamed: "removed", message: "This functionality is no longer supported.")
  private func handleEncryptedShareWithPasswordCompletion(
    encryptedResult: Result<EncryptDataWithPassword>,
    storage _: Storage,
    backupMethod: BackupMethods.RawValue,
    progress: ((MpcStatus) -> Void)?,
    completion: @escaping (Result<String>) -> Void
  ) {
    guard encryptedResult.error == nil else {
      return completion(Result(error: encryptedResult.error!))
    }

    // Attempt to write the encrypted share to storage.
    progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))

    do {
      // Call api to update backup status to `STORED_CLIENT_BACKUP_SHARE_KEY`.
      try self.api.storedClientBackupShareKey(success: true, backupMethod: backupMethod) { (apiResult: Result<String>) in
        // Throw an error if we can't update the backup status + save the backup method.
        if let error = apiResult.error {
          return completion(Result(error: error))
        }
        guard let cipherText = encryptedResult.data?.cipherText else {
          return completion(Result(error: MpcError.unexpectedErrorOnEncrypt("Unknown Error")))
        }
        // Return the cipherText.
        return completion(Result(data: cipherText))
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup("Backup failed")))
    }
  }

  private func handleEncryptedShareCompletion(
    encryptedResult: Result<EncryptData>,
    storage: Storage,
    backupMethod: BackupMethods.RawValue,
    backupSharePairId _: String,
    progress: ((MpcStatus) -> Void)?,
    completion: @escaping (Result<String>) -> Void
  ) {
    if let error = encryptedResult.error {
      return completion(Result(error: error))
    }

    // Attempt to write the encrypted share to storage.
    progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))

    guard let encryptedData = encryptedResult.data else {
      return completion(Result(error: MpcError.unexpectedErrorOnEncrypt("Unknown Error")))
    }

    storage.write(privateKey: encryptedData.key) { (result: Result<Bool>) in
      self.handleStorageWriteCompletion(result: result, encryptedData: encryptedData, backupMethod: backupMethod, completion: completion)
    }
  }

  @available(*, deprecated, renamed: "executeRecovery", message: "Please use the async/await implementation of executeRecovery().")
  private func executeRecovery(
    storage _: Storage,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    cipherText: String,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    progress?(MpcStatus(status: MpcStatuses.readingShare, done: false))
    self.getBackupShare(cipherText: cipherText, method: method, backupConfigs: backupConfigs) { (result: Result<String>) in
      // Throw if there was an error getting the backup share.
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      progress?(MpcStatus(status: MpcStatuses.recoveringSigningShare, done: false))
      self.recoverSigning(backupShare: result.data!) { signingResult in
        if signingResult.error != nil {
          return completion(Result(error: signingResult.error!))
        }

        // Throw if address is nil.
        guard let unwrappedAddress = self.address else {
          return completion(Result(error: MpcError.unwrappingAddress))
        }

        return completion(Result(data: unwrappedAddress))
      } progress: { status in
        progress?(status)
      }
    } progress: { status in
      progress?(status)
    }
  }

  /// Loads the private key from cloud storage, uses that to decrypt the cipherText, and returns the string of the backup share.
  /// - Parameters:
  ///   - cipherText: The cipherText of the backup share.
  ///   - method: The storage method.
  ///   - completion: The completion handler that includes the backup share string.
  @available(*, deprecated, renamed: "getBackupShare", message: "Please use the async/await implementation of getBackupShare().")
  private func getBackupShare(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    // Derive the storage and throw an error if none was provided.
    guard let storage = self.storage[method] as? Storage else {
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }

    if method == BackupMethods.Password.rawValue {
      // Attempt to decrypt the cipherText.
      do {
        // Encrypt the backup share.
        guard let password = backupConfigs?.passwordStorage?.password else {
          return completion(Result(error: PasswordStorageError.passwordMissing("Make sure you pass a PasswordStorage Config in backupConfigs")))
        }
        let backupShare = try self.decryptShare(cipherText: cipherText, privateKey: password, method: method) { status in
          progress?(status)
        }
        return completion(Result(data: backupShare))
      } catch {
        return completion(Result(error: error))
      }
    } else {
      // Attempt to read the private key from storage.
      storage.read { (result: Result<String>) in
        // If the private key was not found, return an error.
        guard let privateKey = result.data else {
          return completion(Result(error: MpcError.failedToGetBackupFromStorage))
        }

        // Attempt to decrypt the cipherText.
        do {
          let backupShare = try self.decryptShare(cipherText: cipherText, privateKey: privateKey, method: method) { status in
            progress?(status)
          }
          return completion(Result(data: backupShare))
        } catch {
          return completion(Result(error: error))
        }
      }
    }
  }

  /// Uses the signing share to create a new backup share and returns that share in JSON format.
  /// - Parameter
  ///   - clientBackupShare: The signing share as a string.
  /// - Returns: The backup share.
  @available(*, deprecated, renamed: "recoverBackup", message: "Please use the async/await implementation of recoverBackup().")
  private func recoverBackup(
    clientBackupShare: String,
    backupMethod: BackupMethods.RawValue,
    completion: (Result<MpcShare>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
      // Add the backup method.
      self.mpcMetadata.backupMethod = backupMethod

      // Stringify the MPC metadata.
      let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

      // Call the MPC service to recover the backup share.
      progress?(MpcStatus(status: MpcStatuses.generatingShare, done: false))
      let result = self.mobile.MobileRecoverBackup(self.apiKey, self.host, clientBackupShare, self.apiHost, mpcMetadataString)

      progress?(MpcStatus(status: MpcStatuses.parsingShare, done: false))
      let rotateResult: RotateResult = try JSONDecoder().decode(RotateResult.self, from: result.data(using: .utf8)!)

      // Throw an error if the MPC service returned an error.
      guard rotateResult.error.code == 0 else {
        return completion(Result(error: PortalMpcError(rotateResult.error)))
      }

      // Return the new backup share.
      return completion(Result(data: rotateResult.data!.dkgResult))
    } catch {
      return completion(Result(error: error))
    }
  }

  /// Uses the backup share to create a new signing share and stores it in the keychain.
  /// - Parameter
  ///   - backupShare: The backup share.
  /// - Returns: The new signing share.
  @available(*, deprecated, renamed: "recoverSigning", message: "Please use the async/await implementation of recoverSigning().")
  private func recoverSigning(
    backupShare: String,
    completion: @escaping (Result<MpcShare>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
      // Stringify the MPC metadata.
      let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

      // Call the MPC service to recover the signing share.
      progress?(MpcStatus(status: MpcStatuses.generatingShare, done: false))
      let result = self.mobile.MobileRecoverSigning(self.apiKey, self.host, backupShare, self.apiHost, mpcMetadataString)

      progress?(MpcStatus(status: MpcStatuses.parsingShare, done: false))
      let rotateResult = try JSONDecoder().decode(RotateResult.self, from: result.data(using: .utf8)!)

      // Throw an error if the MPC service returned an error.
      guard rotateResult.error.code == 0 else {
        return completion(Result(error: PortalMpcError(rotateResult.error)))
      }

      if rotateResult.data == nil {
        return completion(Result(error: MpcError.signingRecoveryError("Could not read recovery data")))
      }

      // Store the signing share in the keychain.
      progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))
      guard let dkgResult = rotateResult.data?.dkgResult else {
        return completion(Result(error: JSONParseError.jsonDecodingFailed))
      }

      let encodedShare = try JSONEncoder().encode(dkgResult)
      let shareString = String(data: encodedShare, encoding: .utf8)

      guard let address = rotateResult.data?.address else {
        return completion(Result(error: JSONParseError.jsonDecodingFailed))
      }

      self.keychain.setAddress(address: address) { result in
        // Handle errors
        if let error = result.error {
          return completion(Result(error: error))
        }

        self.keychain.setSigningShare(signingShare: shareString!) { result in
          // Handle errors
          if let error = result.error {
            return completion(Result(error: error))
          }

          guard let signingSharePairId = dkgResult.signingSharePairId else {
            return completion(Result(error: ReadSigningSharePairIdError.noSigningSharePairIdFound))
          }

          do {
            try self.api.storedClientSigningShare(signingSharePairId: signingSharePairId) { result in
              // Handle errors
              if let error = result.error {
                return completion(Result(error: error))
              }

              guard let dkgResult = rotateResult.data?.dkgResult else {
                return completion(Result(error: MpcError.unableToWriteToKeychain))
              }

              // Return the new signing share.
              return completion(Result(data: dkgResult))
            }
          } catch {
            return completion(Result(error: error))
          }
        }
      }
    } catch {
      return completion(Result(error: MpcError.unableToWriteToKeychain))
    }
  }

  /// Helper function to parse the MPC share from a JSON string.
  /// - Parameter
  ///   - shareString: The JSON string of the MPC share.
  /// - Returns: An MPC share.
  private func JSONParseShare(shareString: String) throws -> MpcShare {
    var shareJson: MpcShare
    do {
      guard let jsonString = shareString.data(using: .utf8) else {
        throw JSONParseError.stringToDataConversionFailed
      }
      shareJson = try JSONDecoder().decode(MpcShare.self, from: jsonString)
    } catch {
      throw MpcError.unableToDecodeShare
    }

    return shareJson
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
public enum MpcError: Error {
  case addressNotFound(_ message: String)
  case backupNoLongerSupported(_ message: String)
  case failedToEncryptClientBackupShare(_ message: String)
  case failedToGetBackupFromStorage
  case failedToRecoverBackup(_ message: String)
  case failedToStoreClientBackupShareKey(_ message: String)
  case failedToValidateBackupMethod
  case generateNoLongerSupported(_ message: String)
  case noSigningSharePresent
  case recoverNoLongerSupported(_ message: String)
  case signingRecoveryError(_ message: String)
  case unableToAuthenticate
  case unableToDecodeShare
  case unableToRetrieveClient(String)
  case unableToWriteToKeychain
  case unexpectedErrorOnBackup(_ message: String)
  case unexpectedErrorOnDecrypt(_ message: String)
  case unexpectedErrorOnEncrypt(_ message: String)
  case unexpectedErrorOnGenerate(_ message: String)
  case unexpectedErrorOnRecoverBackup(_ message: String)
  case unexpectedErrorOnSign(_ message: String)
  case unsupportedStorageMethod
  case unwrappingAddress
  case walletModificationAlreadyInProgress
}

/// A list of errors RSA can throw.
public enum RsaError: Error {
  case unableToCreatePrivateKey(message: String)
  case incompatibleKeyWithAlgorithm
  case dataIsTooLongForKey
  case unableToGetPublicKey
  case incorrectCipherTextFormat
}

public enum JSONParseError: Error {
  case stringToDataConversionFailed
  case jsonDecodingFailed
}

public enum ReadSigningSharePairIdError: Error {
  case noSigningSharePairIdFound
}

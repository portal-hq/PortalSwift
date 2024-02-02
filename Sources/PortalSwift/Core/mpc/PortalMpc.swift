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

  private let mobile: Mobile
  private let api: PortalApi
  private let apiKey: String
  private let host: String
  private let apiHost: String
  private let isSimulator: Bool
  private let keychain: PortalKeychain
  private var signingShare: String? {
    do {
      return try self.keychain.getSigningShare()
    } catch {
      return nil
    }
  }

  private let storage: BackupOptions
  private let version: String
  private let featureFlags: FeatureFlags?

  private let rsaHeader = "-----BEGIN RSA KEY-----\n"
  private let rsaFooter = "\n-----END RSA KEY-----"
  private var isWalletModificationInProgress: Bool = false
  private var isMock: Bool = false
  private let mpcMetadata: MpcMetadata

  /// Create an instance of Portal's MPC service.
  public init(
    apiKey: String,
    api: PortalApi,
    keychain: PortalKeychain,
    storage: BackupOptions,
    isSimulator: Bool = false,
    host: String = "mpc.portalhq.io",
    version: String = "v5",
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
      mpcServerVersion: self.version,
      optimized: featureFlags?.optimized ?? false
    )
  }

  public func getBinaryVersion() -> String {
    self.mobile.MobileGetVersion()
  }

  /// Creates a backup share, encrypts it, and stores the private key in cloud storage.
  /// - Parameters:
  ///   - method: Either gdrive or icloud.
  ///   - completion: The callback which includes the cipherText of the backed up share.
  public func backup(
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    if self.version != "v5" {
      return completion(Result(error: MpcError.backupNoLongerSupported(message: "[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = v5`.")))
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
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
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
  public func generate(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    DispatchQueue.global(qos: .background).async { [self] in
      if self.version != "v5" {
        let result = Result<String>(error: MpcError.generateNoLongerSupported(
          message: "[PortalMpc] Generate is no longer supported for this version of MPC. Please use `version = v5`."
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
  public func ejectPrivateKey(
    clientBackupCiphertext: String,
    method: BackupMethods.RawValue,
    backupConfigs _: BackupConfigs? = nil,
    orgBackupShare: String,
    completion: @escaping (Result<String>) -> Void
  ) {
    if self.version != "v5" {
      completion(Result(error: MpcError.recoverNoLongerSupported(message: "[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v5`.")))
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
  public func recover(
    cipherText: String,
    method: BackupMethods.RawValue,
    backupConfigs: BackupConfigs? = nil,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    if self.version != "v5" {
      return completion(Result(error: MpcError.recoverNoLongerSupported(message: "[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v5`.")))
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

  /// Uses the backup share to create a new signing share and a new backup share, encrypts the new backup share, and stores the private key in storage.
  /// - Parameters:
  ///   - cipherText: the cipherText of the backup share (should be passed in from the custodian).
  ///   - method: The specific backup storage option.
  ///   - completion: The callback which includes the cipherText of the new backup share.
  @available(*, deprecated, renamed: "recover")
  public func legacyRecover(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    if self.version != "v5" {
      return completion(Result(error: MpcError.recoverNoLongerSupported(message: "[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v5`.")))
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
          self.executeLegacyRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
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

          self.executeLegacyRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
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
        }
      } else if method == BackupMethods.local.rawValue {
        self.executeLegacyRecovery(storage: storage!, method: method, cipherText: cipherText) { recoveryResult in
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
        throw MpcError.unexpectedErrorOnEncrypt(message: "Failed to convert mpc share data to string")
      }

      let result = self.mobile.MobileEncryptWithPassword(data: mpcShareString, password: password)
      guard let jsonResult = result.data(using: .utf8) else {
        throw MpcError.unexpectedErrorOnEncrypt(message: "Failed to convert encrypted string to data")
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
          self.handleEncryptedShareCompletion(encryptedResult: encryptedResult, storage: storage, backupMethod: backupMethod, progress: progress, completion: completion)
        } progress: { status in
          progress?(status)
        }
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
    }
  }

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
      // Call api to update backup method + update backup status to `STORED_CLIENT_BACKUP_SHARE_KEY`.
      let formattedBackupMethod = self.formatBackupMethod(backupMethod: backupMethod)
      try self.api.storedClientBackupShareKey(backupMethod: formattedBackupMethod) { (apiResult: Result<String>) in
        // Throw an error if we can't update the backup status + save the backup method.
        if let error = apiResult.error {
          return completion(Result(error: error))
        }

        // Return the cipherText.
        return completion(Result(data: encryptedData.cipherText))
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
    }
  }

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
      // Call api to update backup method + update backup status to `STORED_CLIENT_BACKUP_SHARE_KEY`.
      let formattedBackupMethod = self.formatBackupMethod(backupMethod: backupMethod)
      try self.api.storedClientBackupShareKey(backupMethod: formattedBackupMethod) { (apiResult: Result<String>) in
        // Throw an error if we can't update the backup status + save the backup method.
        if let error = apiResult.error {
          return completion(Result(error: error))
        }
        guard let cipherText = encryptedResult.data?.cipherText else {
          return completion(Result(error: MpcError.unexpectedErrorOnEncrypt(message: "Unknown Error")))
        }
        // Return the cipherText.
        return completion(Result(data: cipherText))
      }
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
    }
  }

  private func handleEncryptedShareCompletion(
    encryptedResult: Result<EncryptData>,
    storage: Storage,
    backupMethod: BackupMethods.RawValue,
    progress: ((MpcStatus) -> Void)?,
    completion: @escaping (Result<String>) -> Void
  ) {
    if let error = encryptedResult.error {
      return completion(Result(error: error))
    }

    // Attempt to write the encrypted share to storage.
    progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))

    guard let encryptedData = encryptedResult.data else {
      return completion(Result(error: MpcError.unexpectedErrorOnEncrypt(message: "Unknown Error")))
    }

    storage.write(privateKey: encryptedData.key) { (result: Result<Bool>) in
      self.handleStorageWriteCompletion(result: result, encryptedData: encryptedData, backupMethod: backupMethod, completion: completion)
    }
  }

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

  private func executeLegacyRecovery(
    storage: Storage,
    method: BackupMethods.RawValue,
    cipherText: String,
    completion: @escaping (Result<String>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    progress?(MpcStatus(status: MpcStatuses.readingShare, done: false))
    self.getBackupShare(cipherText: cipherText, method: method) { (result: Result<String>) in
      // Throw if there was an error getting the backup share.
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      progress?(MpcStatus(status: MpcStatuses.recoveringSigningShare, done: false))
      self.recoverSigning(backupShare: result.data!) { signingResult in
        if signingResult.error != nil {
          return completion(Result(error: signingResult.error!))
        }

        progress?(MpcStatus(status: MpcStatuses.recoveringBackupShare, done: false))

        self.recoverBackup(clientBackupShare: result.data!) { backupResult in
          if backupResult.error != nil {
            print("Signing shares were successfully replaced, but backup shares were not refreshed. Try running backup again with your new signing shares.")
            if let error = backupResult.error {
              return completion(Result(error: MpcError.failedToRecoverBackup(message: error.localizedDescription)))
            } else {
              return completion(Result(error: MpcError.failedToRecoverBackup(message: "")))
            }
          }

          self.encryptShare(mpcShare: backupResult.data!) { encryptedResult in
            // Handle errors
            if encryptedResult.error != nil {
              print("Signing shares were successfully replaced, but backup shares were not refreshed. Try running backup again with your new signing shares.")
              if let error = encryptedResult.error {
                return completion(Result(error: MpcError.failedToEncryptClientBackupShare(message: error.localizedDescription)))
              } else {
                return completion(Result(error: MpcError.failedToEncryptClientBackupShare(message: "")))
              }
            }

            // Attempt to write the encrypted share to storage.
            progress?(MpcStatus(status: MpcStatuses.storingShare, done: false))

            storage.write(privateKey: encryptedResult.data!.key) { (result: Result<Bool>) in
              // Throw an error if we can't write to storage.
              guard result.data != nil else {
                print("Signing shares were successfully replaced, but backup shares were not refreshed. Try running backup again with your new signing shares.")
                if let error = result.error {
                  return completion(Result(error: MpcError.failedToStoreClientBackupShareKey(message: error.localizedDescription)))
                } else {
                  return completion(Result(error: MpcError.failedToStoreClientBackupShareKey(message: "")))
                }
              }

              do {
                // Call api to update backup method + update backup status to `STORED_CLIENT_BACKUP_SHARE_KEY`.
                let formattedBackupMethod = self.formatBackupMethod(backupMethod: method)
                try self.api.storedClientBackupShareKey(backupMethod: formattedBackupMethod) { (result: Result<String>) in
                  // Throw an error if we can't update the backup status + save the backup method.
                  if result.error != nil {
                    print("Signing shares were successfully replaced, but backup shares were not refreshed. Try running backup again with your new signing shares.")
                    if let error = result.error {
                      return completion(Result(error: MpcError.failedToStoreClientBackupShareKey(message: error.localizedDescription)))
                    } else {
                      return completion(Result(error: MpcError.failedToStoreClientBackupShareKey(message: "")))
                    }
                  }

                  // Return the cipherText.
                  return completion(Result(data: encryptedResult.data!.cipherText))
                }
              } catch {
                print("Signing shares were successfully replaced, but backup shares were not refreshed. Try running backup again with your new signing shares.")
                return completion(Result(error: MpcError.failedToStoreClientBackupShareKey(message: "")))
              }
            }
          } progress: { status in
            progress?(status)
          }
        } progress: { status in
          progress?(status)
        }
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
          print(result.error)
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
  ///   - signingShare: The signing share as a string.
  /// - Returns: The backup share.
  private func recoverBackup(
    clientBackupShare: String,
    completion: (Result<MpcShare>) -> Void,
    progress: ((MpcStatus) -> Void)? = nil
  ) {
    do {
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
        return completion(Result(error: MpcError.signingRecoveryError(message: "Could not read recovery data")))
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

  private func formatBackupMethod(backupMethod: BackupMethods.RawValue) -> String {
    switch backupMethod {
    case BackupMethods.GoogleDrive.rawValue:
      return "GDRIVE"
    case BackupMethods.iCloud.rawValue:
      return "ICLOUD"
    case BackupMethods.Password.rawValue:
      return "PASSWORD"
    default:
      return "CUSTOM"
    }
  }
}

// DATA TYPES

/// A MPC share that includes a variable number of fields, depending on the MPC version being used
/// GG18 shares will only contain: bks, pubkey, and share
/// CGGMP shares will contain all fields except: pubkey.
public struct MpcShare: Codable {
  public var allY: PartialPublicKey?
  public var bks: Berkhoffs?
  public var clientId: String
  public var p: String
  public var partialPubkey: PartialPublicKey?
  public var pederson: Pedersons?
  public var pubkey: PublicKey?
  public var q: String
  public var share: String
  public var signingSharePairId: String?
  public var ssid: String
}

/// In the bks dictionary for an MPC share, Berkhoff is the value.
public struct Berkhoff: Codable {
  public var X: String
  public var Rank: Int
}

/// A partial public key for client and server (x, y)
public struct PartialPublicKey: Codable {
  public var client: PublicKey?
  public var server: PublicKey?
}

/// A berhkoff coefficient mapping for client and server (x, rank)
public struct Berkhoffs: Codable {
  public var client: Berkhoff?
  public var server: Berkhoff?
}

public struct Pederson: Codable {
  public var n: String?
  public var s: String?
  public var t: String?
}

public struct Pedersons: Codable {
  public var client: Pederson?
  public var server: Pederson?
}

/// A public key's coordinates (x, y).
public struct PublicKey: Codable {
  public var X: String?
  public var Y: String?
}

private struct DecryptResult: Codable {
  public var data: DecryptData?
  public var error: PortalError
}

private struct DecryptData: Codable {
  public var plaintext: String
}

/// The response from encrypting.
private struct EncryptDataWithPassword: Codable {
  public var cipherText: String
}

private struct EncryptResultWithPassword: Codable {
  public var data: EncryptDataWithPassword?
  public var error: PortalError
}

/// The response from encrypting.
private struct EncryptData: Codable {
  public var key: String
  public var cipherText: String
}

private struct EncryptResult: Codable {
  public var data: EncryptData?
  public var error: PortalError
}

/// The response from fetching the client.
public struct ClientResult: Codable {
  public var data: Client?
  public var error: PortalError
}

/// The response from fetching the client.
public struct EjectResult: Codable {
  public var privateKey: String
  public var error: PortalError
}

/// The data for GenerateResult.
public struct GenerateData: Codable {
  public var address: String
  public var dkgResult: MpcShare?
}

/// The response from generating.
private struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: PortalError
}

/// The data for RotateResult.
public struct RotateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}

/// The response from rotating.
private struct RotateResult: Codable {
  public var data: RotateData?
  public var error: PortalError
}

/// The data for SignResult.
public struct SignData: Codable {
  public var R: String
  public var S: String
}

/// The response from signing.
public struct SignResult: Codable {
  public var data: String?
  public var error: PortalError
}

public struct MpcStatus {
  public var status: MpcStatuses
  public var done: Bool
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
  case addressNotFound(message: String)
  case backupNoLongerSupported(message: String)
  case failedToEncryptClientBackupShare(message: String)
  case failedToGetBackupFromStorage
  case failedToRecoverBackup(message: String)
  case failedToStoreClientBackupShareKey(message: String)
  case generateNoLongerSupported(message: String)
  case noSigningSharePresent
  case recoverNoLongerSupported(message: String)
  case signingRecoveryError(message: String)
  case unableToAuthenticate
  case unableToDecodeShare
  case unableToRetrieveClient(String)
  case unableToWriteToKeychain
  case unexpectedErrorOnBackup(message: String)
  case unexpectedErrorOnDecrypt(message: String)
  case unexpectedErrorOnEncrypt(message: String)
  case unexpectedErrorOnGenerate(message: String)
  case unexpectedErrorOnRecoverBackup(message: String)
  case unexpectedErrorOnSign(message: String)
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

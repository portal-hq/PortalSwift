//
//  PortalKeychain.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public protocol PortalKeychainProtocol {
  var metadata: PortalKeychainMetadata? { get async throws }
  var api: PortalApiProtocol? { get set }
  var legacyAddress: String? { get set }

  func deleteShares() async throws
  func getAddress(_ forChainId: String) async throws -> String?
  func getAddresses() async throws -> [PortalNamespace: String?]
  func getMetadata() async throws -> PortalKeychainClientMetadata
  func getShare(_ forChainId: String) async throws -> String
  func getShares() async throws -> PortalKeychainClientShares
  func loadMetadata() async throws -> PortalKeychainMetadata
  func setMetadata(_: PortalKeychainClientMetadata) async throws
  func setShares(_: [String: PortalMpcGeneratedShare]) async throws
  func getAddress() throws -> String
  func getSigningShare() throws -> String
  func deleteAddress() throws
  func deleteSigningShare() throws
  func setAddress(address _: String, completion: @escaping (Result<OSStatus>) -> Void)
  func setSigningShare(signingShare _: String, completion: @escaping (Result<OSStatus>) -> Void)
}

/// The main interface for Portal to securely store the client's signing share.
public class PortalKeychain: PortalKeychainProtocol {
  private var _metadata: PortalKeychainMetadata?
  public var metadata: PortalKeychainMetadata? {
    get async throws {
      if let _metadata {
        return _metadata
      }

      _metadata = try await loadMetadata()
      return _metadata
    }
  }

  public enum KeychainError: Error, Equatable {
    case clientNotFound
    case clientIdNotSetYet
    case itemNotFound(item: String)
    case itemAlreadyExists(item: String)
    case keychainUnavailableOrNoPasscode(status: OSStatus)
    case noAddressForNamespace(_ namespace: PortalNamespace)
    case noAddressesFound
    case noWalletForNamespace(_ namespace: PortalNamespace)
    case noWalletsFound
    case shareNotFoundForCurve(_ curve: PortalCurve)
    case unableToEncodeKeychainData
    case unexpectedItemData(item: String)
    case unhandledError(status: OSStatus)
    case unsupportedNamespace(_ chainId: String)
  }

  public weak var api: PortalApiProtocol? {
    get { self._api }
    set(api) {
      self._api = api

      //  Load the metadata as soon as the api is set
      if let _ = _api {
        Task {
          do {
            try await self.loadMetadata()
          } catch {}
        }
      }
    }
  }

  public var clientId: String?
  public var legacyAddress: String?

  let baseKey = "PortalMpc"
  let deprecatedAddressKey = "PortalMpc.Address"
  let deprecatedShareKey = "PortalMpc.DkgResult"

  private weak var _api: PortalApiProtocol?
  private var client: ClientResponse? {
    get async throws {
      return try await self.api?.client
    }
  }

  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private let keychain: PortalKeychainAccessProtocol
  private let logger: PortalLoggerProtocol = PortalLogger()
  private let metadataKey = "metadata"
  private let sharesKey = "shares"

  public init(keychainAccess: PortalKeychainAccessProtocol? = nil) {
    self.keychain = keychainAccess ?? PortalKeychainAccess()
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func deleteShares() async throws {
    guard let client = try await client else {
      self.logger.error("PortalKeychain.deleteShares() - Client not found")
      throw KeychainError.clientNotFound
    }
    let clientId = client.id
    try self.keychain.deleteItem("\(clientId).\(self.sharesKey)")
  }

  public func getAddress(_ forChainId: String) async throws -> String? {
    guard let blockchain = try? PortalBlockchain(fromChainId: forChainId) else {
      self.logger.error("PortalKeychain.getAddress() - ❌ Unsupported chainId received: \(forChainId)")
      throw KeychainError.unsupportedNamespace(forChainId)
    }

    do {
      let metadata = try await getMetadata()
      guard let address = metadata.addresses?[blockchain.namespace] else {
        self.logger.error("PortalKeychain.getAddress() - No address found for namespace: \(blockchain.namespace.rawValue)")
        throw KeychainError.noAddressForNamespace(blockchain.namespace)
      }
      return address
    } catch {
      self.logger.debug("PortalKeychain.getAddress() - Attempting to read from legacy address data...")
      // Handle backward compatibility with legacy Keychain data
      guard let client = try await client else {
        self.logger.error("PortalKeychain.getAddress() - Client not found")
        throw KeychainError.clientNotFound
      }
      let clientId = client.id
      do {
        // Before multi-wallet support was added
        let address = try keychain.getItem("\(clientId).address")
        return address
      } catch KeychainError.itemNotFound(_) {
        self.logger.debug("PortalKeychain.getAddress() - Attempting to read from even older legacy address data...")
        // Handle even older legacy backward compatinility with deprecated Keychain data
        // - Before clientId was added to the Keychain key
        let address = try keychain.getItem(self.deprecatedAddressKey)
        return address
      }
    }
  }

  public func getAddresses() async throws -> [PortalNamespace: String?] {
    do {
      let metadata = try await getMetadata()
      if let addresses = metadata.addresses {
        return addresses
      } else {
        throw KeychainError.itemNotFound(item: "metadata")
      }
    } catch KeychainError.itemNotFound(_) {
      self.logger.debug("PortalKeychain.getAddresses() - Attempting to read from legacy address data...")
      // Handle backward compatibility with legacy Keychain data
      guard let client = try await client else {
        self.logger.error("PortalKeychain.getAddresses() - Client not found")
        throw KeychainError.clientNotFound
      }
      let clientId = client.id
      do {
        // Before multi-wallet support was added
        let address = try keychain.getItem("\(clientId).address")
        let addresses: [PortalNamespace: String?] = [
          .eip155: address
        ]
        return addresses
      } catch {
        self.logger.debug("PortalKeychain.getAddresses() - Attempting to read from even older legacy address data...")
        // Handle even older legacy backward compatinility with deprecated Keychain data
        // - Before clientId was added to the Keychain key
        let address = try keychain.getItem(self.deprecatedAddressKey)
        let addresses: [PortalNamespace: String?] = [
          .eip155: address
        ]
        return addresses
      }
    }
  }

  public func getMetadata() async throws -> PortalKeychainClientMetadata {
    guard let client = try await client else {
      self.logger.error("PortalKeychain.getMetadata() - Client not found")
      throw KeychainError.clientNotFound
    }

    let clientId = client.id
    let value = try getItem("\(clientId).\(metadataKey)")
    guard let data = value.data(using: .utf8) else {
      self.logger.error("PortalKeychain.getMetadata() - Unable to encode keychain data")
      throw KeychainError.unableToEncodeKeychainData
    }
    let metadata = try decoder.decode(PortalKeychainClientMetadata.self, from: data)

    return metadata
  }

  public func getShare(_ forChainId: String) async throws -> String {
    guard let blockchain = try? PortalBlockchain(fromChainId: forChainId) else {
      self.logger.error("PortalKeychain.getAddress() - ❌ Unsupported chainId received: \(forChainId)")
      throw KeychainError.unsupportedNamespace(forChainId)
    }

    do {
      let shares = try await getShares()
      guard let share = shares[blockchain.curve.rawValue] else {
        self.logger.error("PortalKeychain.getShare() - No share found for curve: \(blockchain.curve.rawValue)")
        throw KeychainError.shareNotFoundForCurve(blockchain.curve)
      }

      return share.share
    } catch {
      // We only want to do backward compatibility checks for the
      // SECP256K1 curve, since that's all that is relevant to
      // pre-multi-wallet support
      guard blockchain.curve == .SECP256K1 else {
        throw KeychainError.noWalletForNamespace(blockchain.namespace)
      }
      // Handle backward compatibility for legacy Keychain data
      guard let client = try await client else {
        self.logger.error("PortalKeychain.getShare() - Client not found")
        throw KeychainError.clientNotFound
      }
      let clientId = client.id

      do {
        // Before multi-wallet support was added
        let signingShareValue = try keychain.getItem("\(clientId).share")
        return signingShareValue
      } catch {
        // Handle even older legacy Keychain data
        // - Before clientId was added to the Keychain key
        let share = try keychain.getItem(self.deprecatedShareKey)
        return share
      }
    }
  }

  public func getShares() async throws -> PortalKeychainClientShares {
    guard let client = try await client else {
      self.logger.error("PortalKeychain.getShares() - Client not found")
      throw KeychainError.clientNotFound
    }

    let clientId = client.id

    do {
      let value = try keychain.getItem("\(clientId).\(self.sharesKey)")

      guard let data = value.data(using: .utf8) else {
        self.logger.error("PortalKeychain.getShares() - Unable to decode keychain data")
        throw KeychainError.unableToEncodeKeychainData
      }
      let shares = try decoder.decode(PortalKeychainClientShares.self, from: data)

      return shares
    } catch {
      self.logger.debug("PortalKeychain.getShares() - Attempting to read from legacy share data...")
      // Handle backward compatibility with legacy Keychain data
      do {
        // Before multi-wallet support was added
        let signingShareValue = try keychain.getItem("\(clientId).share")

        guard let data = signingShareValue.data(using: .utf8) else {
          self.logger.error("PortalKeychain.getShares() - Unable to decode legacy keychain data")
          throw KeychainError.unableToEncodeKeychainData
        }
        let share = try decoder.decode(MpcShare.self, from: data)
        let generateResponse: PortalMpcGenerateResponse = [
          "SECP256K1": PortalMpcGeneratedShare(
            id: share.signingSharePairId ?? "",
            share: signingShareValue
          )
        ]
        return generateResponse
      } catch {
        self.logger.debug("PortalKeychain.getShares() - Attempting to read from even older legacy share data...")
        // Handle even older legacy Keychain data
        // - Before clientId was added to the Keychain key
        let share = try keychain.getItem(self.deprecatedShareKey)
        let generateResponse: PortalMpcGenerateResponse = [
          "SECP256K1": PortalMpcGeneratedShare(
            id: "",
            share: share
          )
        ]
        return generateResponse
      }
    }
  }

  @discardableResult
  public func loadMetadata() async throws -> PortalKeychainMetadata {
    self.logger.debug("PortalKeychain.loadMetadata() - Loading metadata...")
    guard let client = try await self.client else {
      throw KeychainError.clientNotFound
    }
    // Load the curve map into memory
    var metadata = PortalKeychainMetadata(
      namespaces: [:]
    )
    if let eip155Curve = client.metadata.namespaces.eip155?.curve {
      metadata.namespaces[.eip155] = eip155Curve
    }
    if let solanaCurve = client.metadata.namespaces.solana?.curve {
      metadata.namespaces[.solana] = solanaCurve
    }

    self._metadata = metadata

    // Build the client's wallet metadata
    var wallets: [PortalCurve: PortalKeychainClientMetadataWallet] = [:]
    for wallet in client.wallets {
      wallets[wallet.curve] = PortalKeychainClientMetadataWallet(
        id: wallet.id,
        curve: wallet.curve,
        publicKey: wallet.publicKey,
        backupShares: wallet.backupSharePairs.map { share in
          PortalKeychainClientMetadataWalletBackupShare(
            backupMethod: share.backupMethod,
            createdAt: share.createdAt,
            id: share.id,
            status: share.status
          )
        },
        signingShares: wallet.signingSharePairs.map { share in
          PortalKeychainClientMetadataWalletShare(
            createdAt: share.createdAt,
            id: share.id,
            status: share.status
          )
        }
      )
    }

    // Build the client's metadata
    let clientMetadata = PortalKeychainClientMetadata(
      id: client.id,
      addresses: [
        .eip155: client.metadata.namespaces.eip155?.address,
        .solana: client.metadata.namespaces.solana?.address
      ],
      custodian: client.custodian,
      wallets: wallets
    )

    // TODO: Remove this when we go fully async and chain agnostic
    self.legacyAddress = client.metadata.namespaces.eip155?.address
    self.clientId = client.id

    // Write the metadata to the keychain
    try await self.setMetadata(clientMetadata)
    return metadata
  }

  public func setMetadata(_ withData: PortalKeychainClientMetadata) async throws {
    guard let client = try await client else {
      self.logger.error("PortalKeychain.setMetadata() - Client not found")
      throw KeychainError.clientNotFound
    }
    let clientId = client.id
    let data = try encoder.encode(withData)
    guard let value = String(data: data, encoding: .utf8) else {
      self.logger.error("PortalKeychain.setMetadata() - Unable to encode keychain data")
      throw KeychainError.unableToEncodeKeychainData
    }

    try self.keychain.updateItem("\(clientId).\(self.metadataKey)", value: value)
  }

  public func setShares(_ withData: [String: PortalMpcGeneratedShare]) async throws {
    guard let client = try await client else {
      self.logger.error("PortalKeychain.setShares() - Client not found")
      throw KeychainError.clientNotFound
    }
    let clientId = client.id
    let data = try encoder.encode(withData)
    guard let value = String(data: data, encoding: .utf8) else {
      self.logger.error("PortalKeychain.setShares() - Unable to encode keychain data.")
      throw KeychainError.unableToEncodeKeychainData
    }

    try self.keychain.updateItem("\(clientId).\(self.sharesKey)", value: value)
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func deleteItem(_ key: String) throws {
    try self.keychain.deleteItem(key)
  }

  private func getItem(_ key: String) throws -> String {
    return try self.keychain.getItem(key)
  }

  private func setItem(_ key: String, withValue: String) throws {
    try self.keychain.addItem(key, value: withValue)
  }

  private func updateItem(_ key: String, withValue: String) throws {
    try self.keychain.updateItem(key, value: withValue)
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Retrieve the address stored in the client's keychain.
  /// - Returns: The client's address.
  @available(*, deprecated, renamed: "getAddress", message: "Please use the async, chainId-specific implementation of getAddress().")
  public func getAddress() throws -> String {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"
    var address: String

    do {
      address = try self.getItem(addressKey)
    } catch {
      do {
        // Fallback to deprecated key.
        address = try self.getItem(self.deprecatedAddressKey)
      } catch {
        do {
          // Fallback to metadata key.
          let value = try getItem("\(clientId).\(metadataKey)")
          guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToEncodeKeychainData
          }
          let metadata = try decoder.decode(PortalKeychainClientMetadata.self, from: data)
          guard let address = metadata.addresses?[.eip155] else {
            throw KeychainError.itemNotFound(item: "\(clientId).\(self.metadataKey)")
          }
          guard let address = address else {
            throw KeychainError.itemNotFound(item: "\(clientId).\(self.metadataKey)")
          }
          return address
        } catch {
          throw KeychainError.itemNotFound(item: "\(clientId).\(self.metadataKey)")
        }
      }
    }

    return address
  }

  /// Retrieve the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  @available(*, deprecated, renamed: "getShares", message: "Please use the async implementation of getShares() or getShare(forChainId).")
  public func getSigningShare() throws -> String {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"
    var share: String

    do {
      share = try self.getItem(shareKey)
    } catch KeychainError.itemNotFound(item: shareKey) {
      do {
        // Fallback to deprecated key.
        share = try self.getItem(self.deprecatedShareKey)
      } catch KeychainError.itemNotFound(item: self.deprecatedShareKey) {
        // Throw original item not found error.
        throw KeychainError.itemNotFound(item: shareKey)
      }
    }

    return share
  }

  /// Sets the address in the client's keychain.
  /// - Parameter address: The public address of the client's wallet.
  @available(*, deprecated, renamed: "updateMetadata", message: "Please use the async implementation of updateMetadata().")
  public func setAddress(
    address: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    var clientId: String
    do {
      clientId = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }
    let addressKey = "\(clientId).address"

    self.setItem(key: addressKey, value: address) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      return completion(Result(data: result.data!))
    }
  }

  /// Sets the signing share in the client's keychain.
  /// - Parameter signingShare: A dkg object.
  @available(*, deprecated, renamed: "updateShares", message: "Please use the async implementation of updateShares().")
  public func setSigningShare(
    signingShare: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    var clientId: String
    do {
      clientId = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }
    let shareKey = "\(clientId).share"

    self.setItem(key: shareKey, value: signingShare) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      return completion(Result(data: result.data!))
    }
  }

  /// Deletes the address stored in the client's keychain.
  @available(*, deprecated, renamed: "deleteMetadata", message: "Please use the async implementation of deleteMetadata().")
  public func deleteAddress() throws {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"

    try deleteItem(addressKey)
    try deleteItem(deprecatedAddressKey)
  }

  /// Deletes the signing share stored in the client's keychain.
  @available(*, deprecated, renamed: "deleteShares", message: "Please use the async implementation of deleteShares().")
  public func deleteSigningShare() throws {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"

    try deleteItem(shareKey)
    try deleteItem(deprecatedShareKey)
  }

  /// Tests `setItem` in the client's keychain.
  @available(*, deprecated, renamed: "validateOperations", message: "Please use the async implementation of validateOperations().")
  func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    do {
      _ = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }

    let testKey = "portal_test"
    let testValue = "test_value"

    self.setItem(key: testKey, value: testValue) { result in
      // Handle errors.
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      do {
        // Delete the key that was created.
        try self.deleteItem(testKey)
        return completion(Result(data: result.data!))
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "setItem", message: "Please use the async implementation of setItem().")
  private func setItem(
    key: String,
    value: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    do {
      // Construct the query to set the keychain item.
      let query: [String: AnyObject] = [
        kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
      ]

      // Try to set the keychain item that matches the query.
      let status = SecItemAdd(query as CFDictionary, nil)

      // Throw if the status is not successful.
      if status == errSecDuplicateItem {
        try self.updateItem(key, withValue: value)
        return completion(Result(data: status))
      }
      guard status != errSecNotAvailable else {
        return completion(Result(error: KeychainError.keychainUnavailableOrNoPasscode(status: status)))
      }
      guard status == errSecSuccess else {
        return completion(Result(error: KeychainError.unhandledError(status: status)))
      }
      return completion(Result(data: status))
    } catch {
      return completion(Result(error: error))
    }
  }

  @available(*, deprecated, renamed: "client.id", message: "Please use the async `client` getter to access clientId.")
  private func getClientId() throws -> String {
    if self.clientId == nil {
      throw KeychainError.clientIdNotSetYet
    }

    return self.clientId!
  }
}

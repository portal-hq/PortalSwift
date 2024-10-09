//
//  PortalKeychainSpy.swift
//
//
//  Created by Ahmed Ragab on 07/09/2024.
//

import Foundation
@testable import PortalSwift

class PortalKeychainSpy: PortalKeychainProtocol {
    var metadata: PortalSwift.PortalKeychainMetadata?
    var api: PortalApiProtocol?
    var legacyAddress: String?

    // MARK: - deleteShares
    private(set) var deleteSharesCallCount = 0
    
    func deleteShares() async throws {
        deleteSharesCallCount += 1
    }

    // MARK: - getAddress(forChainId:)
    private(set) var getAddressForChainIdCallCount = 0
    private(set) var getAddressForChainIdParams: [String] = []

    func getAddress(_ forChainId: String) async throws -> String? {
        getAddressForChainIdCallCount += 1
        getAddressForChainIdParams.append(forChainId)
        return nil
    }

    // MARK: - getAddresses
    private(set) var getAddressesCallCount = 0
    var getAddressesReturnValue: [PortalNamespace: String?] = [:]

    func getAddresses() async throws -> [PortalNamespace: String?] {
        getAddressesCallCount += 1
        return getAddressesReturnValue
    }

    // MARK: - getMetadata
    private(set) var getMetadataCallCount = 0

    func getMetadata() async throws -> PortalKeychainClientMetadata {
        getMetadataCallCount += 1
        // Provide a mock or stub value if needed
        return PortalKeychainClientMetadata.stub()
    }

    // MARK: - getShare(forChainId:)
    private(set) var getShareForChainIdCallCount = 0
    private(set) var getShareForChainIdParams: [String] = []

    func getShare(_ forChainId: String) async throws -> String {
        getShareForChainIdCallCount += 1
        getShareForChainIdParams.append(forChainId)
        return ""
    }

    // MARK: - getShares
    private(set) var getSharesCallCount = 0

    func getShares() async throws -> PortalKeychainClientShares {
        getSharesCallCount += 1
        // Provide a mock or stub value if needed
        return PortalKeychainClientShares()
    }

    // MARK: - loadMetadata
    private(set) var loadMetadataCallCount = 0

    func loadMetadata() async throws -> PortalSwift.PortalKeychainMetadata {
        loadMetadataCallCount += 1
        return PortalKeychainMetadata(namespaces: [:])
    }

    // MARK: - setMetadata
    private(set) var setMetadataCallCount = 0
    private(set) var setMetadataParams: [PortalKeychainClientMetadata] = []

    func setMetadata(_ metadata: PortalKeychainClientMetadata) async throws {
        setMetadataCallCount += 1
        setMetadataParams.append(metadata)
    }

    // MARK: - setShares
    private(set) var setSharesCallCount = 0
    private(set) var setSharesParams: [[String: PortalMpcGeneratedShare]] = []

    func setShares(_ shares: [String: PortalMpcGeneratedShare]) async throws {
        setSharesCallCount += 1
        setSharesParams.append(shares)
    }

    // MARK: - getAddress
    private(set) var getAddressCallCount = 0

    func getAddress() throws -> String {
        getAddressCallCount += 1
        return ""
    }

    // MARK: - getSigningShare
    private(set) var getSigningShareCallCount = 0

    func getSigningShare() throws -> String {
        getSigningShareCallCount += 1
        return ""
    }

    // MARK: - deleteAddress
    private(set) var deleteAddressCallCount = 0

    func deleteAddress() throws {
        deleteAddressCallCount += 1
    }

    // MARK: - deleteSigningShare
    private(set) var deleteSigningShareCallCount = 0

    func deleteSigningShare() throws {
        deleteSigningShareCallCount += 1
    }

    // MARK: - setAddress
    private(set) var setAddressCallCount = 0
    private(set) var setAddressParams: [String] = []

    func setAddress(address: String, completion: @escaping (Result<OSStatus>) -> Void) {
        setAddressCallCount += 1
        setAddressParams.append(address)
        // Call completion with a mock result
        completion(Result(error: NSError()))
    }

    // MARK: - setSigningShare
    private(set) var setSigningShareCallCount = 0
    private(set) var setSigningShareParams: [String] = []

    func setSigningShare(signingShare: String, completion: @escaping (Result<OSStatus>) -> Void) {
        setSigningShareCallCount += 1
        setSigningShareParams.append(signingShare)
        // Call completion with a mock result
        completion(Result(error: NSError()))
    }
}

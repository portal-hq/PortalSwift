//
//  PortalStorageMock.swift
//
//
//  Created by Ahmed Ragab on 08/09/2024.
//

import Foundation
@testable import PortalSwift

class PortalStorageMock: PortalStorage {
    var api: PortalApiProtocol?
    var encryption: PortalEncryptionProtocol

    // Initialize with default or injected encryption
    init(encryption: PortalEncryptionProtocol = PortalEncryption()) {
        self.encryption = encryption
    }

    // Mock properties to store return values
    var decryptReturnValue: String?
    var decryptError: Error?
    func decrypt(_ value: String, withKey: String) async throws -> String {
        if let error = decryptError {
            throw error
        }
        return decryptReturnValue ?? ""
    }

    var deleteReturnValue: Bool?
    var deleteError: Error?
    func delete() async throws -> Bool {
        if let error = deleteError {
            throw error
        }
        return deleteReturnValue ?? false
    }

    var encryptReturnValue: EncryptData?
    var encryptError: Error?
    func encrypt(_ value: String) async throws -> EncryptData {
        if let error = encryptError {
            throw error
        }
        return encryptReturnValue ?? EncryptData(key: "", cipherText: "")
    }

    var readReturnValue: String?
    var readError: Error?
    func read() async throws -> String {
        if let error = readError {
            throw error
        }
        return readReturnValue ?? ""
    }

    var validateOperationsReturnValue: Bool?
    var validateOperationsError: Error?
    func validateOperations() async throws -> Bool {
        if let error = validateOperationsError {
            throw error
        }
        return validateOperationsReturnValue ?? false
    }

    var writeReturnValue: Bool?
    var writeError: Error?
    func write(_ value: String) async throws -> Bool {
        if let error = writeError {
            throw error
        }
        return writeReturnValue ?? false
    }
}

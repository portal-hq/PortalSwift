//
//  PortalRequestsMock.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

import Foundation
@testable import PortalSwift

final class PortalRequestsMock: PortalRequestsProtocol {

    private let encoder = JSONEncoder()

    var returnValueData: Data?
    var returnValueString: String?

    func delete(_ from: URL, withBearerToken: String?) async throws -> Data {
        return try getReturnValue()
    }

    func get(_ from: URL, withBearerToken: String?) async throws -> Data {
        return try getReturnValue()
    }

    func patch(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
        return try getReturnValue()
    }

    func post(_ from: URL, withBearerToken: String?, andPayload: (any Codable)?) async throws -> Data {
        return try getReturnValue()
    }

    func postMultiPartData(_ from: URL, withBearerToken: String, andPayload: String, usingBoundary: String) async throws -> Data {
        return try getReturnValue()
    }
}

extension PortalRequestsMock {
    private func getReturnValue() throws -> Data {
        if let returnValueData {
            return returnValueData
        } else if let returnValueString {
            return try encoder.encode(returnValueString)
        } else {
            return Data()
        }
    }
}

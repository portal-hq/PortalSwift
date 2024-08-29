//
//  PortalRequestsFailMock.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

import Foundation
@testable import PortalSwift

final class PortalRequestsFailMock: PortalRequestsProtocol {

    var errorToThrow: URLError = URLError(.badURL)

    func delete(_ from: URL, withBearerToken: String?) async throws -> Data {
        throw errorToThrow
    }

    func get(_ from: URL, withBearerToken: String?) async throws -> Data {
        throw errorToThrow
    }

    func patch(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
        throw errorToThrow
    }

    func post(_ from: URL, withBearerToken: String?, andPayload: (any Codable)?) async throws -> Data {
        throw errorToThrow
    }

    func postMultiPartData(_ from: URL, withBearerToken: String, andPayload: String, usingBoundary: String) async throws -> Data {
        throw errorToThrow
    }
}

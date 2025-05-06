//
//  PortalRequestsFailMock.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

import Foundation
@testable import PortalSwift

final class PortalRequestsFailMock: PortalRequestsProtocol {
  var errorToThrow: URLError = .init(.badURL)

  func delete(_: URL, withBearerToken _: String?) async throws -> Data {
    throw errorToThrow
  }

  func get(_: URL, withBearerToken _: String?) async throws -> Data {
    throw errorToThrow
  }

  func patch(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    throw errorToThrow
  }

  func put(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    throw errorToThrow
  }

  func post(_: URL, withBearerToken _: String?, andPayload _: (any Codable)?) async throws -> Data {
    throw errorToThrow
  }

  func postMultiPartData(_: URL, withBearerToken _: String, andPayload _: String, usingBoundary _: String) async throws -> Data {
    throw errorToThrow
  }
}

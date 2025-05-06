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

  func delete(_: URL, withBearerToken _: String?) async throws -> Data {
    return try getReturnValue()
  }

  func get(_: URL, withBearerToken _: String?) async throws -> Data {
    return try getReturnValue()
  }

  func patch(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    return try getReturnValue()
  }

  func put(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    return try getReturnValue()
  }

  func post(_: URL, withBearerToken _: String?, andPayload _: (any Codable)?) async throws -> Data {
    return try getReturnValue()
  }

  func postMultiPartData(_: URL, withBearerToken _: String, andPayload _: String, usingBoundary _: String) async throws -> Data {
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

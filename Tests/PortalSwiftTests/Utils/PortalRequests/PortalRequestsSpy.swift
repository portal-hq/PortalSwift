//
//  PortalRequestsSpy.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

@testable import PortalSwift
import XCTest

final class PortalRequestsSpy: PortalRequestsProtocol {
  var returnData = Data()

  // Tracking variables for `delete` function
  private(set) var deleteCallsCount = 0
  private(set) var deleteFromParam: URL?
  private(set) var deleteWithBearerTokenParam: String?

  func delete(_ from: URL, withBearerToken: String?) async throws -> Data {
    deleteCallsCount += 1
    deleteFromParam = from
    deleteWithBearerTokenParam = withBearerToken
    return returnData
  }

  // Tracking variables for `get` function
  private(set) var getCallsCount = 0
  private(set) var getFromParam: URL?
  private(set) var getWithBearerTokenParam: String?

  func get(_ from: URL, withBearerToken: String?) async throws -> Data {
    getCallsCount += 1
    getFromParam = from
    getWithBearerTokenParam = withBearerToken
    return returnData
  }

  // Tracking variables for `patch` function
  private(set) var patchCallsCount = 0
  private(set) var patchFromParam: URL?
  private(set) var patchWithBearerTokenParam: String?
  private(set) var patchAndPayloadParam: Codable?

  func patch(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
    patchCallsCount += 1
    patchFromParam = from
    patchWithBearerTokenParam = withBearerToken
    patchAndPayloadParam = andPayload
    return returnData
  }

  // Tracking variables for `post` function
  var postCallsCount = 0
  private(set) var postFromParam: URL?
  private(set) var postWithBearerTokenParam: String?
  private(set) var postAndPayloadParam: Codable?

  func post(_ from: URL, withBearerToken: String?, andPayload: (any Codable)?) async throws -> Data {
    postCallsCount += 1
    postFromParam = from
    postWithBearerTokenParam = withBearerToken
    postAndPayloadParam = andPayload
    return returnData
  }

  // Tracking variables for `postMultiPartData` function
  private(set) var postMultiPartDataCallsCount = 0
  private(set) var postMultiPartDataFromParam: URL?
  private(set) var postMultiPartDataWithBearerTokenParam: String?
  private(set) var postMultiPartDataAndPayloadParam: String?
  private(set) var postMultiPartDataUsingBoundaryParam: String?

  func postMultiPartData(_ from: URL, withBearerToken: String, andPayload: String, usingBoundary: String) async throws -> Data {
    postMultiPartDataCallsCount += 1
    postMultiPartDataFromParam = from
    postMultiPartDataWithBearerTokenParam = withBearerToken
    postMultiPartDataAndPayloadParam = andPayload
    postMultiPartDataUsingBoundaryParam = usingBoundary
    return returnData
  }

  // Tracking variables for `execute` function
  private(set) var executeCallsCount = 0
  private(set) var executeRequestParam: PortalBaseRequestProtocol?

  func execute<ResponseType>(request: any PortalSwift.PortalBaseRequestProtocol, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    executeCallsCount += 1
    executeRequestParam = request

    if ResponseType.self == Data.self {
      return returnData as! ResponseType
    }

    return try JSONDecoder().decode(ResponseType.self, from: returnData)
  }

  // Tracking variables for `put` function
  private(set) var putCallsCount = 0
  private(set) var putFromParam: URL?
  private(set) var putWithBearerTokenParam: String?
  private(set) var putAndPayloadParam: Codable?

  func put(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
    putCallsCount += 1
    putFromParam = from
    putWithBearerTokenParam = withBearerToken
    putAndPayloadParam = andPayload
    return returnData
  }
}

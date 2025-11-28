//
//  PortalRequestsSpy.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

import Foundation
@testable import PortalSwift
import XCTest

final class PortalRequestsSpy: PortalRequestsProtocol {
  var returnData = Data()

  // Thread-safe serial queue for synchronizing access to counters and parameters
  private let queue = DispatchQueue(label: "com.portal.PortalRequestsSpy.queue")

  // Tracking variables for `delete` function
  private var _deleteCallsCount = 0
  private var _deleteFromParam: URL?
  private var _deleteWithBearerTokenParam: String?

  var deleteCallsCount: Int {
    queue.sync { _deleteCallsCount }
  }

  var deleteFromParam: URL? {
    queue.sync { _deleteFromParam }
  }

  var deleteWithBearerTokenParam: String? {
    queue.sync { _deleteWithBearerTokenParam }
  }

  func delete(_ from: URL, withBearerToken: String?) async throws -> Data {
    queue.sync {
      _deleteCallsCount += 1
      _deleteFromParam = from
      _deleteWithBearerTokenParam = withBearerToken
    }
    return returnData
  }

  // Tracking variables for `get` function
  private var _getCallsCount = 0
  private var _getFromParam: URL?
  private var _getWithBearerTokenParam: String?

  var getCallsCount: Int {
    queue.sync { _getCallsCount }
  }

  var getFromParam: URL? {
    queue.sync { _getFromParam }
  }

  var getWithBearerTokenParam: String? {
    queue.sync { _getWithBearerTokenParam }
  }

  func get(_ from: URL, withBearerToken: String?) async throws -> Data {
    queue.sync {
      _getCallsCount += 1
      _getFromParam = from
      _getWithBearerTokenParam = withBearerToken
    }
    return returnData
  }

  // Tracking variables for `patch` function
  private var _patchCallsCount = 0
  private var _patchFromParam: URL?
  private var _patchWithBearerTokenParam: String?
  private var _patchAndPayloadParam: Codable?

  var patchCallsCount: Int {
    queue.sync { _patchCallsCount }
  }

  var patchFromParam: URL? {
    queue.sync { _patchFromParam }
  }

  var patchWithBearerTokenParam: String? {
    queue.sync { _patchWithBearerTokenParam }
  }

  var patchAndPayloadParam: Codable? {
    queue.sync { _patchAndPayloadParam }
  }

  func patch(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
    queue.sync {
      _patchCallsCount += 1
      _patchFromParam = from
      _patchWithBearerTokenParam = withBearerToken
      _patchAndPayloadParam = andPayload
    }
    return returnData
  }

  // Tracking variables for `put` function
  private var _putCallsCount = 0
  private var _putFromParam: URL?
  private var _putWithBearerTokenParam: String?
  private var _putAndPayloadParam: Codable?

  var putCallsCount: Int {
    queue.sync { _putCallsCount }
  }

  var putFromParam: URL? {
    queue.sync { _putFromParam }
  }

  var putWithBearerTokenParam: String? {
    queue.sync { _putWithBearerTokenParam }
  }

  var putAndPayloadParam: Codable? {
    queue.sync { _putAndPayloadParam }
  }

  func put(_ from: URL, withBearerToken: String?, andPayload: any Codable) async throws -> Data {
    queue.sync {
      _putCallsCount += 1
      _putFromParam = from
      _putWithBearerTokenParam = withBearerToken
      _putAndPayloadParam = andPayload
    }
    return returnData
  }

  // Tracking variables for `post` function
  private var _postCallsCount = 0
  private var _postFromParam: URL?
  private var _postWithBearerTokenParam: String?
  private var _postAndPayloadParam: Codable?

  var postCallsCount: Int {
    queue.sync { _postCallsCount }
  }

  var postFromParam: URL? {
    queue.sync { _postFromParam }
  }

  var postWithBearerTokenParam: String? {
    queue.sync { _postWithBearerTokenParam }
  }

  var postAndPayloadParam: Codable? {
    queue.sync { _postAndPayloadParam }
  }

  func post(_ from: URL, withBearerToken: String?, andPayload: (any Codable)?) async throws -> Data {
    queue.sync {
      _postCallsCount += 1
      _postFromParam = from
      _postWithBearerTokenParam = withBearerToken
      _postAndPayloadParam = andPayload
    }
    return returnData
  }

  // Tracking variables for `postMultiPartData` function
  private var _postMultiPartDataCallsCount = 0
  private var _postMultiPartDataFromParam: URL?
  private var _postMultiPartDataWithBearerTokenParam: String?
  private var _postMultiPartDataAndPayloadParam: String?
  private var _postMultiPartDataUsingBoundaryParam: String?

  var postMultiPartDataCallsCount: Int {
    queue.sync { _postMultiPartDataCallsCount }
  }

  var postMultiPartDataFromParam: URL? {
    queue.sync { _postMultiPartDataFromParam }
  }

  var postMultiPartDataWithBearerTokenParam: String? {
    queue.sync { _postMultiPartDataWithBearerTokenParam }
  }

  var postMultiPartDataAndPayloadParam: String? {
    queue.sync { _postMultiPartDataAndPayloadParam }
  }

  var postMultiPartDataUsingBoundaryParam: String? {
    queue.sync { _postMultiPartDataUsingBoundaryParam }
  }

  func postMultiPartData(_ from: URL, withBearerToken: String, andPayload: String, usingBoundary: String) async throws -> Data {
    queue.sync {
      _postMultiPartDataCallsCount += 1
      _postMultiPartDataFromParam = from
      _postMultiPartDataWithBearerTokenParam = withBearerToken
      _postMultiPartDataAndPayloadParam = andPayload
      _postMultiPartDataUsingBoundaryParam = usingBoundary
    }
    return returnData
  }

  // Tracking variables for `execute` function
  private var _executeCallsCount = 0
  private var _executeRequestParam: PortalBaseRequestProtocol?

  var executeCallsCount: Int {
    queue.sync { _executeCallsCount }
  }

  var executeRequestParam: PortalBaseRequestProtocol? {
    queue.sync { _executeRequestParam }
  }

  func execute<ResponseType>(request: any PortalSwift.PortalBaseRequestProtocol, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    queue.sync {
      _executeCallsCount += 1
      _executeRequestParam = request
    }

    if ResponseType.self == Data.self {
      return returnData as! ResponseType
    }

    return try JSONDecoder().decode(ResponseType.self, from: returnData)
  }

  // Tracking variables for `execute` function
  private var _executeReturningDataCallsCount = 0
  private var _executeReturningDataRequestParam: PortalBaseRequestProtocol?

  var executeReturningDataCallsCount: Int {
    queue.sync { _executeReturningDataCallsCount }
  }

  var executeReturningDataRequestParam: PortalBaseRequestProtocol? {
    queue.sync { _executeReturningDataRequestParam }
  }

  func execute(request: any PortalSwift.PortalBaseRequestProtocol) async throws -> Data {
    queue.sync {
      _executeReturningDataCallsCount += 1
      _executeReturningDataRequestParam = request
    }
    return returnData
  }
}

//
//  NonReportingPortalRequestsSpy.swift
//  PortalSwiftTests
//
//  A transport double that deliberately does NOT conform to `PortalUnauthorizedReporting`.
//

import Foundation
@testable import PortalSwift

/// A recording `PortalRequestsProtocol` double that intentionally does not adopt
/// `PortalUnauthorizedReporting`.
///
/// The credentials layer installs its 401 hook only when
/// `requests as? PortalUnauthorizedReporting` succeeds; hosts may hand the SDK any conforming
/// transport, so installation must be a silent no-op for one that cannot report. This double
/// exists to prove that: constructing `Portal`, `PortalApi`, `PortalProvider`, the storages and
/// the auth module with it must succeed and every request must still flow. Do not add the
/// conformance here; use `PortalRequestsSpy` for the reporting case.
final class NonReportingPortalRequestsSpy: PortalRequestsProtocol {
  var returnData = Data()

  /// When set, every call throws this error instead of returning `returnData`.
  var errorToThrow: Error?

  private let queue = DispatchQueue(label: "com.portal.NonReportingPortalRequestsSpy.queue")

  private var _executeCallsCount = 0
  private var _executeReturningDataCallsCount = 0
  private var _postMultiPartDataCallsCount = 0
  private var _deleteCallsCount = 0
  private var _getCallsCount = 0
  private var _patchCallsCount = 0
  private var _putCallsCount = 0
  private var _postCallsCount = 0
  private var _executeRequestHistory: [PortalBaseRequestProtocol] = []
  private var _bearerTokensSent: [String?] = []

  /// Calls to `execute(request:mappingInResponse:)`.
  var executeCallsCount: Int {
    queue.sync { _executeCallsCount }
  }

  /// Calls to `execute(request:)`.
  var executeReturningDataCallsCount: Int {
    queue.sync { _executeReturningDataCallsCount }
  }

  var postMultiPartDataCallsCount: Int {
    queue.sync { _postMultiPartDataCallsCount }
  }

  var deleteCallsCount: Int {
    queue.sync { _deleteCallsCount }
  }

  var getCallsCount: Int {
    queue.sync { _getCallsCount }
  }

  var patchCallsCount: Int {
    queue.sync { _patchCallsCount }
  }

  var putCallsCount: Int {
    queue.sync { _putCallsCount }
  }

  var postCallsCount: Int {
    queue.sync { _postCallsCount }
  }

  /// Every call across every verb.
  var totalCallsCount: Int {
    queue.sync {
      _executeCallsCount + _executeReturningDataCallsCount + _postMultiPartDataCallsCount
        + _deleteCallsCount + _getCallsCount + _patchCallsCount + _putCallsCount + _postCallsCount
    }
  }

  /// Every request passed to either `execute` overload, in call order.
  var executeRequestHistory: [PortalBaseRequestProtocol] {
    queue.sync { _executeRequestHistory }
  }

  /// The bearer token carried by each call, in call order, across every verb (`nil` when
  /// none was supplied). The `Bearer ` prefix is stripped.
  var bearerTokensSent: [String?] {
    queue.sync { _bearerTokensSent }
  }

  var executeRequestParam: PortalBaseRequestProtocol? {
    queue.sync { _executeRequestHistory.last }
  }

  private func finish() throws -> Data {
    if let error = errorToThrow {
      throw error
    }
    return returnData
  }

  private func recordBearer(_ token: String?) {
    queue.sync { _bearerTokensSent.append(token) }
  }

  private func recordExecute(_ request: PortalBaseRequestProtocol) {
    queue.sync {
      _executeRequestHistory.append(request)
      _bearerTokensSent.append(Self.bearerToken(in: request.headers))
    }
  }

  private static func bearerToken(in headers: [String: String]) -> String? {
    guard let authorization = headers.first(where: { $0.key.caseInsensitiveCompare("Authorization") == .orderedSame })?.value else {
      return nil
    }
    let prefix = "Bearer "
    if authorization.hasPrefix(prefix) {
      return String(authorization.dropFirst(prefix.count))
    }
    return authorization
  }

  // MARK: - PortalRequestsProtocol

  func execute<ResponseType>(request: any PortalBaseRequestProtocol, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    queue.sync { _executeCallsCount += 1 }
    recordExecute(request)
    let data = try finish()

    if ResponseType.self == Data.self, let typed = data as? ResponseType {
      return typed
    }
    if ResponseType.self == String.self, let typed = (String(data: data, encoding: .utf8) ?? "") as? ResponseType {
      return typed
    }
    return try JSONDecoder().decode(ResponseType.self, from: data)
  }

  func execute(request: any PortalBaseRequestProtocol) async throws -> Data {
    queue.sync { _executeReturningDataCallsCount += 1 }
    recordExecute(request)
    return try finish()
  }

  func postMultiPartData(_: URL, withBearerToken: String, andPayload _: String, usingBoundary _: String) async throws -> Data {
    queue.sync { _postMultiPartDataCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }

  func delete(_: URL, withBearerToken: String?) async throws -> Data {
    queue.sync { _deleteCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }

  func get(_: URL, withBearerToken: String?) async throws -> Data {
    queue.sync { _getCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }

  func patch(_: URL, withBearerToken: String?, andPayload _: any Codable) async throws -> Data {
    queue.sync { _patchCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }

  func put(_: URL, withBearerToken: String?, andPayload _: any Codable) async throws -> Data {
    queue.sync { _putCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }

  func post(_: URL, withBearerToken: String?, andPayload _: (any Codable)?) async throws -> Data {
    queue.sync { _postCallsCount += 1 }
    recordBearer(withBearerToken)
    return try finish()
  }
}

//
//  PortalRequestsSpy.swift
//
//
//  Created by Ahmed Ragab on 29/08/2024.
//

import Foundation
@testable import PortalSwift
import XCTest

/// A recording `PortalRequestsProtocol` double that also conforms to
/// `PortalUnauthorizedReporting`, so the credentials layer treats it like the real transport
/// and installs its 401 hook on it. Tests observe the installation through
/// `onUnauthorizedSetCount`, replay a Portal 401 through `simulatePortalUnauthorizedOnce`, and
/// read the exact bearer sent per call from `bearerTokensSent`.
final class PortalRequestsSpy: PortalRequestsProtocol, PortalUnauthorizedReporting {
  var returnData = Data()

  // Thread-safe serial queue for synchronizing access to counters and parameters
  private let queue = DispatchQueue(label: "com.portal.PortalRequestsSpy.queue")

  // MARK: - PortalUnauthorizedReporting

  private var _onUnauthorized: (() -> Void)?
  private var _onUnauthorizedSetCount = 0

  /// The hook the credentials layer installs. Assigning a non-nil closure counts as an
  /// install (see `onUnauthorizedSetCount`); assigning `nil` clears it without counting so a
  /// test can reset between phases.
  var onUnauthorized: (() -> Void)? {
    get {
      queue.sync { _onUnauthorized }
    }
    set {
      queue.sync {
        _onUnauthorized = newValue
        if newValue != nil {
          _onUnauthorizedSetCount += 1
        }
      }
    }
  }

  /// Number of times a non-nil `onUnauthorized` closure was installed. Lets tests prove the
  /// "install only when the transport has no hook yet" rule (a preset hook must leave this at 1).
  var onUnauthorizedSetCount: Int {
    queue.sync { _onUnauthorizedSetCount }
  }

  /// When `true`, the next call (any verb) behaves like the real transport receiving a `401`
  /// from a Portal host: it invokes `onUnauthorized`, clears the flag, and throws
  /// `PortalRequestsError.unauthorized`. Subsequent calls proceed normally.
  var simulatePortalUnauthorizedOnce = false

  // MARK: - Cross-verb recording

  private var _executeRequestHistory: [PortalBaseRequestProtocol] = []
  private var _bearerTokensSent: [String?] = []

  /// Every request passed to either `execute` overload, in call order.
  var executeRequestHistory: [PortalBaseRequestProtocol] {
    queue.sync { _executeRequestHistory }
  }

  /// The bearer token carried by each call, in call order, across every verb: `nil` when no
  /// `Authorization` header (or bearer parameter) was supplied. The `Bearer ` prefix is
  /// stripped so tests compare against the raw credential value.
  var bearerTokensSent: [String?] {
    queue.sync { _bearerTokensSent }
  }

  /// Bodies returned by successive `execute` calls (both overloads), consumed in order before
  /// falling back to `returnData`. A call that throws (via `simulatePortalUnauthorizedOnce` or
  /// `executeThrowableErrorSequence`) does not consume an entry.
  var executeReturnDataSequence: [Data] = []

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

  private func simulateUnauthorizedIfRequested() throws {
    guard simulatePortalUnauthorizedOnce else {
      return
    }
    simulatePortalUnauthorizedOnce = false
    onUnauthorized?()
    throw PortalRequestsError.unauthorized
  }

  private func nextExecuteReturnData() -> Data {
    if !executeReturnDataSequence.isEmpty {
      return executeReturnDataSequence.removeFirst()
    }
    return returnData
  }

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
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
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
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
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
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
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
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
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
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
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

  /// Errors to throw from successive `postMultiPartData` calls (nil = succeed);
  /// once exhausted, calls succeed with `returnData`.
  var postMultiPartDataThrowableErrorSequence: [Error?] = []

  func postMultiPartData(_ from: URL, withBearerToken: String, andPayload: String, usingBoundary: String) async throws -> Data {
    queue.sync {
      _postMultiPartDataCallsCount += 1
      _postMultiPartDataFromParam = from
      _postMultiPartDataWithBearerTokenParam = withBearerToken
      _postMultiPartDataAndPayloadParam = andPayload
      _postMultiPartDataUsingBoundaryParam = usingBoundary
    }
    recordBearer(withBearerToken)
    try simulateUnauthorizedIfRequested()
    if !postMultiPartDataThrowableErrorSequence.isEmpty, let error = postMultiPartDataThrowableErrorSequence.removeFirst() {
      throw error
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

  /// Errors to throw from successive `execute(request:mappingInResponse:)` calls
  /// (nil = succeed); once exhausted, calls succeed with `returnData`.
  var executeThrowableErrorSequence: [Error?] = []

  func execute<ResponseType>(request: any PortalSwift.PortalBaseRequestProtocol, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    queue.sync {
      _executeCallsCount += 1
      _executeRequestParam = request
    }
    recordExecute(request)
    try simulateUnauthorizedIfRequested()

    if !executeThrowableErrorSequence.isEmpty, let error = executeThrowableErrorSequence.removeFirst() {
      throw error
    }

    let data = nextExecuteReturnData()

    if ResponseType.self == Data.self {
      return data as! ResponseType
    }

    return try JSONDecoder().decode(ResponseType.self, from: data)
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
    recordExecute(request)
    try simulateUnauthorizedIfRequested()
    return nextExecuteReturnData()
  }
}

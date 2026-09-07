//
//  RecordingPortalRequests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

// MARK: - RecordingPortalRequestsError

/// Thrown by `RecordingPortalRequests` when the auth module drives the transport through a verb
/// it must never use. The house rule is `execute(request:)` only — the deprecated verbs build
/// their own headers and would bypass the `x-portal-auth-environment-id` header and the trace
/// id that `PortalAuthApi` puts on a `PortalAPIRequest`.
enum RecordingPortalRequestsError: LocalizedError {
  case unexpectedVerb(String)

  var errorDescription: String? {
    switch self {
    case let .unexpectedVerb(verb):
      return "RecordingPortalRequests: the auth module must use execute(request:), but `\(verb)` was called."
    }
  }
}

// MARK: - RecordedRequest

/// One request the auth module handed to the transport, flattened so a test can assert on the
/// exact wire shape (URL, method, headers, bearer, trace id, JSON body) without re-deriving it
/// from a `PortalBaseRequestProtocol`.
///
/// `payloadData` is the `JSONEncoder` output of the request's `payload` — the same bytes the
/// real transport would put on the wire — and `payloadJSON` is that body parsed back into a
/// dictionary so a test can check `payloadJSON?["isAccountAbstracted"] as? Bool == true` (a
/// real `Bool`, not the string `"true"`) or count the keys exactly.
struct RecordedRequest {
  /// The absolute request URL, query included.
  let url: URL
  /// `url.path`, e.g. `/api/v3/auth/oauth/urls` (never the query).
  let path: String
  /// `url.query`, raw (still percent-encoded), or `nil` when the URL has none.
  let query: String?
  let method: HttpMethod
  /// Every header the request carried, exactly as `PortalBaseRequestProtocol.headers` had it.
  let headers: [String: String]
  /// The `Authorization` bearer with the `Bearer ` prefix stripped; `nil` when the request
  /// carried no `Authorization` header.
  let bearerToken: String?
  /// The `X-Portal-Trace-Id` header (matched case-insensitively), or `nil`.
  let traceId: String?
  /// The encoded JSON body, or `nil` for a request without a payload.
  let payloadData: Data?
  /// `payloadData` parsed as a JSON object; `nil` when there is no body or it is not an object.
  let payloadJSON: [String: Any]?

  /// `url.absoluteString`, for one-line URL assertions.
  var absoluteString: String {
    self.url.absoluteString
  }

  /// The body as UTF-8 text, or `nil` without a body.
  var payloadString: String? {
    self.payloadData.flatMap { String(data: $0, encoding: .utf8) }
  }

  /// The value of `name`, matched case-insensitively — HTTP header names are.
  func header(_ name: String) -> String? {
    self.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  /// `true` when `path` equals this request's path or is a suffix of it, so both
  /// `"/api/v3/auth/oauth/tokens"` and `"/oauth/tokens"` select the same request.
  func matches(path: String) -> Bool {
    self.path == path || self.path.hasSuffix(path)
  }

  init(_ request: PortalBaseRequestProtocol) {
    self.url = request.url
    self.path = request.url.path
    self.query = request.url.query
    self.method = request.method
    self.headers = request.headers
    self.bearerToken = Self.bearerToken(in: request.headers)
    self.traceId = request.headers.first { $0.key.caseInsensitiveCompare(PORTAL_TRACE_ID_HEADER) == .orderedSame }?.value

    if let payload = request.payload, let data = try? JSONEncoder().encode(payload) {
      self.payloadData = data
      self.payloadJSON = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    } else {
      self.payloadData = nil
      self.payloadJSON = nil
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
}

// MARK: - RecordingPortalRequests

/// The transport double for the auth module: records every `execute(request:)` call as a
/// `RecordedRequest`, answers from a scripted queue, and can hold the first request open so a
/// test can observe what the module does while an exchange is in flight.
///
/// **Answering.** Each call is resolved in this order: `failWith` (every call throws it) →
/// a per-path failure registered with `fail(with:onPath:)` → the head of `queuedResponses`
/// (consumed only on success paths; a throwing call never eats a queued body) → `responder`
/// (per-request bodies, e.g. one session token per endpoint) → `defaultResponse`.
///
/// **Gating.** With `gateFirstRequest == true` the first request is recorded and then parks on
/// a continuation (never a blocked thread) until `release()`. `waitUntilArrived()` lets the
/// test wait for that moment with a bounded poll, so a "two deliveries of one grant collapse
/// into one exchange" test can start the second delivery while the first is provably inside the
/// transport. Later requests are not gated; setting `gateFirstRequest = true` again re-arms it.
///
/// **401 hook.** Conforms to `PortalUnauthorizedReporting` like the real `PortalRequests`, and
/// mirrors its rule: `onUnauthorized` fires only for a `PortalRequestsError.unauthorized` on a
/// request that carried an `Authorization` header to a Portal-owned URL. `PortalAuthApi` never
/// installs the hook, so `onUnauthorized` must stay `nil` and `unauthorizedHookInvocations`
/// zero across every auth test — that is what the tests assert.
///
/// **Verbs.** The deprecated `get/post/put/patch/delete` and `postMultiPartData` fail the test
/// (`XCTFail`) and throw: `PortalAuthApi` must go through `execute(request:)` so the auth
/// environment header and trace id ride on a `PortalAPIRequest`.
///
/// All state is guarded by one `NSLock`; the module calls in from whatever executor resumed it.
final class RecordingPortalRequests: PortalRequestsProtocol, PortalUnauthorizedReporting {
  private let lock = NSLock()

  private var _recorded: [RecordedRequest] = []
  private var _defaultResponse: Data
  private var _queuedResponses: [Swift.Result<Data, Error>]
  private var _failWith: Error?
  private var _failuresByPath: [String: Error] = [:]
  private var _responder: ((RecordedRequest) throws -> Data)?

  private var _inFlightCount = 0
  private var _maxInFlight = 0

  private var _gateFirstRequest = false
  private var gateConsumed = false
  private var _gatedRequestArrived = false
  private var gateReleased = false
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

  private var _onUnauthorized: ((String?) -> Void)?
  private var _onUnauthorizedSetCount = 0
  private var _unauthorizedHookInvocations = 0

  /// - Parameters:
  ///   - defaultResponse: The body returned once `queuedResponses` is exhausted and no
  ///     `responder` is set. Empty by default, which `PortalAuthApi` reports as
  ///     `malformedResponse` — a loud failure for a test that forgot to queue a body, while
  ///     `sendMagicLink` (which ignores the body) still succeeds.
  ///   - queued: Bodies (or failures) to answer the first calls with, in order.
  init(defaultResponse: Data = Data(), queued: [Swift.Result<Data, Error>] = []) {
    self._defaultResponse = defaultResponse
    self._queuedResponses = queued
  }

  // MARK: Recording

  /// Every `execute` call, in call order.
  var recorded: [RecordedRequest] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._recorded
  }

  /// The number of `execute` calls so far (gated calls included — they are recorded on arrival).
  var callCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._recorded.count
  }

  /// Alias of `callCount`.
  var count: Int {
    self.callCount
  }

  /// The absolute URL string of every call, in order.
  var requestedUrls: [String] {
    self.recorded.map { $0.absoluteString }
  }

  /// The URL path of every call, in order (e.g. `/api/v3/auth/oauth/tokens`).
  var requestedPaths: [String] {
    self.recorded.map { $0.path }
  }

  /// The most recent call, or `nil` before the first.
  var lastRequest: RecordedRequest? {
    self.recorded.last
  }

  /// The `index`-th call. Traps like an array on an out-of-range index, which in a test is the
  /// right failure mode for "I expected a request that never happened".
  subscript(index: Int) -> RecordedRequest {
    self.recorded[index]
  }

  /// The calls whose path equals `path` or ends with it (see `RecordedRequest.matches(path:)`).
  func requests(toPath path: String) -> [RecordedRequest] {
    self.recorded.filter { $0.matches(path: path) }
  }

  // MARK: Scripting

  /// The body returned when nothing else answers a call. See `init`.
  var defaultResponse: Data {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._defaultResponse
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._defaultResponse = newValue
    }
  }

  /// Bodies or failures consumed one per successful-path call, FIFO. A call that throws because
  /// of `failWith` or a per-path failure leaves the queue untouched.
  var queuedResponses: [Swift.Result<Data, Error>] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._queuedResponses
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._queuedResponses = newValue
    }
  }

  /// Appends a success body to `queuedResponses`.
  func enqueue(_ data: Data) {
    self.enqueue(Swift.Result<Data, Error>.success(data))
  }

  /// Appends a failure to `queuedResponses`; the call that consumes it throws `error`.
  func enqueue(failure error: Error) {
    self.enqueue(Swift.Result<Data, Error>.failure(error))
  }

  /// Appends `result` to `queuedResponses`.
  func enqueue(_ result: Swift.Result<Data, Error>) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._queuedResponses.append(result)
  }

  /// When set, every call throws this error (after being recorded) until it is set back to
  /// `nil`. Use `AuthTestFixtures.rateLimited429` / `serverError503` / `unauthorized` /
  /// `clientError(status:body:)` for transport errors in the exact production message format.
  var failWith: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._failWith
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._failWith = newValue
    }
  }

  /// Makes every call whose path matches `path` (exact or suffix) throw `error`, leaving other
  /// paths answered normally. Pass `nil` for `error` to clear a registration.
  func fail(with error: Error?, onPath path: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._failuresByPath[path] = error
  }

  /// The per-path failures registered through `fail(with:onPath:)`.
  var failuresByPath: [String: Error] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._failuresByPath
  }

  /// Answers calls the queue did not: receives the recorded request and returns a body or
  /// throws. The way to give `/oauth/tokens` and `/magic-links/validations` different session
  /// tokens in one test.
  var responder: ((RecordedRequest) throws -> Data)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._responder
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._responder = newValue
    }
  }

  // MARK: Gate

  /// When `true`, the next (first un-gated) request is recorded and then held until `release()`.
  /// Setting it to `true` re-arms the gate even after a previous release.
  var gateFirstRequest: Bool {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._gateFirstRequest
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._gateFirstRequest = newValue
      if newValue {
        self.gateConsumed = false
        self._gatedRequestArrived = false
        self.gateReleased = false
      }
    }
  }

  /// `true` once the gated request has been recorded (it may or may not have been released).
  var hasGatedRequestArrived: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._gatedRequestArrived
  }

  /// `true` while the gated request is parked waiting for `release()`.
  var isHoldingRequest: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._gatedRequestArrived && !self.gateReleased
  }

  /// Polls (every 10 ms, at most `timeout` seconds) until the gated request has arrived.
  /// Returns whether it did, so the caller can `XCTAssertTrue` it with a message.
  func waitUntilArrived(timeout: TimeInterval = 2) async -> Bool {
    await waitUntil(timeout: timeout) { self.hasGatedRequestArrived }
  }

  /// Lets the gated request proceed to its scripted answer. Idempotent; calling it before the
  /// request arrives means the request will not be held at all.
  func release() {
    self.lock.lock()
    self.gateReleased = true
    let waiters = self.releaseWaiters
    self.releaseWaiters = []
    self.lock.unlock()

    for waiter in waiters {
      waiter.resume()
    }
  }

  // MARK: Concurrency observation

  /// How many `execute` calls are inside the transport right now (including a held one).
  var inFlightCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._inFlightCount
  }

  /// The highest `inFlightCount` ever observed. `1` proves the caller serialised its requests.
  var maxInFlight: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._maxInFlight
  }

  // MARK: PortalUnauthorizedReporting

  /// The 401 hook. `PortalAuthApi` never installs one, so tests assert this stays `nil`.
  /// Assigning a non-nil closure bumps `onUnauthorizedSetCount`.
  var onUnauthorized: ((String?) -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onUnauthorized
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onUnauthorized = newValue
      if newValue != nil {
        self._onUnauthorizedSetCount += 1
      }
    }
  }

  /// How many times a non-nil `onUnauthorized` was installed.
  var onUnauthorizedSetCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._onUnauthorizedSetCount
  }

  /// How many times `onUnauthorized` was actually invoked (a `nil` hook is never counted).
  var unauthorizedHookInvocations: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._unauthorizedHookInvocations
  }

  // MARK: PortalRequestsProtocol

  func execute(request: PortalBaseRequestProtocol) async throws -> Data {
    let recorded = self.record(request)
    defer { self.finishInFlight() }

    await self.holdIfGated()

    do {
      return try self.resolve(recorded)
    } catch {
      self.notifyUnauthorizedIfApplicable(for: recorded, error: error)
      throw error
    }
  }

  func execute<ResponseType>(request: PortalBaseRequestProtocol, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    let data = try await self.execute(request: request)

    if let typed = data as? ResponseType {
      return typed
    }
    if ResponseType.self == String.self, let typed = (String(data: data, encoding: .utf8) ?? "") as? ResponseType {
      return typed
    }
    return try JSONDecoder().decode(ResponseType.self, from: data)
  }

  func postMultiPartData(_: URL, withBearerToken _: String, andPayload _: String, usingBoundary _: String) async throws -> Data {
    try self.rejectUnexpectedVerb("postMultiPartData")
  }

  func delete(_: URL, withBearerToken _: String?) async throws -> Data {
    try self.rejectUnexpectedVerb("delete")
  }

  func get(_: URL, withBearerToken _: String?) async throws -> Data {
    try self.rejectUnexpectedVerb("get")
  }

  func patch(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    try self.rejectUnexpectedVerb("patch")
  }

  func put(_: URL, withBearerToken _: String?, andPayload _: any Codable) async throws -> Data {
    try self.rejectUnexpectedVerb("put")
  }

  func post(_: URL, withBearerToken _: String?, andPayload _: (any Codable)?) async throws -> Data {
    try self.rejectUnexpectedVerb("post")
  }

  // MARK: Private

  private func record(_ request: PortalBaseRequestProtocol) -> RecordedRequest {
    let recorded = RecordedRequest(request)
    self.lock.lock()
    defer { self.lock.unlock() }
    self._recorded.append(recorded)
    self._inFlightCount += 1
    self._maxInFlight = max(self._maxInFlight, self._inFlightCount)
    return recorded
  }

  private func finishInFlight() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._inFlightCount -= 1
  }

  /// Parks the first request while the gate is armed and unreleased. The check and the enqueue
  /// happen under the lock, so a `release()` racing the arrival cannot be missed.
  private func holdIfGated() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.lock.lock()
      guard self._gateFirstRequest, !self.gateConsumed else {
        self.lock.unlock()
        continuation.resume()
        return
      }
      self.gateConsumed = true
      self._gatedRequestArrived = true
      if self.gateReleased {
        self.lock.unlock()
        continuation.resume()
        return
      }
      self.releaseWaiters.append(continuation)
      self.lock.unlock()
    }
  }

  private func resolve(_ recorded: RecordedRequest) throws -> Data {
    self.lock.lock()
    let globalFailure = self._failWith
    let pathFailure = self._failuresByPath.first { recorded.matches(path: $0.key) }?.value
    var queued: Swift.Result<Data, Error>?
    if globalFailure == nil, pathFailure == nil, !self._queuedResponses.isEmpty {
      queued = self._queuedResponses.removeFirst()
    }
    let responder = self._responder
    let fallback = self._defaultResponse
    self.lock.unlock()

    if let error = globalFailure {
      throw error
    }
    if let error = pathFailure {
      throw error
    }
    if let queued = queued {
      return try queued.get()
    }
    if let responder = responder {
      return try responder(recorded)
    }
    return fallback
  }

  /// Mirrors `PortalRequests.notifyUnauthorizedIfApplicable`: an `Authorization` header (any
  /// scheme) on a Portal-owned URL, rejected with `.unauthorized`.
  private func notifyUnauthorizedIfApplicable(for recorded: RecordedRequest, error: Error) {
    guard case .unauthorized? = error as? PortalRequestsError else {
      return
    }
    guard recorded.header("Authorization") != nil, isPortalOwnedUrl(recorded.absoluteString) else {
      return
    }

    self.lock.lock()
    let hook = self._onUnauthorized
    if hook != nil {
      self._unauthorizedHookInvocations += 1
    }
    self.lock.unlock()

    hook?(recorded.bearerToken)
  }

  private func rejectUnexpectedVerb(_ verb: String) throws -> Data {
    XCTFail("RecordingPortalRequests: the auth module must use execute(request:), but `\(verb)` was called.")
    throw RecordingPortalRequestsError.unexpectedVerb(verb)
  }
}

//
//  MockURLProtocol.swift
//  PortalSwiftTests
//
//  A `URLProtocol` that answers requests from a scripted handler so the real `PortalRequests`
//  pipeline can be exercised end to end without touching the network.
//

import Foundation

/// Thrown by `MockURLProtocol` when a request arrives and no handler was installed, so a test
/// that forgot to script a response fails loudly instead of hanging or hitting the network.
enum MockURLProtocolError: LocalizedError {
  case noHandlerInstalled

  var errorDescription: String? {
    switch self {
    case .noHandlerInstalled:
      return "MockURLProtocol received a request but no handler is installed. Call respond(...)/fail(with:) first."
    }
  }
}

/// A `URLProtocol` subclass that drives the real `PortalRequests` implementation.
///
/// Register it on a session through `makeSession()` and hand that session to
/// `PortalRequests(urlSession:)`. Every request the transport builds is recorded verbatim in
/// `recordedRequests` (with the body materialised, because URLSession delivers bodies to a
/// protocol as an `httpBodyStream`, not `httpBody`), then answered by the scripted handler:
/// `respond(status:body:headers:)` for an HTTP status, `fail(with:)` for a transport error, or
/// `respondWithNonHttpResponse()` for the "not an `HTTPURLResponse`" edge. All state is static
/// (URLSession instantiates the protocol itself) and lock-guarded because the loading system
/// calls in from its own threads; `reset()` in `setUp` keeps tests independent.
final class MockURLProtocol: URLProtocol {
  typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
  typealias RawHandler = (URLRequest) throws -> (URLResponse, Data)

  private static let lock = NSLock()
  private static var _handler: Handler?
  private static var _rawHandler: RawHandler?
  private static var _recordedRequests: [URLRequest] = []

  /// The scripted answer for the next requests. Setting it clears any raw (non-HTTP) handler.
  static var handler: Handler? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _handler
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _handler = newValue
      _rawHandler = nil
    }
  }

  /// Every request the loading system handed to this protocol, in arrival order, with
  /// `httpBody` populated from the body stream when the transport sent one.
  static var recordedRequests: [URLRequest] {
    lock.lock()
    defer { lock.unlock() }
    return _recordedRequests
  }

  /// The most recent recorded request, for the common single-request assertion.
  static var lastRequest: URLRequest? {
    recordedRequests.last
  }

  /// Answers every request with `status`, `body` and `headers` (HTTP/1.1).
  static func respond(status: Int, body: Data = Data(), headers: [String: String] = [:]) {
    handler = { request in
      guard let url = request.url else {
        throw URLError(.badURL)
      }
      guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
        throw URLError(.badServerResponse)
      }
      return (response, body)
    }
  }

  /// Convenience overload taking a UTF-8 string body.
  static func respond(status: Int, body: String, headers: [String: String] = [:]) {
    respond(status: status, body: Data(body.utf8), headers: headers)
  }

  /// Fails every request with a transport-level `URLError` (no HTTP response at all).
  static func fail(with error: URLError) {
    handler = { _ in throw error }
  }

  /// Answers every request with a plain `URLResponse` that is not an `HTTPURLResponse`, so the
  /// transport's `couldNotParseHttpResponse` branch can be reached.
  static func respondWithNonHttpResponse(body: Data = Data()) {
    lock.lock()
    defer { lock.unlock() }
    _handler = nil
    _rawHandler = { request in
      guard let url = request.url else {
        throw URLError(.badURL)
      }
      let response = URLResponse(url: url, mimeType: nil, expectedContentLength: body.count, textEncodingName: nil)
      return (response, body)
    }
  }

  /// An ephemeral session that routes every request through this protocol and never caches.
  static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }

  /// Clears the handler and the recorded requests. Call from `setUp`.
  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    _handler = nil
    _rawHandler = nil
    _recordedRequests = []
  }

  // MARK: - URLProtocol

  override class func canInit(with _: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let recorded = Self.materialisingBody(of: self.request)
    Self.record(recorded)

    guard let client = self.client else {
      return
    }

    do {
      let (response, data) = try Self.resolveResponse(for: recorded)
      client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client.urlProtocol(self, didLoad: data)
      client.urlProtocolDidFinishLoading(self)
    } catch {
      client.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  // MARK: - Private

  private static func record(_ request: URLRequest) {
    lock.lock()
    defer { lock.unlock() }
    _recordedRequests.append(request)
  }

  private static func resolveResponse(for request: URLRequest) throws -> (URLResponse, Data) {
    lock.lock()
    let rawHandler = _rawHandler
    let httpHandler = _handler
    lock.unlock()

    if let rawHandler = rawHandler {
      return try rawHandler(request)
    }
    if let httpHandler = httpHandler {
      let (response, data) = try httpHandler(request)
      return (response, data)
    }
    throw MockURLProtocolError.noHandlerInstalled
  }

  /// URLSession converts `httpBody` into `httpBodyStream` before handing the request to a
  /// protocol, so the body is read back from the stream here to make payload assertions possible.
  private static func materialisingBody(of request: URLRequest) -> URLRequest {
    var copy = request
    if copy.httpBody == nil, let stream = request.httpBodyStream {
      copy.httpBody = readAll(stream)
    }
    return copy
  }

  private static func readAll(_ stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: bufferSize)
      guard count > 0 else {
        break
      }
      data.append(buffer, count: count)
    }
    return data
  }
}

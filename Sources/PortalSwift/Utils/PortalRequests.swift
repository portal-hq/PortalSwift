import Foundation

/// A transport that can tell its owner when a Portal-authenticated request was rejected with
/// HTTP 401.
///
/// The SDK resolves the client's credential per request, so the transport is the only layer
/// that reliably observes every rejection. Rather than teaching each API surface about
/// sessions, the credentials layer installs a single closure here and the transport calls it
/// whenever a request that carried an `Authorization` header to a Portal-owned host comes back
/// `401`. The hook fires before the `PortalRequestsError.unauthorized` is rethrown, so the
/// credential is already invalidated by the time the caller handles the error.
///
/// `PortalRequestsProtocol` deliberately does not require this conformance: existing doubles
/// and host-written transports keep compiling, and the credentials layer installs the hook
/// only when `requests as? PortalUnauthorizedReporting` succeeds.
public protocol PortalUnauthorizedReporting: AnyObject {
  /// Called once per rejected request. The closure is non-throwing and must not assume any
  /// particular thread: the transport invokes it from whichever context completed the request.
  var onUnauthorized: (() -> Void)? { get set }
}

public protocol PortalRequestsProtocol {
  /// Preferred method for executing requests and mapping responses.
  @discardableResult
  func execute<ResponseType>(
    request: PortalBaseRequestProtocol,
    mappingInResponse response: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable

  /// Preferred method for executing requests and and getting Data response.
  @discardableResult
  func execute(
    request: PortalBaseRequestProtocol
  ) async throws -> Data

  @discardableResult
  func postMultiPartData(
    _ from: URL,
    withBearerToken: String,
    andPayload: String,
    usingBoundary: String
  ) async throws -> Data

  // MARK: - Deprecated functions

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  func delete(_ from: URL, withBearerToken: String?) async throws -> Data

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  func get(_ from: URL, withBearerToken: String?) async throws -> Data

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  func patch(_ from: URL, withBearerToken: String?, andPayload: Codable) async throws -> Data

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  func put(_ from: URL, withBearerToken: String?, andPayload: Codable) async throws -> Data

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  func post(_ from: URL, withBearerToken: String?, andPayload: Codable?) async throws -> Data
}

public class PortalRequests: PortalRequestsProtocol, PortalUnauthorizedReporting {
  /// A session supplied through the internal test seam. When present it replaces the
  /// per-request session so tests can register a `URLProtocol` and drive the real pipeline
  /// without touching the network; production callers never set it.
  private let injectedSession: URLSession?

  private let unauthorizedHookLock = NSLock()
  private var _onUnauthorized: (() -> Void)?

  /// The closure the credentials layer installs to learn about `401` rejections. Guarded by a
  /// lock because requests complete on URLSession's threads while the hook is installed (and
  /// in tests replaced) from elsewhere; the value read at invocation time is the one used.
  public var onUnauthorized: (() -> Void)? {
    get {
      self.unauthorizedHookLock.lock()
      defer { self.unauthorizedHookLock.unlock() }
      return self._onUnauthorized
    }
    set {
      self.unauthorizedHookLock.lock()
      defer { self.unauthorizedHookLock.unlock() }
      self._onUnauthorized = newValue
    }
  }

  public init() {
    self.injectedSession = nil
  }

  /// Test seam: routes every request through `urlSession` instead of a fresh per-request
  /// session, so a `URLProtocol` registered on that session observes exactly what the
  /// transport would send over the wire (headers, body, trace gating, 401 handling).
  init(urlSession: URLSession) {
    self.injectedSession = urlSession
  }

  @discardableResult
  public func execute(request: PortalBaseRequestProtocol) async throws -> Data {
    // create the request
    let request = try createBaseRequest(portalRequest: request)
    // execute the request
    return try await executeRequest(request)
  }

  @discardableResult
  public func execute<ResponseType>(request: PortalBaseRequestProtocol,
                                    mappingInResponse _: ResponseType.Type)
    async throws -> ResponseType where ResponseType: Decodable
  {
    // create the request
    let request = try createBaseRequest(portalRequest: request)
    // execute the request
    let data = try await executeRequest(request)

    // Special case when ResponseType is Data
    if ResponseType.self == Data.self {
      // Force cast is safe here because we've checked the type
      return data as! ResponseType
    } else if ResponseType.self == String.self {
      return (String(data: data, encoding: .utf8) ?? "") as! ResponseType
    }

    // decode the response for all other types other than Data
    let result = try JSONDecoder().decode(ResponseType.self, from: data)
    // return the decode object
    return result
  }

  @discardableResult
  public func postMultiPartData(
    _ from: URL,
    withBearerToken: String,
    andPayload: String,
    usingBoundary: String
  ) async throws -> Data {
    var request = try createBaseRequest(url: from, method: .post, bearerToken: withBearerToken)

    // Override headers for multipart
    request.setValue("multipart/related; boundary=\(usingBoundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = andPayload.data(using: .utf8)

    return try await executeRequest(request)
  }

  // MARK: - Deprecated functions

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  public func delete(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    let request = try createBaseRequest(url: from, method: .delete, bearerToken: withBearerToken)
    return try await executeRequest(request)
  }

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  public func get(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    let request = try createBaseRequest(url: from, method: .get, bearerToken: withBearerToken)
    return try await executeRequest(request)
  }

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  public func patch(_ from: URL, withBearerToken: String? = nil, andPayload: Codable) async throws -> Data {
    var request = try createBaseRequest(url: from, method: .patch, bearerToken: withBearerToken)
    request.httpBody = try JSONEncoder().encode(andPayload)
    return try await executeRequest(request)
  }

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  public func put(_ from: URL, withBearerToken: String? = nil, andPayload: Codable) async throws -> Data {
    var request = try createBaseRequest(url: from, method: .put, bearerToken: withBearerToken)
    request.httpBody = try JSONEncoder().encode(andPayload)
    return try await executeRequest(request)
  }

  /// Deprecated: Use `execute(request:mappingInResponse:)` instead.
  @available(*, deprecated, message: "Use execute(request:mappingInResponse:) instead.")
  @discardableResult
  public func post(_ from: URL, withBearerToken: String? = nil, andPayload: Codable? = nil) async throws -> Data {
    var request = try createBaseRequest(url: from, method: .post, bearerToken: withBearerToken)

    if let payload = andPayload {
      request.httpBody = try JSONEncoder().encode(payload)
      if let bodyLength = request.httpBody?.count {
        request.addValue("\(bodyLength)", forHTTPHeaderField: "Content-Length")
      }
    }

    return try await executeRequest(request)
  }

  // MARK: - Private Methods

  private func createBaseRequest(url: URL, method: HttpMethod, bearerToken: String?, traceId: String? = nil) throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue

    if let token = bearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(traceId ?? generateTraceId(), forHTTPHeaderField: PORTAL_TRACE_ID_HEADER)

    return request
  }

  private func createBaseRequest(portalRequest: PortalBaseRequestProtocol) throws -> URLRequest {
    var request = URLRequest(url: portalRequest.url)
    request.httpMethod = portalRequest.method.rawValue

    for (key, value) in portalRequest.headers {
      request.addValue(value, forHTTPHeaderField: key)
    }

    // Guarantee a trace ID header even if a custom request omitted it.
    if portalRequest.headers[PORTAL_TRACE_ID_HEADER] == nil {
      request.addValue(generateTraceId(), forHTTPHeaderField: PORTAL_TRACE_ID_HEADER)
    }

    if let payload = portalRequest.payload {
      request.httpBody = try JSONEncoder().encode(payload)
      if let bodyLength = request.httpBody?.count {
        request.addValue("\(bodyLength)", forHTTPHeaderField: "Content-Length")
      }
    }

    return request
  }

  private func executeRequest(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }

    guard httpResponse.statusCode < 300 else {
      let error = self.buildError(httpResponse, withData: data, url: request.url?.absoluteString ?? "")
      if httpResponse.statusCode == 401 {
        // Notify first so the credential is already invalidated when the caller sees the error.
        // The hook is non-throwing; nothing here may prevent the rethrow below.
        self.notifyUnauthorizedIfApplicable(for: request)
      }
      throw error
    }

    return data
  }

  /// Fires `onUnauthorized` for a `401` only when the request is one the credentials layer is
  /// responsible for: it carried an `Authorization` header (any scheme) and targeted a
  /// Portal-owned host. A `401` from Google Drive with a Google token, or from a custom RPC
  /// gateway, says nothing about the Portal session and must not invalidate it. Neither the
  /// header nor the response body is ever logged.
  private func notifyUnauthorizedIfApplicable(for request: URLRequest) {
    guard request.value(forHTTPHeaderField: "Authorization") != nil else {
      return
    }
    guard let url = request.url, isPortalOwnedUrl(url.absoluteString) else {
      return
    }
    guard let hook = self.onUnauthorized else {
      PortalLogger.shared.debug("PortalRequests.executeRequest() - Received 401 from a Portal host but no unauthorized hook is registered.")
      return
    }
    PortalLogger.shared.debug("PortalRequests.executeRequest() - Received 401 from a Portal host; notifying the unauthorized hook.")
    hook()
  }

  private func buildError(_ response: HTTPURLResponse, withData: Data, url: String) -> Error {
    let statusText = String(data: withData, encoding: .utf8) ?? ""
    if response.statusCode < 400 {
      return PortalRequestsError.redirectError("\(response.statusCode) - \(statusText)")
    } else if response.statusCode == 401 {
      return PortalRequestsError.unauthorized
    } else if response.statusCode < 500 {
      return PortalRequestsError.clientError("\(response.statusCode) - \(statusText)", url: url)
    } else {
      return PortalRequestsError.internalServerError("\(response.statusCode) - \(statusText)", url: url)
    }
  }

  private func getURLSession() -> URLSession {
    if let injectedSession = self.injectedSession {
      return injectedSession
    }

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

    return URLSession(configuration: configuration)
  }
}

public enum PortalRequestsError: LocalizedError, Equatable {
  case clientError(_ message: String, url: String)
  case couldNotParseHttpResponse
  case internalServerError(_ message: String, url: String)
  case redirectError(_ message: String)
  case unauthorized

  var dataStr: String? {
    switch self {
    case let .clientError(message, _):
      return getDataStr(from: message)
    case let .internalServerError(message, _):
      return getDataStr(from: message)
    case let .redirectError(message):
      return getDataStr(from: message)
    default:
      return nil
    }
  }

  private func getDataStr(from message: String) -> String? {
    let messageComponents = message.components(separatedBy: " - ")
    if messageComponents.count >= 2 {
      return messageComponents[1]
    }
    return nil
  }
}

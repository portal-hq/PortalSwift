import Foundation

public class PortalRequests {
  public init() {}

  public func delete(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Send the request
    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }
    guard httpResponse.statusCode < 300 else {
      throw self.buildError(httpResponse, withData: data)
    }

    return data
  }

  public func get(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Make sure we're sending a DELETE request
    request.httpMethod = "GET"

    // Send the request
    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }
    guard httpResponse.statusCode < 300 else {
      throw self.buildError(httpResponse, withData: data)
    }

    let logger = PortalLogger()

    return data
  }

  public func patch(_ from: URL, withBearerToken: String? = nil, andPayload: Encodable) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Make sure we're sending a PATCH request with the data provided
    request.httpMethod = "PATCH"
    request.httpBody = try JSONEncoder().encode(andPayload)

    // Send the request
    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }
    guard httpResponse.statusCode < 300 else {
      throw self.buildError(httpResponse, withData: data)
    }

    return data
  }

  public func post(_ from: URL, withBearerToken: String? = nil, andPayload: Encodable? = nil) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Make sure we're sending a POST request with the data provided
    request.httpMethod = "POST"

    if let payload = andPayload {
      request.httpBody = try JSONEncoder().encode(payload)
      request.addValue("\((String(data: request.httpBody!, encoding: .utf8) ?? "").count)", forHTTPHeaderField: "Content-Length")
    }

    // Send the request
    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }
    guard httpResponse.statusCode < 300 else {
      throw self.buildError(httpResponse, withData: data)
    }

    return data
  }

  public func postMultiPartData(
    _ from: URL,
    withBearerToken: String,
    andPayload: String,
    usingBoundary: String
  ) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(withBearerToken)", forHTTPHeaderField: "Authorization")
    request.addValue("multipart/related; boundary=\(usingBoundary)", forHTTPHeaderField: "Content-Type")

    request.httpMethod = "POST"
    request.httpBody = andPayload.data(using: .utf8)

    let (data, response) = try await getURLSession().data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PortalRequestsError.couldNotParseHttpResponse
    }
    guard httpResponse.statusCode < 300 else {
      throw self.buildError(httpResponse, withData: data)
    }

    return data
  }

  private func buildError(_ response: HTTPURLResponse, withData: Data) -> Error {
    let statusText = String(data: withData, encoding: .utf8) ?? ""
    if response.statusCode < 400 {
      return PortalRequestsError.redirectError("\(response.statusCode) - \(statusText)")
    } else if response.statusCode < 500 {
      return PortalRequestsError.clientError("\(response.statusCode) - \(statusText)")
    } else {
      return PortalRequestsError.internalServerError("\(response.statusCode) - \(statusText)")
    }
  }

  private func getURLSession() -> URLSession {
    var configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

    return URLSession(configuration: configuration)
  }
}

public enum PortalRequestsError: Error, Equatable {
  case clientError(_ message: String)
  case couldNotParseHttpResponse
  case internalServerError(_ message: String)
  case redirectError(_ message: String)
}
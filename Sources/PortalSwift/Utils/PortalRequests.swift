import Foundation

public enum PortalRequests {
  public static func delete(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Send the request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the response status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 else {
      throw URLError(.badServerResponse)
    }

    return data
  }

  public static func get(_ from: URL, withBearerToken: String? = nil) async throws -> Data {
    var request = URLRequest(url: from)

    // Add required request headers
    if let token = withBearerToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Make sure we're sending a DELETE request
    request.httpMethod = "DELETE"

    // Send the request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the response status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 else {
      throw URLError(.badServerResponse)
    }

    return data
  }

  public static func patch(_ from: URL, withBearerToken: String? = nil, andPayload: Encodable) async throws -> Data {
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
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the response status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 else {
      throw URLError(.badServerResponse)
    }

    return data
  }

  public static func post(_ from: URL, withBearerToken: String? = nil, andPayload: Encodable? = nil) async throws -> Data {
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
    }

    // Send the request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the response status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 else {
      throw URLError(.badServerResponse)
    }

    return data
  }

  public static func postMultiPartData(
    _ from: URL,
    withBearerToken: String,
    andPayload: Encodable
  ) async throws -> Data {
    var request = URLRequest(url: from)

    let body = try JSONEncoder().encode(andPayload)

    // Add required request headers
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(withBearerToken)", forHTTPHeaderField: "Authorization")
    request.addValue("\(body.count)", forHTTPHeaderField: "Content-Length")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the reponse status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 else {
      throw URLError(.badServerResponse)
    }

    return data
  }
}

//
//  HttpRequest.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum HttpRequestType {
  case GatewayRequest
  case CustomRequest
}

private enum HttpError: Error {
  case clientError(String)
  case httpError(String)
  case internalServerError(String)
  case nilResponseError
  case unknownError(String)
}

private enum GatewayError: Error {
  case gatewayError(response: ETHGatewayErrorResponse, status: String)
}

extension GatewayError: CustomStringConvertible {
  public var description: String {
    switch self {
    case let .gatewayError(response, status):
      return "HTTP Gateway Error -status: \(status) -code: \(response.code) -message: \(response.message)"
    }
  }
}

/// A class for making HTTP requests.
public class HttpRequest<T: Codable, BodyType> {
  private var body: BodyType?
  private var headers: [String: String]
  private var method: String
  private var url: String
  private var requestType: HttpRequestType

  /// Creates an instance of HttpRequest.
  /// - Parameters:
  ///   - url: The URL to make a request to.
  ///   - method: The HTTP method to use.
  ///   - body: The body of a type you specify.
  ///   - headers: The HTTP headers.
  public init(
    url: String,
    method: String,
    body: BodyType?,
    headers: [String: String],
    requestType: HttpRequestType
  ) {
    self.body = body
    self.headers = headers
    self.method = method
    self.url = url
    self.requestType = requestType
  }

  /// Sends an HTTP request.
  /// - Parameter completion: Resolves as a result with the HTTP response.
  /// - Returns: Void.
  public func send(completion: @escaping (Result<T>) -> Void) {
    do {
      // Build the request object
      let request = try prepareRequest()

      // Make the request via URLSession
      let task = URLSession.shared.dataTask(with: request) { data, response, error in
        do {
          // Handle errors
          if error != nil {
            return completion(Result<T>(error: HttpError.unknownError(error!.localizedDescription)))
          }

          // Parse the response and return the properly typed data
          let httpResponse = response as? HTTPURLResponse

          if httpResponse == nil {
            return completion(Result(error: HttpError.nilResponseError))
          }

          // Process the response object
          if httpResponse!.statusCode == 204 {
            return completion(Result(data: "OK" as! T))
          } else if httpResponse!.statusCode >= 200, httpResponse!.statusCode < 300 {
            var typedData: T
            // Decode the response into the appropriate type
            if T.self == String.self {
              typedData = String(data: data!, encoding: .utf8) as! T
            } else if T.self == [String: Any].self {
              typedData = self.dataToDictionary(data!) as! T
            } else if T.self == [Any].self {
              typedData = self.dataToArray(data!) as! T
            } else {
              typedData = try JSONDecoder().decode(T.self, from: data!)
            }

            // Pass off to the completion closure
            return completion(Result(data: typedData))
          } else if httpResponse!.statusCode >= 500 {
            if self.requestType == HttpRequestType.GatewayRequest {
              var typedData: T

              // Decode the response into the appropriate type
              if T.self == String.self {
                typedData = String(data: data!, encoding: .utf8) as! T
              } else if T.self == [String: Any].self {
                typedData = self.dataToDictionary(data!) as! T
              } else if T.self == [Any].self {
                typedData = self.dataToArray(data!) as! T
              } else {
                typedData = try JSONDecoder().decode(T.self, from: data!)
              }
              return completion(Result(error: GatewayError.gatewayError(response: (typedData as! ETHGatewayResponse).error!, status: String(httpResponse!.statusCode))))
            }
            return completion(Result(error: HttpError.internalServerError("Status: \(httpResponse!.statusCode) " + String(data: data!, encoding: .utf8)!)))
          } else if httpResponse!.statusCode >= 400 {
            if self.requestType == HttpRequestType.GatewayRequest {
              var typedData: T

              // Decode the response into the appropriate type
              if T.self == String.self {
                typedData = String(data: data!, encoding: .utf8) as! T
              } else if T.self == [String: Any].self {
                typedData = self.dataToDictionary(data!) as! T
              } else if T.self == [Any].self {
                typedData = self.dataToArray(data!) as! T
              } else {
                typedData = try JSONDecoder().decode(T.self, from: data!)
              }
              return completion(Result(error: GatewayError.gatewayError(response: (typedData as? ETHGatewayResponse)?.error! ?? ETHGatewayErrorResponse(code: 32602, message: "Unknown Error"), status: String(httpResponse!.statusCode))))
            }
            return completion(Result(error: HttpError.clientError("Status: \(httpResponse!.statusCode) " + String(data: data!, encoding: .utf8)!)))
          } else {
            return completion(Result(error: HttpError.internalServerError("Status: \(httpResponse!.statusCode) " + String(data: data!, encoding: .utf8)!)))
          }
        } catch {
          return completion(Result(error: error))
        }
      }

      task.resume()
    } catch {
      return completion(Result(error: error))
    }
  }

  private func prepareRequest() throws -> URLRequest {
    do {
      // Build URLRequest instance
      let url = URL(string: url)
      var request = URLRequest(url: url!)

      // Set the request method of the request
      request.httpMethod = self.method

      // Add request headers as defined in the constructor
      for (key, value) in self.headers {
        request.setValue(value, forHTTPHeaderField: key)
      }

      // If no Content-Type header was provided, set one.
      if self.headers["Content-Type"] == nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }

      // Set the request body to the string literal of the Dictionary
      if self.headers["Content-Type"] != nil && (self.headers["Content-Type"]!).contains("multipart") {
        let rawBody = (body as! [String: Any])["rawBody"] as! String
        request.httpBody = rawBody.data(using: .utf8)
      } else if self.method != "GET" && self.method != "DELETE" && self.body != nil {
        request.httpBody = try JSONSerialization.data(withJSONObject: self.body!, options: [])
      } else {
        request.httpBody = nil
      }

      return request
    }
  }

  private func dataToDictionary(_ data: Data) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
  }

  private func dataToArray(_ data: Data) -> [Any]? {
    try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [Any]
  }
}

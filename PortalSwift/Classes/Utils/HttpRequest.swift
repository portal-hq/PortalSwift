//
//  HttpRequest.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import UIKit

private enum HttpError: Error {
  case clientError(String)
  case httpError(String)
  case internalServerError(String)
  case nilResponseError
  case unknownError(String)
}

/// A class for making HTTP requests.
public class HttpRequest<T: Codable, U> {
  private var body: U?
  private var headers: Dictionary<String, String>
  private var method: String
  private var url: String
  private var isString: Bool

  /// Creates an instance of HttpRequest.
  /// - Parameters:
  ///   - url: The URL to make a request to.
  ///   - method: The HTTP method to use.
  ///   - body: The body of a type you specify.
  ///   - headers: The HTTP headers.
  public init(
    url: String,
    method: String,
    body: U?,
    headers: Dictionary<String, String>
  ) {
    self.body = body
    self.headers = headers
    self.method = method
    self.url = url
    self.isString = false
  }

  /// Creates an instance of HttpRequest.
  /// - Parameters:
  ///   - url: The URL to make a request to.
  ///   - method: The HTTP method to use.
  ///   - body: The body of a type you specify.
  ///   - headers: The HTTP headers.
  ///   - isString: If we should convert the response to a string.
  public init(
    url: String,
    method: String,
    body: U?,
    headers: Dictionary<String, String>,
    isString: Bool
  ) {
    self.body = body
    self.headers = headers
    self.method = method
    self.url = url
    self.isString = isString
  }

  /// Sends an HTTP request.
  /// - Parameter completion: Resolves as a result with the HTTP response.
  /// - Returns: Void.
  public func send(completion: @escaping (Result<T>) -> Void) -> Void {
    do {
      // Build the request object
      let request = try prepareRequest()

      // Make the request via URLSession
      let task = URLSession.shared.dataTask(with: request) {
        (data, response, error) -> Void in
        do {
          // Handle errors
          if (error != nil) {
            return completion(Result<T>(error: HttpError.unknownError(error!.localizedDescription)))
          }

          // Parse the response and return the properly typed data
          let httpResponse = response as? HTTPURLResponse

          if (httpResponse == nil) {
            return completion(Result(error: HttpError.nilResponseError))
          }

          // Process the response object
          if httpResponse?.statusCode == 200 {
            // Decode the response into the appropriate type
            let typedData = try JSONDecoder().decode(T.self, from: data!)

            // Pass off to the completion closure
            return completion(Result(data: typedData))
          } else if httpResponse!.statusCode >= 500 {
            return completion(Result(error: HttpError.internalServerError(httpResponse!.description)))
          } else if httpResponse!.statusCode >= 400 {
            return completion(Result(error: HttpError.clientError(httpResponse!.description)))
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
      request.httpMethod = method

      // Add request headers as defined in the constructor
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
      
      // If no Content-Type header was provided, set one.
      if (headers["Content-Type"] == nil) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }

      // Set the request body to the string literal of the Dictionary
      if (headers["Content-Type"] != nil && (headers["Content-Type"]!).contains("multipart")) {
        let rawBody = (body as! Dictionary<String, Any>)["rawBody"] as! String
        request.httpBody = rawBody.data(using: .utf8)
      } else if (method != "GET" && body != nil) {
        request.httpBody = try JSONSerialization.data(withJSONObject: body!, options: [])
      } else {
        request.httpBody = nil
      }

      return request
    }
  }
}

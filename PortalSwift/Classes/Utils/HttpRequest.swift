//
//  HttpRequest.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import UIKit

private enum HttpError: Error {
  case clientError
  case internalServerError
  case httpError(String)
  case unknownError
}

public class HttpRequest<T: Codable, U: Codable> {
  private var body: U?
  private var headers: Dictionary<String, String>
  private var method: String
  private var url: String

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
  }

  public func send(completion: @escaping (T) -> Void) throws -> Void {
    do {
      // Build the request object
      let request = try prepareRequest()

      // Make the request via URLSession
      let task = URLSession.shared.dataTask(with: request) {
        (data, response, error) -> Void in

        do {
          // Handle errors
          if (error != nil) {
            throw HttpError.httpError(error!.localizedDescription)
          }

          // Parse the response and return the properly typed data
          let httpResponse = response as? HTTPURLResponse

          if (httpResponse == nil) {
            throw HttpError.unknownError
          }

          // Process the response object
          if httpResponse?.statusCode == 200 {
            // Decode the response into the appropriate type
            let decoder = JSONDecoder()
            let typedData = try decoder.decode(T.self, from: data!)

            // Pass off to the completion closure
            _ = completion(typedData)
          } else if httpResponse!.statusCode >= 500 {
            throw HttpError.internalServerError
          } else if httpResponse!.statusCode >= 400 {
            throw HttpError.clientError
          }
        } catch {
          print(error)
        }
      }

      task.resume()
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(value, forHTTPHeaderField: key)
      }

      // Set the request body to the string literal of the Dictionary
      if (method != "GET") {
        request.httpBody = try JSONEncoder().encode(body)
      } else {
        request.httpBody = nil
      }

      return request
    }
  }
}

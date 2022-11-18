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
  case clientError(String)
  case httpError(String)
  case internalServerError(String)
  case nilResponseError
  case unknownError(String)
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

  public func send(completion: @escaping (Result<T>) -> Void) -> Void {
    do {
      // Build the request object
      let request = try prepareRequest()
      print("BODY ", self.body)
      
      // Make the request via URLSession
      let task = URLSession.shared.dataTask(with: request) {
        (data, response, error) -> Void in

        do {
          // Handle errors
          if (error != nil) {
            return completion(Result(error: HttpError.unknownError(error!.localizedDescription)))
          }

          // Parse the response and return the properly typed data
          let httpResponse = response as? HTTPURLResponse

          if (httpResponse == nil) {
            return completion(Result(error: HttpError.nilResponseError))
          }

          // Process the response object
          if httpResponse?.statusCode == 200 {
            // Decode the response into the appropriate type
            let decoder = JSONDecoder()
            let typedData = try decoder.decode(T.self, from: data!)

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(value, forHTTPHeaderField: key)
      }

      // Set the request body to the string literal of the Dictionary
      if (method != "GET" && body != nil) {
        request.httpBody = try JSONEncoder().encode(body!)
        print("Updated request body:", String(data: request.httpBody!, encoding: .utf8)!)
      } else {
        request.httpBody = nil
      }

      return request
    }
  }
}

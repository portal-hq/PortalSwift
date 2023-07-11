//
//  HttpRequester.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A class for making HTTP requests.
public class HttpRequester {
  var baseUrl: String

  init(baseUrl: String) {
    self.baseUrl = baseUrl
  }

  func delete<T: Codable>(
    path: String,
    headers: [String: String],
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let url = String(format: "%@%@", baseUrl, path)
    let request = HttpRequest<T, [String: String]>(
      url: url,
      method: "DELETE",
      body: [:],
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send { (result: Result<T>) in
      completion(result)
    }
  }

  func get<T: Codable>(
    path: String,
    headers: [String: String],
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let url = String(format: "%@%@", baseUrl, path)
    let request = HttpRequest<T, [String: String]>(
      url: url,
      method: "GET",
      body: [:],
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send { (result: Result<T>) in
      completion(result)
    }
  }

  func post<T: Codable>(
    path: String,
    body: [String: Any],
    headers: [String: String],
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let request = HttpRequest<T, [String: Any]>(
      url: String(format: "%@%@", baseUrl, path),
      method: "POST",
      body: body,
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send { (result: Result<T>) in
      completion(result)
    }
  }

  func put<T: Codable>(
    path: String,
    body: [String: Any]?,
    headers: [String: String],
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let request = HttpRequest<T, [String: Any]?>(
      url: String(format: "%@%@", baseUrl, path),
      method: "PUT",
      body: body,
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send { (result: Result<T>) in
      completion(result)
    }
  }
}

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
    headers: Dictionary<String, String>,
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let url = String(format:"%@%@", self.baseUrl, path)
    let request = HttpRequest<T, [String: String]>(
      url: url,
      method: "DELETE",
      body: [:],
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send() { (result: Result<T>) -> Void in
      return completion(result)
    }
  }

  func get<T: Codable>(
    path: String,
    headers: Dictionary<String, String>,
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let url = String(format:"%@%@", self.baseUrl, path)
    let request = HttpRequest<T, [String: String]>(
      url: url,
      method: "GET",
      body: [:],
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send() { (result: Result<T>) -> Void in
      return completion(result)
    }
  }

  func post<T: Codable>(
    path: String,
    body: Dictionary<String, Any>,
    headers: Dictionary<String, String>,
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let request = HttpRequest<T, Dictionary<String, Any>>(
      url: String(format:"%@%@", self.baseUrl, path),
      method: "POST",
      body: body,
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send() { (result: Result<T>) -> Void in
      completion(result)
    }
  }
  
  func put<T: Codable>(
    path: String,
    body: Dictionary<String, Any>?,
    headers: Dictionary<String, String>,
    requestType: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws -> Void {
    // Create the request.
    let request = HttpRequest<T, Dictionary<String, Any>?>(
      url: String(format:"%@%@", self.baseUrl, path),
      method: "PUT",
      body: body,
      headers: headers,
      requestType: requestType
    )

    // Attempt to send the request.
    request.send() { (result: Result<T>) -> Void in
      completion(result)
    }
  }
}

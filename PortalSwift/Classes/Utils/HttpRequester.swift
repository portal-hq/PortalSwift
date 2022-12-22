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

  func get(
    path: String,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<Any>) -> Void
  ) throws -> Void {
    // Create the request.
    let url = String(format:"%@%@", self.baseUrl, path)
    let request = HttpRequest<Dictionary<String, Any>, [String: String]>(
      url: url,
      method: "GET",
      body: [:],
      headers: headers
    )

    // Attempt to send the request.
    request.send() { (result: Result<Any>) -> Void in
      return completion(result)
    }
  }

  func post(
    path: String,
    body: Dictionary<String, Any>,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<Any>) -> Void
  ) throws -> Void {
    // Create the request.
    let request = HttpRequest<Any, Dictionary<String, Any>>(
      url: String(format:"%@%@", self.baseUrl, path),
      method: "POST",
      body: body,
      headers: headers
    )

    // Attempt to send the request.
    request.send() { (result: Result<Any>) -> Void in
      completion(result)
    }
  }
}

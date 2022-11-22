//
//  HttpRequester.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public struct HttpRequester {
  var baseUrl: String

  init(baseUrl: String) {
    self.baseUrl = baseUrl
  }

  func handleResponse(
    data: Dictionary<String, AnyObject>,
    response: String?
  ) -> Void {

  }

  func get(
    path: String,
    headers: Dictionary<String, String>,
    completion: @escaping (Result<Any>) -> Void
  ) throws -> Void {
    // Build the HTTPRequest object
    let url = String(format:"%@%@", self.baseUrl, path)
    let request = HttpRequest<Dictionary<String, Any>, [String: String]>(
      url: url,
      method: "GET",
      body: [:],
      headers: headers
    )
    
    // Send the HTTP request
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
    // Build the HTTPRequest object
    var request = HttpRequest<Any, Dictionary<String, Any>>(
      url: String(format:"%@%@", self.baseUrl, path),
      method: "POST",
      body: body,
      headers: headers
    )

    // Send the HTTP request
    request.send() { (result: Result<Any>) -> Void in
      completion(result)
    }
  }
}

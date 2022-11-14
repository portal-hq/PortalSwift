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
  
  func get<T: Codable>(
    path: String,
    headers: Dictionary<String, String>,
    completion: @escaping (T) -> Void
  ) throws -> Void {
    // Build the HTTPRequest object
    let url = String(format:"%@%@", self.baseUrl, path)
    let request = HttpRequest<T, [String: String]>(
      url: url,
      method: "GET",
      body: [:],
      headers: headers
    )
    do {
      // Send the HTTP request
      try request.send() { (response: T) -> Void in
        completion(response)
      }
    }
  }
  
  func post<T: Codable, U: Codable>(
    path: String,
    body: U,
    headers: Dictionary<String, String>,
    completion: @escaping (T) -> Void
  ) throws -> Void {
    // Build the HTTPRequest object
    let request = HttpRequest<T, U>(
      url: String(format:"%@%@", self.baseUrl, path),
      method: "POST",
      body: body,
      headers: headers
    )
    
    do {
      // Send the HTTP request
      try request.send() { (response: T) -> Void in
        completion(response)
      }
    }
  }
}

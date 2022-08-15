//
//  HttpRequester.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/13/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

struct HttpRequester {
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
    completion: @escaping (_ response: T) -> T
  ) throws -> Void {
    // Build the HTTPRequest object
    let request = HttpRequest<T, [String: String]>(
      url: String(format:"%s%s", self.baseUrl, path),
      method: "GET",
      body: [:],
      headers: headers
    )
    do {
      // Send the HTTP request
      let _ = try request.send() { response in
        // Pass the result off to the completion closure
        let _ = completion(response)
      }
    }
  }
  
  func post<T: Codable, U: Codable>(
    path: String,
    body: U,
    headers: Dictionary<String, String>,
    completion: @escaping (_ response: T) -> T
  ) throws -> Void {
    // Build the HTTPRequest object
    let request = HttpRequest<T, U>(
      url: String(format:"%s%s", self.baseUrl, path),
      method: "POST",
      body: body,
      headers: headers
    )
    
    do {
      // Send the HTTP request
      let _ = try request.send() { response in
        // Pass the result off to the completion closure
        let _ = completion(response)
      }
    }
  }
}

//
//  HttpRequest.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/12/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

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
  
  public func send(completion: @escaping (_ response: T) -> Void) throws -> Void {
    do {
      // Build the request object
      let request = try prepareRequest()
      // Make the request via URLSession
      (URLSession.shared.dataTask(with: request) {
        (data, response, error) -> Void in
        // Handle errors
        if (error != nil) {
          // TODO: Figure out how to fail here
          return
        }
        
        // Parse the response and return the properly typed data
        if let httpResponse = response as? HTTPURLResponse {
          if httpResponse.statusCode == 200 {
            do {
              // Decode the response into the appropriate type
              let decoder = JSONDecoder()
              let typedData = try decoder.decode(T.self, from: data!)
              
              // Pass off to the completion closure
              completion(typedData)
            } catch {
              // TODO: Figure out how to fail here
              return
            }
          } else {
            // TODO: Figure out how to fail here
            return
          }
        }
      }).resume()
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
      
      print("Request Body: ")
      print(request.httpBody)
      
      return request
    }
  }
}

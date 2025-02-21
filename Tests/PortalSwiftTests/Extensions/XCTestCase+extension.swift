//
//  XCTestCase+extension.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/02/2025.
//

import XCTest

extension XCTestCase {
  func AssertJSONEQual(_ json1: String?, _ json2: String?) {
    guard
      let json1,
      let json2,
      let data1 = json1.data(using: .utf8),
      let data2 = json2.data(using: .utf8)
    else {
      XCTFail("Failed to convert JSON strings to Data")
      return
    }

    do {
      let jsonObject1 = try JSONSerialization.jsonObject(with: data1, options: [])
      let jsonObject2 = try JSONSerialization.jsonObject(with: data2, options: [])

      // Use XCTAssertEqual to compare the two JSON objects
      XCTAssertEqual(jsonObject1 as? NSObject, jsonObject2 as? NSObject)
    } catch {
      XCTFail("Failed to parse JSON: \(error)")
    }
  }
}

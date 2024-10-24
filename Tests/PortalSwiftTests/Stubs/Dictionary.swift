//
//  Dictionary.swift
//
//
//  Created by Ahmed Ragab on 04/09/2024.
//

import Foundation

typealias StringDictionary = [String: String]

extension StringDictionary where Key == String, Value == String {
  static func stub() -> [String: String] {
    return [
      "key1": "value1",
      "key2": "value2",
      "key3": "value3"
    ]
  }
}

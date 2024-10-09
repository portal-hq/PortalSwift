//
//  PortalKeyValueStoreSpy.swift
//
//
//  Created by Ahmed Ragab on 23/09/2024.
//

import Foundation
@testable import PortalSwift

class PortalKeyValueStoreSpy: PortalKeyValueStoreProtocol {
  var deleteCallsCount: Int = 0
  var deleteKeyParam: String? = nil
  var deleteReturnValue: Bool = true

  func delete(_ key: String) -> Bool {
    deleteCallsCount += 1
    deleteKeyParam = key
    return deleteReturnValue
  }

  var readCallsCount: Int = 0
  var readKeyParam: String? = nil
  var readReturnValue: String = ""

  func read(_ key: String) -> String {
    readCallsCount += 1
    readKeyParam = key
    return readReturnValue
  }

  var writeCallsCount: Int = 0
  var writeKeyParam: String? = nil
  var writeValueParam: String? = nil
  var writeReturnValue: Bool = true

  func write(_ key: String, value: String) -> Bool {
    writeCallsCount += 1
    writeKeyParam = key
    writeValueParam = value
    return writeReturnValue
  }
}

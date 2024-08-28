//
//  PortalKeyChainAccessSpy.swift
//
//
//  Created by Ahmed Ragab on 27/08/2024.
//

import Foundation
@testable import PortalSwift

class PortalKeyChainAccessSpy: PortalKeychainAccessProtocol {
  // Tracking variables for `addItem` function
  private(set) var addItemCallsCount = 0
  private(set) var addItemKeyParam: String?
  private(set) var addItemValue: String?

  func addItem(_ key: String, value: String) throws {
    addItemCallsCount += 1
    addItemKeyParam = key
    addItemValue = value
  }

  // Tracking variables for `deleteItem` function
  private(set) var deleteItemCallsCount = 0
  private(set) var deleteItemKeyParam: String?

  func deleteItem(_ key: String) throws {
    deleteItemCallsCount += 1
    deleteItemKeyParam = key
  }

  // Tracking variables for `getItem` function
  private(set) var getItemCallsCount = 0
  private(set) var getItemKeyParam: String?
  var getItemReturnValue: String = ""

  func getItem(_ key: String) throws -> String {
    getItemCallsCount += 1
    getItemKeyParam = key
    return getItemReturnValue
  }

  // Tracking variables for `updateItem` function
  var updateItemCallsCount = 0
  private(set) var updateItemKeyParam: String?
  private(set) var updateItemValueParam: String?

  func updateItem(_ key: String, value: String) throws {
    updateItemCallsCount += 1
    updateItemKeyParam = key
    updateItemValueParam = value
  }
}

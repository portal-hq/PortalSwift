//
//  PortalKeyChainAccessMock.swift
//
//
//  Created by Ahmed Ragab on 27/08/2024.
//

import Foundation
@testable import PortalSwift

class PortalKeyChainAccessMock: PortalKeychainAccessProtocol {
  func addItem(_: String, value _: String) throws {}

  func deleteItem(_: String) throws {}

  var getItemReturnValue: String = ""
  func getItem(_: String) throws -> String {
    return getItemReturnValue
  }

  func updateItem(_: String, value _: String) throws {}
}

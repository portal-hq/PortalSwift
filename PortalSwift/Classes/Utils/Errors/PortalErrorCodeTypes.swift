//
//  PortalErrorCodeTypes.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public enum PortalErrorCodeTypes {
  static var MpcErrors = Array(100 ... 199)
  static var NetworkErrors = Array(200 ... 299)
  static var GeneralErrors = Array(300 ... 399)
  static var EncryptDecryptErrors = Array(400 ... 499)
}

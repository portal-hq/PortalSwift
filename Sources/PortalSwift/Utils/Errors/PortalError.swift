//
//  PortalError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public struct PortalError: Codable {
  public var code: Int
  public var message: String
}

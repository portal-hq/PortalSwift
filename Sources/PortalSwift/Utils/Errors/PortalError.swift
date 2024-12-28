//
//  PortalError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public struct PortalError: Codable {
  @available(*, deprecated, message: "Use `id` instead.")
  public var code: Int?
  public var id: String?
  public var message: String?
}

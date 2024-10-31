//
//  Error+Extension.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 31/10/2024.
//

import Foundation

public extension LocalizedError {
  var errorDescription: String? {
    return "PortalSwift.\(String(describing: Self.self)).\(self)"
  }
}

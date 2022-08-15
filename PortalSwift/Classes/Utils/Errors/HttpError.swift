//
//  HttpError.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/12/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

struct HttpError: Error {
  var code: Int
  var message: String
  
  init(code: Int, message: String) {
    self.code = code
    self.message = message
  }
}

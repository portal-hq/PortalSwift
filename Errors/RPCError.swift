//
//  RPCError.swift
//  PortalSwift_Example
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

class RPCError: Error {
  var code: Int
  var data: ETHRequestPayload
  
  init(code: Int, data: ETHRequestPayload) {
    self.code = code
    self.data = data
  }
}

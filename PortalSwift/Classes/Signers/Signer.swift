//
//  Signer.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

struct Signature: Codable {
  var x: String
  var y: String
}

class Signer {
  func sign(payload: ETHRequestPayload, provider: PortalProvider) throws -> Signature? {
    fatalError("Subclasses need to implement the sign() method")
  }
  
  func getApproval() -> Void {}
}

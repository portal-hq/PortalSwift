//
//  MPCSigner.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

class MPCSigner: Signer {
  override func sign(
    payload: ETHRequestPayload,
    provider: PortalProvider,
    completion: @escaping (_ signature: Signature?) -> Void
  ) throws -> Void {
    // TODO: Do MPC Signing with the mpc.xcframework binary
    
    return
  }
}

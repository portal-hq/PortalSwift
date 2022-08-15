//
//  HttpSigner.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

class HttpSigner: Signer {
  var portal: HttpRequester
  
  init(portal: HttpRequester) {
    self.portal = portal
  }
  
  override func sign(payload: ETHRequestPayload, provider: PortalProvider) throws -> Signature? {
    do {
      let _ = try portal.post(
        path: "/api/clients/sign",
        body: payload,
        headers: [
          "Authorization": String(format: "Bearer %s", provider.getApiKey()),
        ]
      ) { (signature: Signature) in
        return signature
      }
    }
    
    return nil
  }
}

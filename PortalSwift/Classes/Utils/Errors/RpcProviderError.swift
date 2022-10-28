//
//  RpcProviderError.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/12/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

struct ProviderRpcErrorDefinition {
  var description: String
  var name: String
}

enum ProviderRpcErrorCodes: Int {
  case UserRejectedRequest = 4001
  case Unauthorized = 4100
  case UnsupportedMethod = 4200
  case Disconnected = 4900
  case ChainDisconnected = 4901
}

var providerErrors: Dictionary<ProviderRpcErrorCodes.RawValue, ProviderRpcErrorDefinition> = [
  4001: ProviderRpcErrorDefinition(
    description: "The user rejected the request.",
    name: "User Rejected Request"
  ),
  4100: ProviderRpcErrorDefinition(
    description:
      "The requested method and/or account has not been authorized by the user.",
    name: "Unauthorized"
  ),
  4200: ProviderRpcErrorDefinition(
    description: "The Provider does not support the requested method.",
    name: "Unsupported Method"
  ),
  4900: ProviderRpcErrorDefinition(
    description: "The Provider is disconnected from all chains.",
    name: "Disconnected"
  ),
  4901: ProviderRpcErrorDefinition(
    description: "The Provider is not connected to the requested chain.",
    name: "Chain Disconnected"
  ),
]

struct RpcProviderError: Error {
  var code: Int
  var definition: ProviderRpcErrorDefinition
  var data: Any? = []
  var message: String
  
  init(code: ProviderRpcErrorCodes.RawValue, data: Any? = []) {
    self.definition = providerErrors[code]!
    let message = String(
      format: "[Portal] RPC Error: %@ %@",
      code,
      String(format: "%@ - %@", self.definition.name, self.definition.description)
    )
    
    self.code = code
    self.data = data
    self.message = message
  }
}



enum PortalProviderErrorMessages: String {
    case AutoApproveDisabled = "[PortalProvider] Auto-approve is disabled. Cannot perform signing requests without an event handler for the 'portal_signingRequested' event."
    case SigningRequestRejected = "[PortalProvider] Request for signing method '${method}' could not be completed because it was not approved by the user."
    case WalletRequestRejected = "[PortalProvider] Request for wallet method '${method}' could not be completed because it was not approved by the user."
    
}

enum PortalProviderErrors: Error {
   case AutoApproveDisabled(String)
   case SigningRequestRejected(String)
   case WalletRequestRejected(String)
}

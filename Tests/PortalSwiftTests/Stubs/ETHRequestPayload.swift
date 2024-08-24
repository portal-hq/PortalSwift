//
//  ETHRequestPayload.swift
//
//
//  Created by Ahmed Ragab on 24/08/2024.
//

import Foundation
@testable import PortalSwift

extension ETHRequestPayload {
    static func stub(
        method: ETHRequestMethods.RawValue = "eth_accounts",
        params: [Any] = [""]
    ) -> Self {
        return ETHRequestPayload(method: method, params: params)
    }
}

//
//  File.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

public class MockPortalMpcSigner: PortalMpcSigner {
  override public func sign(
    _: String,
    withPayload _: PortalSignRequest,
    andRpcUrl _: String,
    usingBlockchain _: PortalBlockchain
  ) async throws -> String {
    return MockConstants.mockSignResult
  }
}

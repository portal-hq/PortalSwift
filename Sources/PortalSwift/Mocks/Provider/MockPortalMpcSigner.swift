//
//  MockPortalMpcSigner.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

public class MockPortalMpcSigner: PortalMpcSigner {
  override public func sign(
    _: String,
    withPayload: PortalSignRequest,
    andRpcUrl _: String,
    usingBlockchain _: PortalBlockchain,
    signatureApprovalMemo _: String?,
    sponsorGas _: Bool?
  ) async throws -> String {
    switch withPayload.method {
    case .eth_sendTransaction, .eth_sendRawTransaction:
      return MockConstants.mockTransactionHash
    default:
      return MockConstants.mockSignature
    }
  }
}

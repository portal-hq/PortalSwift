//
//  FundResponse.swift
//  Pods
//
//  Created by Ahmed Ragab on 07/02/2025.
//

import Foundation
@testable import PortalSwift

extension FundResponse {
  static func stub(
    data: FundResponseData? = .stub(),
    metadata: FundResponseMetadata = .stub(),
    error: FundResponseError? = nil
  ) -> FundResponse {
    return FundResponse(
      data: data,
      metadata: metadata,
      error: error
    )
  }
}

extension FundResponseData {
  static func stub(
    explorerUrl: String = "https://sepolia.etherscan.io/tx/0x13aebe28e9661959f73e06c48123d67d47e8e24a3833f626d2fcaa6ef640d0de",
    txHash: String = "0x13aebe28e9661959f73e06c48123d67d47e8e24a3833f626d2fcaa6ef640d0de"
  ) -> FundResponseData {
    return FundResponseData(
      explorerUrl: explorerUrl,
      txHash: txHash
    )
  }
}

extension FundResponseMetadata {
  static func stub(
    amount: String = "0.01",
    chainId: String = "eip155:11155111",
    clientId: String = "clientId",
    custodianId: String = "custodianId",
    environmentId: String = "environmentId",
    token: String = "ETH"
  ) -> FundResponseMetadata {
    return FundResponseMetadata(
      amount: amount,
      chainId: chainId,
      clientId: clientId,
      custodianId: custodianId,
      environmentId: environmentId,
      token: token
    )
  }
}

extension FundResponseError {
  static func stub(
    id: String = "id",
    message: String = "message"
  ) -> FundResponseError {
    return FundResponseError(
      id: id,
      message: message
    )
  }
}

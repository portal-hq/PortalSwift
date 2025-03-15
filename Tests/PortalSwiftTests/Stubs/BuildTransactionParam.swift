//
//  BuildTransactionParam.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 15/03/2025.
//

@testable import PortalSwift

extension BuildTransactionParam {
  static func stub() -> BuildTransactionParam {
    return BuildTransactionParam(
      to: "t0_address",
      token: "token",
      amount: "100"
    )
  }
}

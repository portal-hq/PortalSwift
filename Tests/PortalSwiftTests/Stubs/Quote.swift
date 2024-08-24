//
//  Quote.swift
//
//
//  Created by Ahmed Ragab on 22/08/2024.
//

import Foundation
@testable import PortalSwift

extension Quote {
  static func stub(
    allowanceTarget: String = "default_allowance_target",
    cost: Double = 0.0,
    transaction: ETHTransactionParam = .stub()
  ) -> Self {
    return Quote(
      allowanceTarget: allowanceTarget,
      cost: cost,
      transaction: transaction
    )
  }
}

extension ETHTransactionParam {
  static func stub(
    from: String = "default_from",
    to: String = "default_to"
  ) -> Self {
    return ETHTransactionParam(
      from: from,
      to: to
    )
  }
}

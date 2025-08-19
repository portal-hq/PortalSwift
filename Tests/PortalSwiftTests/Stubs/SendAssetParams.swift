//
//  SendAssetParams.swift
//  Pods
//
//  Created by Ahmed Ragab on 07/02/2025.
//

import Foundation
@testable import PortalSwift

extension SendAssetParams {
  static func stub(
    to: String = "0xabcdef123456789abcdef123456789abcdef123456",
    amount: String = "0.001",
    token: String = "ETH",
    signatureApprovalMemo: String? = nil
  ) -> SendAssetParams {
    return SendAssetParams(
      to: to,
      amount: amount,
      token: token,
      signatureApprovalMemo: signatureApprovalMemo
    )
  }
}

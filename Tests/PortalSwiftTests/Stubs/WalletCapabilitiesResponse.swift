//
//  WalletCapabilitiesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 11/11/2024.
//

@testable import PortalSwift

extension WalletCapabilitiesResponse {
  static func stub(
    walletCapabilities: [String: WalletCapabilitiesValue] = ["0x1": WalletCapabilitiesValue.stub()]
  ) -> Self {
    return walletCapabilities
  }
}

extension WalletCapabilitiesValue {
  static func stub(
    paymasterService: PaymasterService = .stub()
  ) -> Self {
    return WalletCapabilitiesValue(paymasterService: paymasterService)
  }
}

extension PaymasterService {
  static func stub() -> Self {
    return PaymasterService(supported: true)
  }
}

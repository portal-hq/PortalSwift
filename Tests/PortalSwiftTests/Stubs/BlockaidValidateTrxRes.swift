//
//  BlockaidValidateTrxRes.swift
//
//
//  Created by Ahmed Ragab on 05/09/2024.
//

@testable import AnyCodable
import Foundation
@testable import PortalSwift

extension BlockaidValidateTrxRes {
  static func stub(
    validation: BlockaidValidation? = .stub(),
    simulation: BlockaidSimulation? = .stub(),
    block: Int? = 123_456,
    chain: String = "ethereum"
  ) -> BlockaidValidateTrxRes {
    return BlockaidValidateTrxRes(
      validation: validation,
      simulation: simulation,
      block: block,
      chain: chain
    )
  }
}

extension BlockaidValidation {
  static func stub(
    classification: String? = "low_risk",
    description: String? = "Transaction is low risk.",
    features: [Feature] = [.stub()],
    reason: String? = "No issues detected.",
    resultType: String = "success",
    status: String = "completed"
  ) -> BlockaidValidation {
    return BlockaidValidation(
      classification: classification,
      description: description,
      features: features,
      reason: reason,
      resultType: resultType,
      status: status
    )
  }
}

extension BlockaidValidation.Feature {
  static func stub(
    type: String = "basic",
    featureId: String = "feature-123",
    description: String = "A basic feature.",
    address: String? = "0x123456789abcdef123456789abcdef123456789a"
  ) -> BlockaidValidation.Feature {
    return BlockaidValidation.Feature(
      type: type,
      featureId: featureId,
      description: description,
      address: address
    )
  }
}

extension BlockaidSimulation {
  static func stub(
    accountAddress: String? = "0xabcdef123456789abcdef123456789abcdef12345",
    accountSummary: [String: AnyCodable] = ["balance": AnyCodable(1000)],
    addressDetails: [String: AnyCodable] = ["eth_balance": AnyCodable("10 ETH")],
    assetsDiffs: [String: [BlockaidAssetDiff]] = ["ETH": [.stub()]],
    block: Int? = 123_456,
    chain: String? = "ethereum",
    exposures: [String: AnyCodable] = ["exposureType": AnyCodable("minimal")],
    status: String = "success",
    totalUsdDiff: [String: AnyCodable] = ["total": AnyCodable(100.0)],
    totalUsdExposure: [String: AnyCodable] = ["exposure": AnyCodable(50.0)]
  ) -> BlockaidSimulation {
    return BlockaidSimulation(
      accountAddress: accountAddress,
      accountSummary: accountSummary,
      addressDetails: addressDetails,
      assetsDiffs: assetsDiffs,
      block: block,
      chain: chain,
      exposures: exposures,
      status: status,
      totalUsdDiff: totalUsdDiff,
      totalUsdExposure: totalUsdExposure
    )
  }
}

extension BlockaidAssetDiff {
  static func stub(
    asset: [String: AnyCodable] = ["name": AnyCodable("ETH")],
    in: [[String: AnyCodable]] = [["value": AnyCodable("5 ETH")]],
    out: [[String: AnyCodable]] = [["value": AnyCodable("3 ETH")]]
  ) -> BlockaidAssetDiff {
    return BlockaidAssetDiff(
      asset: asset,
      in: `in`,
      out: out
    )
  }
}

extension AnyCodable {
  static func stub() -> AnyCodable {
    return AnyCodable("example")
  }
}

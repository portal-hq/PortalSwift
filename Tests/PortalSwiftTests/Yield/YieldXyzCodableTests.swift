//
//  YieldXyzCodableTests.swift
//  PortalSwiftTests
//

@testable import PortalSwift
import XCTest

final class YieldXyzCodableTests: XCTestCase {
  let decoder = JSONDecoder()

  func test_getYieldsResponse_decodesLendingYieldSource() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "items": [
            {
              "id": "ethereum-sepolia-link-aave-v3-lending",
              "network": "eip155:11155111",
              "inputTokens": [
                {
                  "symbol": "LINK",
                  "name": "LINK",
                  "decimals": 18,
                  "network": "eip155:11155111",
                  "address": "0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5",
                  "isPoints": false
                }
              ],
              "outputToken": {
                "symbol": "aEthLINK",
                "name": "Aave Ethereum LINK",
                "decimals": 18,
                "network": "eip155:11155111",
                "address": "0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24",
                "isPoints": false
              },
              "token": {
                "symbol": "LINK",
                "name": "LINK",
                "decimals": 18,
                "network": "eip155:11155111",
                "address": "0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5",
                "isPoints": false
              },
              "rewardRate": {
                "total": 6.478416940285867,
                "rateType": "APY",
                "components": [
                  {
                    "rate": 6.478416940285867,
                    "rateType": "APY",
                    "token": {
                      "symbol": "LINK",
                      "name": "LINK",
                      "decimals": 18,
                      "network": "eip155:11155111",
                      "address": "0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5",
                      "isPoints": false
                    },
                    "yieldSource": "lending",
                    "description": "Earn lending rewards by supplying LINK"
                  }
                ]
              },
              "status": { "enter": true, "exit": true },
              "metadata": {
                "name": "Aave v3 LINK Lending",
                "logoURI": "https://assets.stakek.it/tokens/link.svg",
                "description": "Lend your LINK with Aave v3",
                "documentation": "https://docs.yield.xyz/docs/aave-lending",
                "underMaintenance": false,
                "deprecated": false,
                "supportedStandards": []
              },
              "mechanics": {
                "type": "lending",
                "requiresValidatorSelection": false,
                "rewardSchedule": "block",
                "rewardClaiming": "auto",
                "gasFeeToken": {
                  "symbol": "ETH",
                  "name": "Ethereum",
                  "decimals": 18,
                  "network": "eip155:11155111",
                  "isPoints": false
                },
                "entryLimits": { "minimum": "0", "maximum": null },
                "supportsLedgerWalletApi": true,
                "arguments": {
                  "enter": { "fields": [] },
                  "exit": { "fields": [] }
                },
                "possibleFeeTakingMechanisms": {
                  "depositFee": true,
                  "managementFee": true,
                  "performanceFee": true,
                  "validatorRebates": false
                }
              },
              "providerId": "aave",
              "tags": ["lending"]
            }
          ],
          "limit": 10,
          "offset": 0,
          "total": 1
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(YieldXyzGetYieldsResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.items.count, 1)
    XCTAssertEqual(
      decoded.data?.rawResponse.items.first?.rewardRate.components.first?.yieldSource,
      .lending
    )
  }
}

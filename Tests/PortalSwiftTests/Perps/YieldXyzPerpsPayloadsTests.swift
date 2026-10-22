//
//  YieldXyzPerpsPayloadsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Ported from the React Native SDK's `yieldXyzPerps.payloads.test.ts`, so every SDK signs the same
/// bytes for the same payload.
final class YieldXyzPerpsPayloadsTests: XCTestCase {
  private let wallet = YieldXyzPerpsFixtures.wallet
  private let usdc = YieldXyzPerpsFixtures.arbitrumUsdc

  private func payload(_ json: String) -> AnyCodable {
    YieldXyzPerpsFixtures.decode(AnyCodable.self, json)
  }

  private func domainType(of result: Swift.Result<[String: Any], YieldXyzPerpsPayloadProblem>) throws -> [[String: String]] {
    let typedData = try result.get()
    let types = try XCTUnwrap(typedData["types"] as? [String: Any])
    return try XCTUnwrap(types["EIP712Domain"] as? [[String: String]])
  }

  /// The order typed data with `domain` replaced.
  private func orderTypedData(domain: String) -> AnyCodable {
    payload("""
    {"domain":\(domain),"types":{"Agent":[{"name":"source","type":"string"},{"name":"connectionId","type":"bytes32"}]},
      "primaryType":"Agent","message":{"source":"a","connectionId":"0x\(String(repeating: "c4", count: 32))"}}
    """)
  }

  // MARK: - prepareTypedData

  func test_prepareTypedData_addsEip712DomainInViemOrder() throws {
    let result = YieldXyzPerpsPayloads.prepareTypedData(YieldXyzPerpsFixtures.hyperliquidOrderTypedData())

    XCTAssertEqual(try domainType(of: result), [
      ["name": "name", "type": "string"],
      ["name": "version", "type": "string"],
      ["name": "chainId", "type": "uint256"],
      ["name": "verifyingContract", "type": "address"]
    ])
  }

  func test_prepareTypedData_leavesEveryOtherPartUnchanged() throws {
    let original = try XCTUnwrap(YieldXyzPerpsFixtures.hyperliquidOrderTypedData().value as? [String: Any])

    var prepared = try YieldXyzPerpsPayloads.prepareTypedData(YieldXyzPerpsFixtures.hyperliquidOrderTypedData()).get()
    var types = try XCTUnwrap(prepared["types"] as? [String: Any])
    types.removeValue(forKey: "EIP712Domain")
    prepared["types"] = types

    XCTAssertEqual(NSDictionary(dictionary: prepared), NSDictionary(dictionary: original))
  }

  func test_prepareTypedData_includesOnlyThePresentDomainFields_hyperliquidUserSignedDomain() throws {
    let result = YieldXyzPerpsPayloads.prepareTypedData(payload("""
    {"domain":{"name":"HyperliquidSignTransaction","version":"1","chainId":42161},
      "types":{"HyperliquidTransaction:ApproveAgent":[{"name":"hyperliquidChain","type":"string"},{"name":"agentAddress","type":"address"},{"name":"agentName","type":"string"},{"name":"nonce","type":"uint64"}]},
      "primaryType":"HyperliquidTransaction:ApproveAgent",
      "message":{"hyperliquidChain":"Mainnet","agentAddress":"\(wallet)","agentName":"portal","nonce":1756207800000}}
    """))

    XCTAssertEqual(try domainType(of: result), [
      ["name": "name", "type": "string"],
      ["name": "version", "type": "string"],
      ["name": "chainId", "type": "uint256"]
    ])
  }

  func test_prepareTypedData_ignoresAStringChainIdAndAnEmptyVerifyingContract_likeViem() throws {
    let result = YieldXyzPerpsPayloads.prepareTypedData(orderTypedData(domain: #"{"name":"Exchange","chainId":"1337","verifyingContract":""}"#))

    XCTAssertEqual(try domainType(of: result), [["name": "name", "type": "string"]])
  }

  func test_prepareTypedData_addsSaltWhenPresent() throws {
    let salt = "0x" + String(repeating: "11", count: 32)
    let result = YieldXyzPerpsPayloads.prepareTypedData(orderTypedData(domain: #"{"name":"Exchange","version":"1","chainId":1337,"salt":"\#(salt)"}"#))

    XCTAssertEqual(try domainType(of: result), [
      ["name": "name", "type": "string"],
      ["name": "version", "type": "string"],
      ["name": "chainId", "type": "uint256"],
      ["name": "salt", "type": "bytes32"]
    ])
  }

  func test_prepareTypedData_keepsADefinedEip712Domain() throws {
    let result = YieldXyzPerpsPayloads.prepareTypedData(payload("""
    {"domain":{"name":"Exchange","version":"1","chainId":1337},
      "types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"chainId","type":"uint256"}],"Agent":[{"name":"source","type":"string"}]},
      "primaryType":"Agent","message":{"source":"a"}}
    """))

    let domain = try XCTUnwrap(((result.get())["types"] as? [String: Any])?["EIP712Domain"] as? [[String: Any]])
    XCTAssertEqual(domain.count, 2)
    XCTAssertEqual(domain.last?["name"] as? String, "chainId")
  }

  func test_prepareTypedData_rejectsAJsonEncodedPayload() {
    let result = YieldXyzPerpsPayloads.prepareTypedData(AnyCodable(YieldXyzPerpsFixtures.hyperliquidOrderTypedDataJSON))

    XCTAssertEqual(result.failureDescription, "is not an EIP-712 typed data object")
  }

  func test_prepareTypedData_rejectsMalformedPayloads() {
    let cases: [(String, AnyCodable?, String)] = [
      ("a non-object", AnyCodable("0xdeadbeef"), "is not an EIP-712 typed data object"),
      ("null", AnyCodable(NSNull()), "is not an EIP-712 typed data object"),
      ("absent", nil, "is not an EIP-712 typed data object"),
      ("an array", payload("[\(YieldXyzPerpsFixtures.hyperliquidOrderTypedDataJSON)]"), "is not an EIP-712 typed data object"),
      ("no domain", payload(#"{"types":{"Agent":[]},"primaryType":"Agent","message":{}}"#), "is missing an EIP-712 \"domain\" object"),
      ("no types", payload(#"{"domain":{},"primaryType":"Agent","message":{}}"#), "is missing an EIP-712 \"types\" object"),
      ("no primaryType", payload(#"{"domain":{},"types":{"Agent":[]},"message":{}}"#), "is missing an EIP-712 \"primaryType\""),
      ("an empty primaryType", payload(#"{"domain":{},"types":{"Agent":[]},"primaryType":"","message":{}}"#), "is missing an EIP-712 \"primaryType\""),
      ("an undefined primaryType", payload(#"{"domain":{},"types":{"Agent":[]},"primaryType":"Order","message":{}}"#), "does not define its primary type \"Order\" in \"types\""),
      ("no message", payload(#"{"domain":{},"types":{"Agent":[]},"primaryType":"Agent"}"#), "is missing an EIP-712 \"message\" object")
    ]

    for (label, input, expected) in cases {
      XCTAssertEqual(YieldXyzPerpsPayloads.prepareTypedData(input).failureDescription, expected, label)
    }
  }

  func test_typedDataJSON_roundTripsThePreparedPayload() throws {
    let prepared = try YieldXyzPerpsPayloads.prepareTypedData(YieldXyzPerpsFixtures.hyperliquidOrderTypedData()).get()

    let json = try XCTUnwrap(YieldXyzPerpsPayloads.typedDataJSON(prepared))
    let reparsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)

    XCTAssertEqual(reparsed, NSDictionary(dictionary: prepared))
    XCTAssertEqual((reparsed["domain"] as? NSDictionary)?["chainId"] as? Int, 1337)
  }

  // MARK: - parseEvmTransactionRequest

  func test_parseEvm_narrowsTheJsonTransaction_droppingNonceFeesGasLimitAndChain() throws {
    let request = try YieldXyzPerpsPayloads.parseEvmTransactionRequest(
      AnyCodable(YieldXyzPerpsFixtures.fundingTransactionPayload()),
      defaultFrom: wallet
    ).get()

    XCTAssertEqual(request, YieldXyzPerpsEvmTransactionRequest(
      from: wallet,
      to: usdc,
      data: YieldXyzPerpsFixtures.fundingTransferData,
      value: "0x0"
    ))
  }

  func test_parseEvm_acceptsADecodedObject() throws {
    let request = try YieldXyzPerpsPayloads.parseEvmTransactionRequest(
      payload(#"{"to":"\#(usdc)","value":"1000000000000000001","gasLimit":56675}"#),
      defaultFrom: wallet
    ).get()

    XCTAssertEqual(request, YieldXyzPerpsEvmTransactionRequest(from: wallet, to: usdc, value: "1000000000000000001"))
  }

  /// The signer estimates the gas when it sends, so Yield.xyz's `gasLimit` is never read: not even an
  /// invalid one rejects the transaction.
  func test_parseEvm_ignoresTheGasLimit() throws {
    for gasLimit in [#""0x9a0a""#, "39434", #""1e18""#, "true"] {
      let request = try YieldXyzPerpsPayloads.parseEvmTransactionRequest(
        payload(#"{"to":"\#(usdc)","gasLimit":\#(gasLimit)}"#),
        defaultFrom: wallet
      ).get()

      XCTAssertEqual(request, YieldXyzPerpsEvmTransactionRequest(from: wallet, to: usdc), gasLimit)
    }
  }

  func test_parseEvm_keepsAFromThatDiffersFromTheTransactionAddress() throws {
    let other = "0x000000000000000000000000000000000000dEaD"

    let request = try YieldXyzPerpsPayloads.parseEvmTransactionRequest(payload(#"{"to":"\#(usdc)","from":"\#(other)"}"#), defaultFrom: wallet).get()

    XCTAssertEqual(request, YieldXyzPerpsEvmTransactionRequest(from: other, to: usdc))
  }

  func test_parseEvm_sendsAPayloadWithoutFromFromTheTransactionAddress() throws {
    let request = try YieldXyzPerpsPayloads.parseEvmTransactionRequest(payload(#"{"to":"\#(usdc)","from":null,"data":null}"#), defaultFrom: wallet).get()

    XCTAssertEqual(request, YieldXyzPerpsEvmTransactionRequest(from: wallet, to: usdc))
  }

  func test_parseEvm_rejectsMalformedPayloads() {
    let fundingObject = YieldXyzPerpsFixtures.fundingTransactionPayload()
    let cases: [(String, AnyCodable?)] = [
      ("absent", nil),
      ("null", AnyCodable(NSNull())),
      ("a serialized hex transaction", AnyCodable("0x02f8b1820a4b07808401312d00830186a094af88")),
      ("an empty string", AnyCodable("")),
      ("a number", AnyCodable(42)),
      ("an object without to", payload(#"{"data":"0x","value":"0x0"}"#)),
      ("a malformed JSON string", AnyCodable(#"{"to": "#)),
      ("a nested transaction", payload(#"{"transaction":\#(fundingObject)}"#)),
      ("a negative value", payload(#"{"to":"\#(usdc)","value":-1}"#)),
      ("a fractional value", payload(#"{"to":"\#(usdc)","value":1.5}"#)),
      ("an unsafe integer value", payload(#"{"to":"\#(usdc)","value":9007199254740993}"#)),
      ("a boolean value", payload(#"{"to":"\#(usdc)","value":true}"#)),
      ("odd-length data", payload(#"{"to":"\#(usdc)","data":"0x123"}"#)),
      ("a short to", payload(#"{"to":"0x1234"}"#))
    ]

    for (label, input) in cases {
      if case .success = YieldXyzPerpsPayloads.parseEvmTransactionRequest(input, defaultFrom: wallet) {
        XCTFail("Expected \(label) to be rejected.")
      }
    }
  }

  // MARK: - Quantities and params

  func test_canonicalQuantityHex() {
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("0"), "0x0")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("0x00"), "0x0")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("0x0186a0"), "0x186a0")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("0XDD63"), "0xdd63")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("56675"), "0xdd63")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("1000000000000000001"), "0xde0b6b3a7640001")
    XCTAssertEqual(YieldXyzPerpsPayloads.canonicalQuantityHex("0x000de0b6b3a7640001"), "0xde0b6b3a7640001")
    XCTAssertEqual(
      YieldXyzPerpsPayloads.canonicalQuantityHex("115792089237316195423570985008687907853269984665640564039457584007913129639935"),
      "0x" + String(repeating: "f", count: 64)
    )
  }

  func test_toSendTransactionParam_canonicalizesTheValue_andLeavesTheGasToTheSigner() {
    let param = YieldXyzPerpsPayloads.toSendTransactionParam(YieldXyzPerpsEvmTransactionRequest(
      from: wallet,
      to: usdc,
      data: "0x095ea7b3",
      value: "0"
    ))
    XCTAssertEqual(param.from, wallet)
    XCTAssertEqual(param.to, usdc)
    XCTAssertEqual(param.data, "0x095ea7b3")
    XCTAssertNil(param.gas)
    XCTAssertEqual(param.value, "0x0")
    XCTAssertNil(param.nonce)
    XCTAssertNil(param.maxFeePerGas)

    let bare = YieldXyzPerpsPayloads.toSendTransactionParam(YieldXyzPerpsEvmTransactionRequest(from: wallet, to: usdc))
    XCTAssertEqual(bare.value, "0x0")
    XCTAssertNil(bare.gas)
    XCTAssertNil(bare.data)
  }

  func test_isEvmChainId() {
    XCTAssertTrue(YieldXyzPerpsPayloads.isEvmChainId("eip155:42161"))
    XCTAssertFalse(YieldXyzPerpsPayloads.isEvmChainId("eip155:0"))
    XCTAssertFalse(YieldXyzPerpsPayloads.isEvmChainId("eip155:01"))
    XCTAssertFalse(YieldXyzPerpsPayloads.isEvmChainId("eip155:"))
    XCTAssertFalse(YieldXyzPerpsPayloads.isEvmChainId("hyperliquid"))
    XCTAssertFalse(YieldXyzPerpsPayloads.isEvmChainId("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"))
  }

  func test_signatureAndHashFormats() {
    XCTAssertTrue(YieldXyzPerpsPayloads.isSignature(YieldXyzPerpsFixtures.signature))
    XCTAssertFalse(YieldXyzPerpsPayloads.isSignature(String(YieldXyzPerpsFixtures.signature.dropFirst(2))))
    XCTAssertFalse(YieldXyzPerpsPayloads.isSignature("0x1234"))
    XCTAssertTrue(YieldXyzPerpsPayloads.isTransactionHash(YieldXyzPerpsFixtures.fundingTxHash))
    XCTAssertFalse(YieldXyzPerpsPayloads.isTransactionHash(YieldXyzPerpsFixtures.signature))
  }

  func test_idempotencyKey_isDerivedFromTheTransactionId() {
    XCTAssertEqual(
      YieldXyzPerps.idempotencyKey(forTransactionId: "550e8400-e29b-41d4-a716-446655440002"),
      "yieldxyz-perps-550e8400-e29b-41d4-a716-446655440002"
    )
    XCTAssertNil(YieldXyzPerps.idempotencyKey(forTransactionId: ""))
    XCTAssertNil(YieldXyzPerps.idempotencyKey(forTransactionId: "tx/1"))
    XCTAssertNil(YieldXyzPerps.idempotencyKey(forTransactionId: String(repeating: "a", count: 241)))
    XCTAssertNotNil(YieldXyzPerps.idempotencyKey(forTransactionId: String(repeating: "a", count: 240)))
  }
}

private extension Swift.Result where Failure == YieldXyzPerpsPayloadProblem {
  var failureDescription: String? {
    if case let .failure(problem) = self {
      return problem.description
    }
    return nil
  }
}

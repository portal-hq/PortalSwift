//
//  YieldXyzPerpsPayloads.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Validation and preparation of the EIP-712 payloads a Yield.xyz Perps transaction carries.
/// Ported from the React Native SDK (`perps/yieldxyz/payloads.ts`) so every SDK signs the same
/// bytes. Unsigned EVM transactions are parsed by `YieldXyzEvmTransactionParams`.
enum YieldXyzPerpsPayloads {
  // MARK: - EIP-712

  /// Validates an `EIP712_TYPED_DATA` payload and returns it ready for `eth_signTypedData_v4`:
  /// unchanged, except that `types.EIP712Domain` is added when missing. The payload must be an
  /// object: the Portal API cannot verify the signer of any other shape and rejects its submission.
  static func prepareTypedData(_ payload: AnyCodable?) -> Swift.Result<[String: Any], YieldXyzPayloadProblem> {
    guard let typedData = payload?.value as? [String: Any] else {
      return .failure(YieldXyzPayloadProblem(description: "is not an EIP-712 typed data object"))
    }
    guard let domain = typedData["domain"] as? [String: Any] else {
      return .failure(YieldXyzPayloadProblem(description: "is missing an EIP-712 \"domain\" object"))
    }
    guard let types = typedData["types"] as? [String: Any] else {
      return .failure(YieldXyzPayloadProblem(description: "is missing an EIP-712 \"types\" object"))
    }
    guard let primaryType = typedData["primaryType"] as? String, !primaryType.isEmpty else {
      return .failure(YieldXyzPayloadProblem(description: "is missing an EIP-712 \"primaryType\""))
    }
    guard types[primaryType] is [Any] else {
      return .failure(YieldXyzPayloadProblem(description: "does not define its primary type \"\(primaryType)\" in \"types\""))
    }
    guard typedData["message"] is [String: Any] else {
      return .failure(YieldXyzPayloadProblem(description: "is missing an EIP-712 \"message\" object"))
    }

    if types["EIP712Domain"] != nil {
      return .success(typedData)
    }

    var prepared = typedData
    var preparedTypes = types
    preparedTypes["EIP712Domain"] = deriveEip712DomainType(domain)
    prepared["types"] = preparedTypes
    return .success(prepared)
  }

  /// The `EIP712Domain` fields for `domain`, with the same presence rules as viem's
  /// `getTypesForEIP712Domain`. The Portal API verifies signatures with viem, which derives this
  /// entry when it is absent, while the MPC signer hashes with go-ethereum, which requires it, so it
  /// must be derived identically for both hashes to agree.
  static func deriveEip712DomainType(_ domain: [String: Any]) -> [[String: String]] {
    var fields: [[String: String]] = []
    if domain["name"] is String {
      fields.append(["name": "name", "type": "string"])
    }
    if isTruthy(domain["version"]) {
      fields.append(["name": "version", "type": "string"])
    }
    if isNumber(domain["chainId"]) {
      fields.append(["name": "chainId", "type": "uint256"])
    }
    if isTruthy(domain["verifyingContract"]) {
      fields.append(["name": "verifyingContract", "type": "address"])
    }
    if isTruthy(domain["salt"]) {
      fields.append(["name": "salt", "type": "bytes32"])
    }
    return fields
  }

  /// The JSON text of prepared typed data, or `nil` when it holds a value JSON cannot represent.
  static func typedDataJSON(_ typedData: [String: Any]) -> String? {
    guard JSONSerialization.isValidJSONObject(typedData),
          let data = try? JSONSerialization.data(withJSONObject: typedData, options: [.sortedKeys])
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// A 65-byte `0x` hex signature.
  static func isSignature(_ value: String) -> Bool {
    YieldXyzEvmTransactionParams.isPrefixedHex(value, length: 130)
  }

  // MARK: - Private

  /// JavaScript truthiness of a decoded JSON value.
  private static func isTruthy(_ value: Any?) -> Bool {
    if YieldXyzEvmTransactionParams.isAbsent(value) {
      return false
    }
    switch value {
    case let bool as Bool:
      return bool
    case let string as String:
      return !string.isEmpty
    case let int as Int:
      return int != 0
    case let uint as UInt:
      return uint != 0
    case let double as Double:
      return double != 0 && !double.isNaN
    default:
      return true
    }
  }

  private static func isNumber(_ value: Any?) -> Bool {
    guard let value, !(value is Bool) else {
      return false
    }
    return value is Int || value is UInt || value is Double || value is Int64 || value is UInt64
  }
}

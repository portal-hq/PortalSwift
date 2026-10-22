//
//  YieldXyzPerpsPayloads.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Why a `signablePayload` cannot be signed. `description` completes the sentence
/// "The signablePayload of transaction <id> ...".
struct YieldXyzPerpsPayloadProblem: Error, Equatable {
  let description: String
}

/// An unsigned EVM transaction narrowed to the fields the SDK sends; `value` is a decimal or `0x`
/// hex string.
struct YieldXyzPerpsEvmTransactionRequest: Equatable {
  let from: String
  let to: String
  var data: String?
  var value: String?
}

/// Validation and preparation of the payloads a Yield.xyz Perps transaction carries. Ported from
/// the React Native SDK (`perps/yieldxyz/payloads.ts`, `internal/evmTransactionParams.ts`) so every
/// SDK signs the same bytes.
enum YieldXyzPerpsPayloads {
  // MARK: - EIP-712

  /// Validates an `EIP712_TYPED_DATA` payload and returns it ready for `eth_signTypedData_v4`:
  /// unchanged, except that `types.EIP712Domain` is added when missing. The payload must be an
  /// object: the Portal API cannot verify the signer of any other shape and rejects its submission.
  static func prepareTypedData(_ payload: AnyCodable?) -> Swift.Result<[String: Any], YieldXyzPerpsPayloadProblem> {
    guard let typedData = payload?.value as? [String: Any] else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is not an EIP-712 typed data object"))
    }
    guard let domain = typedData["domain"] as? [String: Any] else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is missing an EIP-712 \"domain\" object"))
    }
    guard let types = typedData["types"] as? [String: Any] else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is missing an EIP-712 \"types\" object"))
    }
    guard let primaryType = typedData["primaryType"] as? String, !primaryType.isEmpty else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is missing an EIP-712 \"primaryType\""))
    }
    guard types[primaryType] is [Any] else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "does not define its primary type \"\(primaryType)\" in \"types\""))
    }
    guard typedData["message"] is [String: Any] else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is missing an EIP-712 \"message\" object"))
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

  // MARK: - EVM transactions

  /// Validates an unsigned EVM transaction (JSON-encoded, or the same object already decoded) and
  /// narrows it to `from`, `to`, `data` and `value`. Other keys are not forwarded: Portal's signer
  /// sets the nonce and fees, and estimates the gas limit when it sends, with headroom. Yield.xyz's
  /// `gasLimit` has none, and gas use on Arbitrum moves with the cost of posting data to Ethereum, so
  /// a forwarded limit can already be too low when the leg is sent. A transaction without `from`
  /// takes `defaultFrom`.
  static func parseEvmTransactionRequest(
    _ payload: AnyCodable?,
    defaultFrom: String?
  ) -> Swift.Result<YieldXyzPerpsEvmTransactionRequest, YieldXyzPerpsPayloadProblem> {
    guard let payload, !(payload.value is NSNull) else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is missing"))
    }
    guard let transaction = decodeJsonObject(payload.value) else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "is not a JSON transaction object"))
    }

    let declaredFrom = isAbsent(transaction["from"]) ? defaultFrom : transaction["from"]
    guard let from = declaredFrom as? String, isAddress(from) else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "has no valid \"from\" address"))
    }
    guard let to = transaction["to"] as? String, isAddress(to) else {
      return .failure(YieldXyzPerpsPayloadProblem(description: "has no valid \"to\" address"))
    }

    var request = YieldXyzPerpsEvmTransactionRequest(from: from, to: to)

    if !isAbsent(transaction["data"]) {
      guard let data = transaction["data"] as? String, isHexData(data) else {
        return .failure(YieldXyzPerpsPayloadProblem(description: "has a \"data\" field that is not hex bytes"))
      }
      request.data = data
    }

    switch readQuantity(transaction["value"]) {
    case .invalid:
      return .failure(YieldXyzPerpsPayloadProblem(description: "has an invalid \"value\""))
    case let .value(value):
      request.value = value
    case .absent:
      break
    }

    return .success(request)
  }

  /// `eth_sendTransaction` params as Portal's signer expects them: `value` in canonical hex and
  /// always present, and no `gas`, so the signer estimates it when it sends.
  static func toSendTransactionParam(_ request: YieldXyzPerpsEvmTransactionRequest) -> ETHTransactionParam {
    var param = ETHTransactionParam(from: request.from, to: request.to, value: canonicalQuantityHex(request.value ?? "0"))
    if let data = request.data {
      param.data = data
    }
    return param
  }

  /// Portal MPC strips leading zeros from some quantities before decoding them, so a zero-padded
  /// `0x00` reaches go-ethereum as `0x` and is rejected, and a decimal string is not decoded at all.
  /// Quantities are therefore always sent as canonical hex (`0x0`, `0xdbb0`). `quantity` must be a
  /// decimal or `0x` hex quantity.
  static func canonicalQuantityHex(_ quantity: String) -> String {
    let digits: String
    if quantity.hasPrefix("0x") || quantity.hasPrefix("0X") {
      digits = String(quantity.dropFirst(2)).lowercased()
    } else {
      digits = decimalToHex(quantity)
    }
    let trimmed = digits.drop(while: { $0 == "0" })
    return "0x" + (trimmed.isEmpty ? "0" : String(trimmed))
  }

  /// A CAIP-2 chain id in the `eip155` namespace with a canonical decimal reference.
  static func isEvmChainId(_ chainId: String) -> Bool {
    guard chainId.hasPrefix("eip155:") else {
      return false
    }
    let reference = chainId.dropFirst("eip155:".count)
    guard let first = reference.first, first != "0" else {
      return false
    }
    return reference.allSatisfy(isAsciiDigit)
  }

  /// A 65-byte `0x` hex signature.
  static func isSignature(_ value: String) -> Bool {
    isPrefixedHex(value, length: 130)
  }

  /// A 32-byte `0x` hex transaction hash.
  static func isTransactionHash(_ value: String) -> Bool {
    isPrefixedHex(value, length: 64)
  }

  // MARK: - Private

  private enum Quantity {
    case absent
    case value(String)
    case invalid
  }

  /// A decimal or hex quantity as a string; `.invalid` for anything else, including a negative,
  /// fractional or unsafe (above 2^53 - 1) number.
  private static func readQuantity(_ value: Any?) -> Quantity {
    if isAbsent(value) {
      return .absent
    }
    if value is Bool {
      return .invalid
    }
    if let int = value as? Int {
      return int >= 0 && int <= maxSafeInteger ? .value(String(int)) : .invalid
    }
    if let double = value as? Double {
      guard double >= 0, double <= Double(maxSafeInteger), double.rounded() == double else {
        return .invalid
      }
      return .value(String(Int64(double)))
    }
    if let string = value as? String, isDecimalQuantity(string) || isHexQuantity(string) {
      return .value(string)
    }
    return .invalid
  }

  private static let maxSafeInteger = 9_007_199_254_740_991

  private static func decodeJsonObject(_ value: Any) -> [String: Any]? {
    if let object = value as? [String: Any] {
      return object
    }
    guard let text = value as? String,
          let decoded = try? JSONDecoder().decode(AnyCodable.self, from: Data(text.utf8))
    else {
      return nil
    }
    return decoded.value as? [String: Any]
  }

  /// Absent, `null`, or an `Optional` holding nothing.
  private static func isAbsent(_ value: Any?) -> Bool {
    guard let value else {
      return true
    }
    if value is NSNull {
      return true
    }
    // An `Optional` boxed in `Any` (e.g. `AnyCodable(nil as String?)`) holding nothing.
    let mirror = Mirror(reflecting: value)
    return mirror.displayStyle == .optional && mirror.children.isEmpty
  }

  /// JavaScript truthiness of a decoded JSON value.
  private static func isTruthy(_ value: Any?) -> Bool {
    if isAbsent(value) {
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

  private static func isAddress(_ value: String) -> Bool {
    isPrefixedHex(value, length: 40)
  }

  private static func isHexData(_ value: String) -> Bool {
    guard value.hasPrefix("0x") else {
      return false
    }
    let digits = value.dropFirst(2)
    return digits.count % 2 == 0 && digits.allSatisfy(isHexDigit)
  }

  private static func isDecimalQuantity(_ value: String) -> Bool {
    !value.isEmpty && value.allSatisfy(isAsciiDigit)
  }

  private static func isHexQuantity(_ value: String) -> Bool {
    guard value.hasPrefix("0x") || value.hasPrefix("0X") else {
      return false
    }
    let digits = value.dropFirst(2)
    return !digits.isEmpty && digits.allSatisfy(isHexDigit)
  }

  private static func isPrefixedHex(_ value: String, length: Int) -> Bool {
    guard value.hasPrefix("0x") else {
      return false
    }
    let digits = value.dropFirst(2)
    return digits.count == length && digits.allSatisfy(isHexDigit)
  }

  private static func isAsciiDigit(_ character: Character) -> Bool {
    character.isASCII && character.isNumber
  }

  private static func isHexDigit(_ character: Character) -> Bool {
    character.isASCII && character.isHexDigit
  }

  private static let hexDigits = Array("0123456789abcdef")

  /// Converts a decimal string of any length to lowercase hex digits (no prefix), by repeated
  /// long division by 16. `decimal` must contain only ASCII digits.
  private static func decimalToHex(_ decimal: String) -> String {
    var digits = decimal.compactMap { $0.wholeNumberValue }
    var hex: [Character] = []
    while !digits.isEmpty {
      var remainder = 0
      var quotient: [Int] = []
      quotient.reserveCapacity(digits.count)
      for digit in digits {
        let accumulator = remainder * 10 + digit
        let next = accumulator / 16
        remainder = accumulator % 16
        if !quotient.isEmpty || next > 0 {
          quotient.append(next)
        }
      }
      hex.append(hexDigits[remainder])
      digits = quotient
    }
    return hex.isEmpty ? "0" : String(hex.reversed())
  }
}

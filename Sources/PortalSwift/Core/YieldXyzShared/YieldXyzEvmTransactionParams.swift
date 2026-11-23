//
//  YieldXyzEvmTransactionParams.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Why a `signablePayload` cannot be signed. `description` completes the sentence
/// "The signablePayload of transaction <id> ...".
struct YieldXyzPayloadProblem: Error, Equatable {
  let description: String
}

/// An unsigned EVM transaction narrowed to the fields the SDK sends; `value` is a decimal or `0x`
/// hex string.
struct YieldXyzEvmTransactionRequest: Equatable {
  let from: String
  let to: String
  var data: String?
  var value: String?
}

/// Validation and preparation of the unsigned EVM transactions Yield.xyz integrations return as
/// `signablePayload`. Ported from the React Native SDK (`internal/evmTransactionParams.ts`) so
/// every SDK signs the same bytes.
enum YieldXyzEvmTransactionParams {
  /// Validates an unsigned EVM transaction (JSON-encoded, or the same object already decoded) and
  /// narrows it to `from`, `to`, `data` and `value`. Other keys are not forwarded: Portal's signer
  /// sets the nonce and fees, and estimates the gas limit when it sends, with headroom. Yield.xyz's
  /// `gasLimit` has none, and gas use on chains such as Arbitrum moves with the cost of posting data
  /// to Ethereum, so a forwarded limit can already be too low when the transaction is sent. A
  /// transaction without `from` takes `defaultFrom`; with no `defaultFrom`, `from` is required.
  static func parse(
    _ payload: AnyCodable?,
    defaultFrom: String?
  ) -> Swift.Result<YieldXyzEvmTransactionRequest, YieldXyzPayloadProblem> {
    guard let payload, !(payload.value is NSNull) else {
      return .failure(YieldXyzPayloadProblem(description: "is missing"))
    }
    guard let transaction = decodeJsonObject(payload.value) else {
      return .failure(YieldXyzPayloadProblem(description: "is not a JSON transaction object"))
    }

    let declaredFrom = isAbsent(transaction["from"]) ? defaultFrom : transaction["from"]
    guard let from = declaredFrom as? String, isAddress(from) else {
      return .failure(YieldXyzPayloadProblem(description: "has no valid \"from\" address"))
    }
    guard let to = transaction["to"] as? String, isAddress(to) else {
      return .failure(YieldXyzPayloadProblem(description: "has no valid \"to\" address"))
    }

    var request = YieldXyzEvmTransactionRequest(from: from, to: to)

    if !isAbsent(transaction["data"]) {
      guard let data = transaction["data"] as? String, isHexData(data) else {
        return .failure(YieldXyzPayloadProblem(description: "has a \"data\" field that is not hex bytes"))
      }
      request.data = data
    }

    switch readQuantity(transaction["value"]) {
    case .invalid:
      return .failure(YieldXyzPayloadProblem(description: "has an invalid \"value\""))
    case let .value(value):
      request.value = value
    case .absent:
      break
    }

    return .success(request)
  }

  /// `eth_sendTransaction` params as Portal's signer expects them: `value` in canonical hex and
  /// always present, and no `gas`, so the signer estimates it when it sends.
  static func toSendTransactionParam(_ request: YieldXyzEvmTransactionRequest) -> ETHTransactionParam {
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

  /// A 32-byte `0x` hex transaction hash.
  static func isTransactionHash(_ value: String) -> Bool {
    isPrefixedHex(value, length: 64)
  }

  /// `0x` followed by exactly `length` hex digits.
  static func isPrefixedHex(_ value: String, length: Int) -> Bool {
    guard value.hasPrefix("0x") else {
      return false
    }
    let digits = value.dropFirst(2)
    return digits.count == length && digits.allSatisfy(isHexDigit)
  }

  /// Absent, `null`, or an `Optional` holding nothing.
  static func isAbsent(_ value: Any?) -> Bool {
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

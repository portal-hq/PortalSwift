//
//  PortalIdempotency.swift
//  PortalSwift
//
//  Idempotency keys for transaction broadcasts.
//

import Foundation

/// The HTTP header the MPC Enclave API reads an idempotency key from on `POST /v1/sign`.
public let PORTAL_IDEMPOTENCY_KEY_HEADER = "Idempotency-Key"

/// Generates an idempotency key: a UUID v4, lowercased to stay consistent with the other
/// Portal SDKs.
///
/// Generate one key per logical operation, store it with the pending operation, and reuse it
/// only to retry that identical request.
public func generateIdempotencyKey() -> String {
  UUID().uuidString.lowercased()
}

/// The error ids Portal returns when it refuses a request because of its idempotency key.
///
/// They arrive as `PortalMpcError.id`; `PortalMpcError.isIdempotencyRejection` checks for any of
/// them and `PortalMpcError.isIdempotencyKeyReused` for `keyReused`.
///
/// None of them returns the original transaction hash, and several mean Portal cannot confirm
/// whether the transaction reached the chain. Look the transaction up before sending it again under
/// a new key, or the retry can double-send.
///
/// Portal remembers a key for at least 24 hours after the request was last updated. After that,
/// the same key is accepted as a new request and none of these ids is returned, so check the chain
/// before retrying an operation older than 24 hours.
public enum PortalIdempotencyErrorId {
  /// A request with this key is still being processed. Retry later with the same key.
  public static let requestInProgress = "IDEMPOTENT_REQUEST_IN_PROGRESS"
  /// A request with this key already completed; the transaction was broadcast. The original
  /// transaction hash is not returned, so look the transaction up on-chain.
  public static let requestAlreadyCompleted = "IDEMPOTENT_REQUEST_ALREADY_COMPLETED"
  /// A request with this key failed, or its outcome is unknown. The earlier attempt may still
  /// have been broadcast, so check the chain or your transaction history before retrying the
  /// operation with a new key.
  public static let requestPreviouslyFailed = "IDEMPOTENT_REQUEST_PREVIOUSLY_FAILED"
  /// The request recorded for this key is in a state Portal did not expect. Portal cannot confirm
  /// the outcome; check the chain or your transaction history before retrying with a new key.
  public static let requestUnexpectedState = "IDEMPOTENT_REQUEST_UNEXPECTED_STATE"
  /// This key was already used for a request with a different payload. It does not tell you
  /// whether that earlier request is still in progress, completed or failed. A Solana `sendAsset`
  /// retry usually gets this id, because each build carries a new recent blockhash (see
  /// `SendAssetParams.idempotencyKey`).
  public static let keyReused = "IDEMPOTENCY_KEY_REUSED"
  /// Portal could not find the request recorded for this key. Portal cannot confirm the outcome;
  /// check the chain or your transaction history before retrying with a new key.
  public static let txMissing = "IDEMPOTENT_TX_MISSING"

  /// Every idempotency error id.
  public static let all: Set<String> = [
    requestInProgress,
    requestAlreadyCompleted,
    requestPreviouslyFailed,
    requestUnexpectedState,
    keyReused,
    txMissing
  ]
}

/// Thrown by the SDK, before anything is signed or sent, when an idempotency key cannot be used.
public enum PortalIdempotencyError: LocalizedError, Equatable {
  /// The key is empty, longer than 255 characters, or contains a character outside
  /// `A-Z a-z 0-9 . _ ~ -` (after trimming surrounding whitespace). The associated value names the
  /// rule that failed; it never contains the key.
  case invalidKey(String)
  /// A key was passed for a request whose broadcast Portal cannot protect: `eth_sendRawTransaction`,
  /// `sol_sendTransaction`, or `sendAsset` on a Bitcoin chain. The associated value names the
  /// target and says why; it never contains the key.
  case unsupportedTarget(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidKey(rule):
      return "PortalIdempotencyError.invalidKey - \(rule)"
    case let .unsupportedTarget(reason):
      return "PortalIdempotencyError.unsupportedTarget - \(reason)"
    }
  }
}

extension PortalIdempotencyError {
  /// The error for a key on `method`, a raw broadcast (`PortalRequestMethod.isRawBroadcast`).
  ///
  /// `sol_sendTransaction` is named by its SDK case, because its wire name `sendTransaction` reads
  /// like the protected `eth_sendTransaction`.
  static func unsupportedRawBroadcast(_ method: PortalRequestMethod) -> PortalIdempotencyError {
    let name = method == .sol_sendTransaction ? "sol_sendTransaction" : method.rawValue
    return .unsupportedTarget(
      "idempotencyKey is not supported for \(name); the signed transaction is broadcast by a plain RPC call that Portal cannot deduplicate"
    )
  }

  /// The error for a key on `sendAsset` on a Bitcoin chain, which raw-signs the transaction and
  /// broadcasts it through its own request.
  static let unsupportedBitcoinSendAsset = PortalIdempotencyError.unsupportedTarget(
    "idempotencyKey is not supported for Bitcoin sendAsset; the transaction is raw-signed and broadcast by the SDK"
  )
}

/// The longest key Portal accepts, in characters.
private let idempotencyKeyMaxLength = 255

/// RFC 3986 unreserved characters, spelled out: `.alphanumerics` would also admit non-ASCII
/// letters and digits, which Portal rejects.
private let idempotencyKeyAllowedCharacters = CharacterSet(
  charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-"
)

/// The code points JavaScript's `String.prototype.trim()` removes, which is how Portal trims a key
/// before validating it: tab, LF, vertical tab, form feed, CR, space, no-break space, U+1680,
/// U+2000–U+200A, the line and paragraph separators U+2028 and U+2029, U+202F, U+205F, U+3000
/// and the byte order mark U+FEFF.
///
/// Spelled out because Foundation's `.whitespacesAndNewlines` is a different set: it also removes
/// U+0085 and U+200B, and keeps U+FEFF. Anything not listed here stays in the key and fails the
/// character check.
private let idempotencyKeyTrimmedScalars: Set<UInt32> = [
  0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x00A0, 0x1680,
  0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A,
  0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF
]

/// `raw` without the leading and trailing `idempotencyKeyTrimmedScalars`, as JavaScript's `trim()`
/// would return it.
func trimIdempotencyKey(_ raw: String) -> String {
  let scalars = raw.unicodeScalars
  guard let first = scalars.firstIndex(where: { !idempotencyKeyTrimmedScalars.contains($0.value) }),
        let last = scalars.lastIndex(where: { !idempotencyKeyTrimmedScalars.contains($0.value) })
  else {
    return ""
  }
  return String(scalars[first ... last])
}

/// Trims surrounding whitespace from `raw` the way Portal does (JavaScript's `trim()`) and checks
/// the result against the rules Portal enforces: 1–255 characters, each one of
/// `A-Z a-z 0-9 . _ ~ -`.
///
/// - Returns: The trimmed key, which is the value the SDK sends.
/// - Throws: `PortalIdempotencyError.invalidKey` naming the rule that failed. The message never
///   contains the key.
func validateIdempotencyKey(_ raw: String) throws -> String {
  let key = trimIdempotencyKey(raw)
  guard !key.isEmpty else {
    throw PortalIdempotencyError.invalidKey("idempotencyKey must not be empty or whitespace-only")
  }
  // UTF-16 length, the same measure Portal applies; any key that passes the character check
  // below is ASCII, where every measure agrees.
  guard key.utf16.count <= idempotencyKeyMaxLength else {
    throw PortalIdempotencyError.invalidKey("idempotencyKey must be at most \(idempotencyKeyMaxLength) characters")
  }
  guard key.unicodeScalars.allSatisfy({ idempotencyKeyAllowedCharacters.contains($0) }) else {
    throw PortalIdempotencyError.invalidKey("idempotencyKey may only contain the characters A-Z, a-z, 0-9, '.', '_', '~' and '-'")
  }
  return key
}

extension PortalRequestMethod {
  /// `true` for the broadcast methods Portal protects with an idempotency key.
  var supportsIdempotencyKey: Bool {
    switch self {
    case .eth_sendTransaction, .sol_signAndSendTransaction, .sol_signAndConfirmTransaction:
      return true
    default:
      return false
    }
  }

  /// `true` for the methods that broadcast a transaction the caller already signed through a plain
  /// RPC call: `eth_sendRawTransaction` and `sol_sendTransaction` (Solana's `sendTransaction`). The
  /// SDK relays them to RPC without signing, so Portal cannot deduplicate them, and a key on one
  /// throws `PortalIdempotencyError.unsupportedTarget`.
  var isRawBroadcast: Bool {
    switch self {
    case .eth_sendRawTransaction, .sol_sendTransaction:
      return true
    default:
      return false
    }
  }
}

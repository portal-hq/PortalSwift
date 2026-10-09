import AnyCodable
import Foundation

public struct Signature: Codable {
  public var x: String
  public var y: String
}

public struct PortalSignRequest: Codable {
  public let method: PortalRequestMethod?
  public let params: String
  public var isRaw: Bool? = nil
}

public struct SignerResult: Codable {
  public var signature: String?
}

// SignerType enum to specify which signer to use
public enum SignerType {
  case binary // Uses the existing binary-based MPC signing
  case enclave // Uses the new HTTP endpoint-based signing
}

/// The signing seam `PortalProvider` drives.
///
/// Two overloads exist because the credential moved out of the signer: the SDK now resolves
/// the bearer token at the call site (after the user has approved the request, so a session
/// is never touched for a request that gets declined) and hands it to
/// `sign(_:withPayload:andRpcUrl:usingBlockchain:signatureApprovalMemo:sponsorGas:reqId:token:)`.
/// The token-less overload remains for conformers written against the earlier contract; the
/// extension default forwards the new overload to it so those conformers keep compiling.
///
/// A third overload adds the caller's idempotency key:
/// `sign(_:withPayload:andRpcUrl:usingBlockchain:signatureApprovalMemo:sponsorGas:reqId:idempotencyKey:token:)`
/// is the one `PortalProvider` calls. Its extension default forwards to the `token:` overload,
/// so existing conformers keep compiling; they drop the key (with a warning) until they
/// implement it.
public protocol PortalSignerProtocol {
  /// Signs `withPayload` authenticating with whatever credential the conformer holds itself.
  ///
  /// Kept for existing conformers. New conformers implement the `token:` overload and may omit
  /// this one: the extension default throws `PortalSignerError.tokenLessSignUnsupported`, and
  /// the SDK never calls it.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?
  ) async throws -> String

  /// Signs `withPayload` presenting `token` as the bearer credential to the MPC service.
  ///
  /// `token` is resolved by the caller immediately before this call and must be used for this
  /// call only — never stored — so a rotated or invalidated session takes effect on the very
  /// next signature.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?,
    token: String
  ) async throws -> String

  /// Signs `withPayload` presenting `token` as the bearer credential and attaching
  /// `idempotencyKey`, so Portal refuses to broadcast the same key twice.
  ///
  /// `PortalProvider` calls this overload. `idempotencyKey` is already trimmed and validated, and
  /// is non-`nil` only for `eth_sendTransaction`, `sol_signAndSendTransaction` and
  /// `sol_signAndConfirmTransaction`. The same rules as the `token:` overload apply to `token`.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?,
    idempotencyKey: String?,
    token: String
  ) async throws -> String
}

/// Raised by the default implementation of the token-less `sign` when a conformer written
/// against the current contract (the `token:` overload only) is driven through the legacy
/// overload, which the SDK itself never calls.
public enum PortalSignerError: LocalizedError, Equatable {
  case tokenLessSignUnsupported

  public var errorDescription: String? {
    "PortalSignerProtocol - This signer implements sign(...token:) only; the token-less overload is not supported."
  }
}

public extension PortalSignerProtocol {
  /// Default for conformers written against the current contract, so implementing the `token:`
  /// overload alone compiles. Existing conformers that implement this overload themselves are
  /// unaffected: a conformance's own method always wins over an extension default.
  func sign(
    _: String,
    withPayload _: PortalSignRequest,
    andRpcUrl _: String,
    usingBlockchain _: PortalBlockchain,
    signatureApprovalMemo _: String?,
    sponsorGas _: Bool?,
    reqId _: String?
  ) async throws -> String {
    throw PortalSignerError.tokenLessSignUnsupported
  }

  /// Source-compatibility default for conformers that predate the `token:` overload: they
  /// authenticate on their own, so the caller-resolved token is deliberately ignored and the
  /// call is forwarded to the token-less requirement they implemented.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?,
    token _: String
  ) async throws -> String {
    try await self.sign(
      chainId,
      withPayload: withPayload,
      andRpcUrl: andRpcUrl,
      usingBlockchain: usingBlockchain,
      signatureApprovalMemo: signatureApprovalMemo,
      sponsorGas: sponsorGas,
      reqId: reqId
    )
  }

  /// Source-compatibility default for conformers that predate the `idempotencyKey:` overload:
  /// forwards to the `token:` overload they implemented. The key cannot travel further, so a
  /// non-`nil` key is dropped with a warning (the key itself is never logged).
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?,
    idempotencyKey: String?,
    token: String
  ) async throws -> String {
    if idempotencyKey != nil {
      PortalLogger.shared.warn("PortalSignerProtocol - This signer does not accept idempotencyKey; the key was dropped. Implement sign(...idempotencyKey:token:) to forward it.")
    }
    return try await self.sign(
      chainId,
      withPayload: withPayload,
      andRpcUrl: andRpcUrl,
      usingBlockchain: usingBlockchain,
      signatureApprovalMemo: signatureApprovalMemo,
      sponsorGas: sponsorGas,
      reqId: reqId,
      token: token
    )
  }
}

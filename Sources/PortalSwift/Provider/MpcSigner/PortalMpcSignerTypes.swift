import AnyCodable

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
public protocol PortalSignerProtocol {
  /// Signs `withPayload` authenticating with whatever credential the conformer holds itself.
  ///
  /// Kept for existing conformers. New conformers should implement the `token:` overload and
  /// may leave this one throwing, since the SDK never calls it.
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
}

public extension PortalSignerProtocol {
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
}

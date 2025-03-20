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

// Protocol for signing implementation
public protocol PortalSignerProtocol {
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain
  ) async throws -> String
}

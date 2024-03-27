struct Signature: Codable {
  public var x: String
  public var y: String
}

public struct PortalSignRequest: Encodable {
  public let method: PortalRequestMethod
  public let params: [AnyEncodable]?
}

public struct SignerResult: Codable {
  public var signature: String?
  public var accounts: [String]?
}

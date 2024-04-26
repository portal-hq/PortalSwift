import AnyCodable

public struct Signature: Codable {
  public var x: String
  public var y: String
}

public struct PortalSignRequest: Codable {
  public let method: PortalRequestMethod
  public let params: [AnyCodable]?
}

public struct SignerResult: Codable {
  public var signature: String?
}

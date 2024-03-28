public struct PortalProviderRequestWithId: Encodable {
  public let id: String
  public let method: PortalRequestMethod
  public let params: [AnyEncodable]?
}

public struct PortalProviderRpcRequest: Encodable {
  public var id: Int
  public var jsonrpc: String
  public var method: PortalRequestMethod
  public var params: [AnyEncodable]?
}

public struct PortalProviderRpcBoolResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: Bool?
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderRpcResponse: Codable {
  public var jsonrpc: String
  public var id: Int?
  public var result: String?
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderRpcResponseError: Codable {
  public var code: Int
  public var message: String
}

public struct PortalProviderResult {
  public let result: Any
}

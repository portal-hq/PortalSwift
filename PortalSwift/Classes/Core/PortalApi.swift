//
//  PortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A client from the Portal API.
public struct Client: Codable {
  public var id: String
  public var address: String
  public var clientApiKey: String
  public var custodian: Custodian
}

/// A contract that belongs to a Dapp.
public struct Contract: Codable {
  public var id: String
  public var contractAddress: String
  public var clientUrl: String
  public var network: ContractNetwork
}

/// A custodian that belongs to a Client.
public struct Custodian: Codable {
  public var id: String
  public var name: String
}

/// A Dapp that has many Contracts.
public struct Dapp: Codable {
  public var id: String
  public var contracts: [Contract]
  public var image: DappImage
  public var name: String
}

/// A Dapp's profile image.
public struct DappImage: Codable {
  public var id: String
  public var data: String
  public var filename: String
}

/// A contract network. For example, chainId 5 is the Goerli network.
public struct ContractNetwork: Codable {
  public var id: String
  public var chainId: String
  public var name: String
}

/// The class to interface with Portal's REST API.
public class PortalApi {
  public var apiHost: String
  public var apiKey: String
  public var requests: HttpRequester

  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    mockRequests: Bool = false
  ) {
    self.apiKey = apiKey
    self.apiHost = String(format:"https://%@", apiHost)
    self.requests = mockRequests ? MockHttpRequester(baseUrl: self.apiHost) : HttpRequester(baseUrl: self.apiHost)
  }

  /// Retrieve the client by API key.
  /// - Parameter completion: The callback that contains the Client.
  /// - Returns: Void.
  public func getClient(completion: @escaping (Result<Client>) -> Void) throws -> Void {
    try requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Client>) -> Void in
      if (result.error != nil) {
        completion(Result<Client>(error: result.error!))
      } else if (result.data != nil) {
        completion(Result<Client>(data: result.data!))
      }
    }
  }

  /// Retrieve a list of enabled dapps for the client.
  /// - Parameter completion: The callback that contains the list of Dapps.
  /// - Returns: Void.
  public func getEnabledDapps(completion: @escaping (Result<[Dapp]>) -> Void) throws -> Void {
    try requests.get(
      path: "/api/v1/config/dapps",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Dapp]>) -> Void in
      completion(result)
    }
  }

  /// Retrieves a list of supported networks.
  /// - Parameter completion: The callback that contains the list of Networks.
  /// - Returns: Void.
  public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) throws -> Void {
    try requests.get(
      path: "/api/v1/config/networks",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[ContractNetwork]>) -> Void in
      completion(result)
    }
  }
}

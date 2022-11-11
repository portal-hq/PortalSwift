//
//  PortalApi.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public struct Client: Codable {
  public var id: String
  public var address: String
  public var clientApiKey: String
  public var custodian: Custodian
}

public struct Contract: Codable {
  public var id: String
  public var contractAddress: String
  public var clientUrl: String
  public var network: ContractNetwork
}

public struct Custodian: Codable {
  public var id: String
  public var name: String
}

public struct Dapp: Codable {
  public var id: String
  public var contracts: [Contract]
  public var image: DappImage
  public var name: String
}

public struct DappImage: Codable {
  public var id: String
  public var data: String
  public var filename: String
}

public struct ContractNetwork: Codable {
  public var id: String
  public var chainId: String
  public var name: String
}

public class PortalApi {
  public var apiHost: String
  public var apiKey: String
  public var requests: HttpRequester
  
  init(
    apiKey: String,
    apiHost: String = "https://api.portalhq.io"
  ) {
    self.apiKey = apiKey
    self.apiHost = String(format:"https://%@", apiHost)
    self.requests = HttpRequester(baseUrl: self.apiHost)
  }
  
  /// Fetch the Portal information for the current client
  ///
  /// ```
  ///   let client = try portal.api.getClient()
  /// ```
  ///
  /// - Returns: Void
  public func getClient() throws -> Client {
    let client: Client = try requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    )
    
    return client
  }
  
  /// Fetch a list of enabled dApps
  ///
  /// ```
  ///   let dapps = try portal.api.getEnabledDapps()
  /// ```
  ///
  /// - Returns: [Dapp]
  public func getEnabledDapps() throws -> [Dapp] {
    let dapps: [Dapp] = try requests.get(
      path: "/api/v1/config/dapps",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    )
    
    return dapps
  }
  
  /// Fetch a list of supported networks
  ///
  /// ```
  ///   let networks = try portal.api.getSupportedNetworks()
  /// ```
  ///
  /// - Returns: [ContractNetwork]
  public func getSupportedNetworks() throws -> [ContractNetwork] {
    let networks: [ContractNetwork] = try requests.get(
      path: "/api/v1/config/networks",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    )
    
    return networks
  }
}

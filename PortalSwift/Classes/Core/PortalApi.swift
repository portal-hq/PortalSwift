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
  ///   try portal.api.getClient() {
  ///     (response: Client) -> Void in {
  ///       // Do something with the resulting Client data
  ///     }
  ///   }
  ///
  /// - Returns: Void
  public func getClient(
    completion: @escaping (_ response: Client) -> Void
  ) throws -> Void {
    try requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    ) {
      (response: Client) -> Void in {
        completion(response)
      }
    }
  }
  
  /// Fetch a list of enabled dApps
  ///
  /// ```
  ///   try portal.api.getEnabledDapps() {
  ///     (response: [Dapp]) -> Void in {
  ///       // Do something with the resulting dApp list
  ///     }
  ///   }
  /// ```
  ///
  /// - Returns: Void
  public func getEnabledDapps(
    completion: @escaping (_ response: [Dapp]) -> Void
  ) throws -> Void {
    try requests.get(
      path: "/api/v1/config/dapps",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    ) {
      (_ response: [Dapp]) -> Void in {
        completion(response)
      }
    }
  }
  
  /// Fetch a list of supported networks
  ///
  /// ```
  /// try portal.api.getSupportedNetworks() {
  ///   (response: [ContractNetwork]) -> Void  in {
  ///     // Do something with the resulting network list
  ///   }
  /// }
  public func getSupportedNetworks(
    completion: @escaping (_ response: [ContractNetwork]) -> Void
  ) throws -> Void {
    try requests.get(
      path: "/api/v1/config/networks",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ]
    ) {
      (response: [ContractNetwork]) -> Void in {
        completion(response)
      }
    }
  }
}

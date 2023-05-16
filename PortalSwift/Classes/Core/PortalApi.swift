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

/// Represents an NFT smart contract.
public struct NFTContract: Codable {
  public var address: String
}

/// Represents an NFT owned by the client.
public struct NFT: Codable {
  public var contract: NFTContract
  public var id: TokenId
  public var balance: String
  public var title: String
  public var description: String
  public var tokenUri: TokenUri
  public var media: [Media]
  public var metadata: Metadata
  public var timeLastUpdated: String
  public var contractMetadata: ContractMetadata
}

/// Represents the id of an NFT.
public struct TokenId: Codable {
  public var tokenId: String
  public var tokenMetadata: TokenMetadata
}

/// Represents the metadata of an NFT's id.
public struct TokenMetadata: Codable {
  public var tokenType: String
}

/// Represents the URI of an NFT.
public struct TokenUri: Codable {
  public var gateway: String
  public var raw: String
}

/// Represents the media of an NFT.
public struct Media: Codable {
  public var gateway: String
  public var thumbnail: String
  public var raw: String
  public var format: String
  public var bytes: Int
}

/// Represents the metadata of an NFT.
public struct Metadata: Codable {
  public var name: String
  public var description: String
  public var image: String
  public var external_url: String?
}

/// Represents the contract metadata of an NFT.
public struct ContractMetadata: Codable {
  public var name: String
  public var symbol: String
  public var tokenType: String
  public var contractDeployer: String
  public var deployedBlockNumber: Int
  public var openSea: OpenSeaMetadata?
}

/// Represents the OpenSea metadata of an NFT.
public struct OpenSeaMetadata: Codable {
  public var collectionName: String
  public var safelistRequestStatus: String
  public var imageUrl: String?
  public var description: String
  public var externalUrl: String
  public var lastIngestedAt: String
  public var floorPrice: Float?
  public var twitterUsername: String?
  public var discordUrl: String?
}

/// The class to interface with Portal's REST API.
public class PortalApi {
  public var apiHost: String
  public var apiKey: String
  public var chainId: String
  public var requests: HttpRequester
  
  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - chainId: The chain ID of the EVM network.
  init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    chainId: Int = 1,
    mockRequests: Bool = false
  ) {
    self.apiKey = apiKey
    self.apiHost = String(format:"https://%@", apiHost)
    self.chainId = String(chainId)
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
  
  /// Retrieve a list of NFTs for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of NFTs.
  /// - Returns: Void.
  public func getNFTs(completion: @escaping (Result<[NFT]>) -> Void) throws -> Void {
    print("ChainId", chainId)
    try requests.get(
      path: "/api/v1/clients/me/nfts?chainId=\(chainId)",
      headers: [
        "Authorization": String(format: "Bearer %@", apiKey)
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[NFT]>) -> Void in
      completion(result)
    }
  }
}

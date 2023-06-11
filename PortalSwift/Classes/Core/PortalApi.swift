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
  public var metadata: NFTMetadata
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
public struct NFTMetadata: Codable {
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

/// Represents a blockchain transaction
public struct Transaction: Codable {
  /// Block number in which the transaction was included
  public var blockNum: String
  /// Unique identifier of the transaction
  public var uniqueId: String
  /// Hash of the transaction
  public var hash: String
  /// Address that initiated the transaction
  public var from: String
  /// Address that the transaction was sent to
  public var to: String
  /// Value transferred in the transaction
  public var value: Float
  /// Token Id of an ERC721 token, if applicable
  public var erc721TokenId: String?
  /// Metadata of an ERC1155 token, if applicable
  public var erc1155Metadata: String?
  /// Token Id, if applicable
  public var tokenId: String?
  /// Type of asset involved in the transaction (e.g., ETH)
  public var asset: String
  /// Category of the transaction (e.g., external)
  public var category: String
  /// Contract details related to the transaction
  public var rawContract: RawContract
}

/// Represents the contract details of a transaction
public struct RawContract: Codable {
  /// Value involved in the contract
  public var value: String
  /// Address of the contract, if applicable
  public var address: String?
  /// Decimal representation of the contract value
  public var decimal: String
}

/// A representation of a client's balance.
///
/// This struct is used to parse the JSON response from the "/api/v1/clients/me/balances" endpoint.
public struct Balance: Codable {
  /// The contract address of the token.
  public var contractAddress: String
  /// The balance of the token.
  public var balance: String
}


/// The class to interface with Portal's REST API.
public class PortalApi {
  public var address: String
  public var apiHost: String
  public var apiKey: String
  public var chainId: Int
  public var requests: HttpRequester
  
  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - chainId: The chain ID of the EVM network.
  init(
    address: String,
    apiKey: String,
    chainId: Int,
    apiHost: String = "api.portalhq.io",
    mockRequests: Bool = false
  ) {
    self.address = address
    self.apiKey = apiKey
    self.apiHost = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.chainId = chainId
    self.requests = mockRequests ? MockHttpRequester(baseUrl: self.apiHost) : HttpRequester(baseUrl: self.apiHost)
  }
  
  /// Retrieve the client by API key.
  /// - Parameter completion: The callback that contains the Client.
  /// - Returns: Void.
  public func getClient(completion: @escaping (Result<Client>) -> Void) throws -> Void {
    try requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": "Bearer \(apiKey)"
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
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Dapp]>) -> Void in
      completion(result)
    }
  }
  
  public func getQuote(
    _ swapsApiKey: String,
    _ args: QuoteArgs,
    completion: @escaping (Result<Quote>) -> Void
  ) throws -> Void {
    // Build the request body
    var body = args.toDictionary()
    // Append Portal-provided values
    body["address"] = address
    body["apiKey"] = swapsApiKey
    body["chainId"] = chainId
    
    // Make the request
    try requests.post(
      path: "/api/v1/swaps/sources",
      body: body,
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Quote>) -> Void in
      completion(result)
    }
  }
  
  public func getSources(swapsApiKey: String, completion: @escaping (Result<[String:String]>) -> Void) throws -> Void {
    try requests.post(
      path: "/api/v1/swaps/sources",
      body: [
        "apiKey": swapsApiKey,
        "chainId": chainId,
      ],
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[String:String]>) -> Void in
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
        "Authorization": "Bearer \(apiKey)"
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
    try requests.get(
      path: "/api/v1/clients/me/nfts?chainId=\(chainId)",
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[NFT]>) -> Void in
      completion(result)
    }
  }
  
  /// Retrieve a list of Transactions for the client.
  /// - Parameters:
  ///   - limit: (Optional) The maximum number of transactions to return.
  ///   - offset: (Optional) The number of transactions to skip before starting to return.
  ///   - completion: The callback that contains the list of Transactions.
  /// - Returns: Void.
  public func getTransactions(
    limit: Int? = nil,
    offset: Int? = nil,
    completion: @escaping (Result<[Transaction]>) -> Void
  ) throws -> Void {
    var path = "/api/v1/clients/me/transactions?chainId=\(chainId)"

    // Append limit and offset parameters if provided
    if let limit = limit {
        path += "&limit=\(limit)"
    }
    if let offset = offset {
        path += "&offset=\(offset)"
    }

    try requests.get(
      path: path,
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Transaction]>) -> Void in
      completion(result)
    }
  }
  
  /// Retrieve a list of Balances for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of Balances.
  /// - Returns: Void.
  public func getBalances(
    completion: @escaping (Result<[Balance]>) -> Void
  ) throws -> Void {
    try requests.get(
      path: "/api/v1/clients/me/balances?chainId=\(chainId)",
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Balance]>) -> Void in
      completion(result)
    }
  }
  
  /// Updates the client's wallet state to be stored on the client.
  /// - Parameters:
  ///   - recoverSigning: Optional boolean indicating whether it's from recover signing. If not nil, it's included as a query parameter in the URL.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func storedClientSigningShare(
    recoverSigning: Bool? = nil,
    completion: @escaping (Result<String>) -> Void
  ) throws -> Void {
    var path = "/api/v1/clients/me/wallet/stored-on-client"
    
    if let recoverSigning = recoverSigning {
      path += "?fromRecoverSigning=\(recoverSigning)"
    }
    
    try requests.put(
      path: path,
      body: [:],
      headers: [
        "Authorization": "Bearer \(apiKey)"
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) -> Void in
      completion(result)
    }
  }
  
  /// Updates the client's wallet backup state to have successfully stored the client backup share with the custodian.
  /// - Parameters:
  ///   - success: Boolean indicating whether the storage operation failed.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func storedClientBackupShare(
    success: Bool,
    completion: @escaping (Result<String>) -> Void
  ) throws -> Void {
    try requests.put(
        path: "/api/v1/clients/me/wallet/stored-client-backup-share",
        body: ["success": success],
        headers: [
          "Authorization": "Bearer \(apiKey)"
        ],
        requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) -> Void in
      completion(result)
    }
  }
}

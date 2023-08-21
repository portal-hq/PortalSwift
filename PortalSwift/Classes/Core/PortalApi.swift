//
//  PortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The class to interface with Portal's REST API.
public class PortalApi {
  private var apiKey: String
  private var provider: PortalProvider
  private var requests: HttpRequester

  private var address: String? {
    return self.provider.address
  }

  private var chainId: Int {
    return self.provider.chainId
  }

  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - provider: The PortalProvider instance to use for stateful Provider info (chainId, address)
  init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    provider: PortalProvider,
    mockRequests: Bool = false
  ) {
    self.apiKey = apiKey
    self.provider = provider

    let baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = mockRequests ? MockHttpRequester(baseUrl: baseUrl) : HttpRequester(baseUrl: baseUrl)
  }

  /// Retrieve the client by API key.
  /// - Parameter completion: The callback that contains the Client.
  /// - Returns: Void.
  public func getClient(completion: @escaping (Result<Client>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Client>) in
      if result.error != nil {
        completion(Result<Client>(error: result.error!))
      } else if result.data != nil {
        completion(Result<Client>(data: result.data!))
      }
    }
  }

  /// Retrieve a list of enabled dapps for the client.
  /// - Parameter completion: The callback that contains the list of Dapps.
  /// - Returns: Void.
  public func getEnabledDapps(completion: @escaping (Result<[Dapp]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/config/dapps",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Dapp]>) in
      completion(result)
    }
  }

  public func getQuote(
    _ swapsApiKey: String,
    _ args: QuoteArgs,
    completion: @escaping (Result<Quote>) -> Void
  ) throws {
    // Build the request body
    var body = args.toDictionary()
    // Append Portal-provided values
    body["address"] = self.address
    body["apiKey"] = swapsApiKey
    body["chainId"] = self.chainId

    // Make the request
    try self.requests.post(
      path: "/api/v1/swaps/sources",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Quote>) in
      completion(result)
    }
  }

  public func getSources(swapsApiKey: String, completion: @escaping (Result<[String: String]>) -> Void) throws {
    try self.requests.post(
      path: "/api/v1/swaps/sources",
      body: [
        "apiKey": swapsApiKey,
        "chainId": self.chainId,
      ],
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[String: String]>) in
      completion(result)
    }
  }

  /// Retrieves a list of supported networks.
  /// - Parameter completion: The callback that contains the list of Networks.
  /// - Returns: Void.
  public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/config/networks",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[ContractNetwork]>) in
      completion(result)
    }
  }

  /// Retrieve a list of NFTs for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of NFTs.
  /// - Returns: Void.
  public func getNFTs(completion: @escaping (Result<[NFT]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/nfts?chainId=\(self.chainId)",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[NFT]>) in
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
  ) throws {
    var path = "/api/v1/clients/me/transactions?chainId=\(chainId)"

    // Append limit and offset parameters if provided
    if let limit = limit {
      path += "&limit=\(limit)"
    }
    if let offset = offset {
      path += "&offset=\(offset)"
    }

    try self.requests.get(
      path: path,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Transaction]>) in
      completion(result)
    }
  }

  /// Retrieve a list of Balances for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of Balances.
  /// - Returns: Void.
  public func getBalances(
    completion: @escaping (Result<[Balance]>) -> Void
  ) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/balances?chainId=\(self.chainId)",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Balance]>) in
      completion(result)
    }
  }

  /// Simulates a transaction for the client.
  /// - Parameters:
  ///   - to: The recipient address.
  ///   - value: (Optional) The transacton "value" parameter.
  ///   - data: (Optional) The transacton "data" parameter.
  ///   - maxFeePerGas: (Optional) The transacton "maxFeePerGas" parameter.
  ///   - maxPriorityFeePerGas: (Optional) The transacton "maxPriorityFeePerGas" parameter.
  ///   - gas: (Optional) The transacton "gas" parameter.
  ///   - gasPrice: (Optional) The transacton "gasPrice" parameter.
  ///   - completion: The callback that contains transaction simulation response.
  /// - Returns: Void.
  public func simulateTransaction(
    to: String,
    value: String? = nil,
    data: String? = nil,
    maxFeePerGas: String? = nil,
    maxPriorityFeePerGas: String? = nil,
    gas: String? = nil,
    gasPrice: String? = nil,
    completion: @escaping (Result<SimulatedTransaction>) -> Void
  ) throws {
    var requestBody: [String: String] = ["to": to]

    if let value = value { requestBody["value"] = value }
    if let data = data { requestBody["data"] = data }
    if let maxFeePerGas = maxFeePerGas { requestBody["maxFeePerGas"] = maxFeePerGas }
    if let maxPriorityFeePerGas = maxPriorityFeePerGas { requestBody["maxPriorityFeePerGas"] = maxPriorityFeePerGas }
    if let gas = gas { requestBody["gas"] = gas }
    if let gasPrice = gasPrice { requestBody["gasPrice"] = gasPrice }

    try self.requests.post(
      path: "/api/v1/clients/me/simulate-transaction?chainId=\(self.chainId)",
      body: requestBody,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<SimulatedTransaction>) in
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
  ) throws {
    var path = "/api/v1/clients/me/wallet/stored-on-client"

    if let recoverSigning = recoverSigning {
      path += "?fromRecoverSigning=\(recoverSigning)"
    }

    try self.requests.put(
      path: path,
      body: [:],
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)
    }
  }

  /// Updates the client's wallet backup state to have successfully stored the client backup share key in the client's storage (e.g. gdrive, icloud, etc).
  /// - Parameters:
  ///   - backupMethod: One of: "ICLOUD", "GDRIVE", or "CUSTOM".
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func storedClientBackupShareKey(
    backupMethod: String,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    try self.requests.put(
      path: "/api/v1/clients/me/wallet/stored-client-backup-share-key",
      body: ["backupMethod": backupMethod],
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
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
  ) throws {
    try self.requests.put(
      path: "/api/v1/clients/me/wallet/stored-client-backup-share",
      body: ["success": success],
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)
    }
  }
}

/**********************************
 * Supporting Structs
 **********************************/

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

public struct SimulatedTransactionChange: Codable {
  public var amount: String? = nil
  public var assetType: String? = nil
  public var changeType: String? = nil
  public var contractAddress: String? = nil
  public var decimals: String? = nil
  public var from: String? = nil
  public var name: String? = nil
  public var rawAmount: String? = nil
  public var symbol: String? = nil
  public var to: String? = nil
  public var tokenId: String? = nil
}

public struct SimulatedTransactionError: Codable {
  public var message: String
}

public struct SimulatedTransaction: Codable {
  public var changes: [SimulatedTransactionChange]
  public var gasUsed: String? = nil
  public var error: SimulatedTransactionError
  public var requestError: SimulatedTransactionError
}

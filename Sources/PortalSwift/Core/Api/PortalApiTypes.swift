import AnyCodable

// There's a weird bug with Swift decoding preventing this more convenient version from working.
// Will need to research more and try to bring this in.
// public typealias ClientResponseMetadataNamespaces = [PortalNamespace: ClientResponseNamespaceMetadataItem]

public struct ClientCipherTextResponse: Codable {
  public let cipherText: String
}

public struct ClientResponse: Codable, Equatable {
  public let id: String
  public let custodian: ClientResponseCustodian
  public let createdAt: String
  public let environment: ClientResponseEnvironment?
  public let ejectedAt: String?
  public let isAccountAbstracted: Bool
  public let metadata: ClientResponseMetadata
  public let wallets: [ClientResponseWallet]

  public static func == (lhs: ClientResponse, rhs: ClientResponse) -> Bool {
    lhs.id == rhs.id && lhs.custodian.id == rhs.custodian.id && lhs.createdAt == rhs.createdAt && lhs.environment?.id == rhs.environment?.id && lhs.ejectedAt == rhs.ejectedAt && lhs.isAccountAbstracted == rhs.isAccountAbstracted && lhs.metadata.namespaces.eip155?.address == rhs.metadata.namespaces.eip155?.address && lhs.metadata.namespaces.solana?.address == rhs.metadata.namespaces.solana?.address && lhs.wallets.elementsEqual(rhs.wallets, by: { $0.backupSharePairs.elementsEqual($1.backupSharePairs, by: { $0.backupMethod == $1.backupMethod }) })
  }
}

public struct ClientResponseBackupSharePair: Codable, Equatable {
  public let backupMethod: BackupMethods
  public let createdAt: String
  public let id: String
  public let status: PortalSharePairStatus
}

public struct ClientResponseCustodian: Codable, Equatable {
  public let id: String
  public let name: String
}

public struct ClientResponseEnvironment: Codable, Equatable {
  public let id: String
  public let name: String
  public let backupWithPortalEnabled: Bool?
}

public struct ClientResponseMetadata: Codable, Equatable {
  public let namespaces: ClientResponseMetadataNamespaces
}

public struct ClientResponseMetadataNamespaces: Codable, Equatable {
  public let eip155: ClientResponseNamespaceMetadataItem?
  public let solana: ClientResponseNamespaceMetadataItem?
}

public struct ClientResponseNamespaceMetadataItem: Codable, Equatable {
  public let address: String
  public let curve: PortalCurve
}

public struct ClientResponseSharePair: Codable, Equatable {
  public let id: String
  public let createdAt: String
  public let status: PortalSharePairStatus
}

public struct ClientResponseWallet: Codable, Equatable {
  public let id: String
  public let createdAt: String

  public let backupSharePairs: [ClientResponseBackupSharePair]
  public let curve: PortalCurve
  public let ejectableUntil: String?
  public let publicKey: String
  public let signingSharePairs: [ClientResponseSharePair]
}

public struct FetchedBalance: Codable, Equatable {
  /// The contract address of the token.
  public var contractAddress: String
  /// The balance of the token.
  public var balance: String
  public var name: String?
  public var symbol: String?
}

public struct FetchedNFT: Codable, Equatable {
  public var contract: FetchedNFTContract
  public var id: FetchedNFTTokenId
  public var balance: String
  public var title: String
  public var description: String
  public var tokenUri: FetchedNFTTokenUri
  public var media: [FetchedNFTMedia]
  public var metadata: FetchedNFTMetadata
  public var timeLastUpdated: String
  public var contractMetadata: FetchedNFTContractMetadata
}

public struct FetchedNFTContract: Codable, Equatable {
  public var address: String
}

public struct FetchedNFTContractMetadata: Codable, Equatable {
  public var name: String
  public var symbol: String
  public var tokenType: String
  public var contractDeployer: String
  public var deployedBlockNumber: Int
  public var openSea: FetchedNFTContractOpenSeaMetadata?
}

public struct FetchedNFTContractOpenSeaMetadata: Codable, Equatable {
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

public struct FetchedNFTTokenId: Codable, Equatable {
  public var tokenId: String
  public var tokenMetadata: FetchedNFTTokenMetadata
}

/// Represents the metadata of an NFT's id.
public struct FetchedNFTTokenMetadata: Codable, Equatable {
  public var tokenType: String
}

/// Represents the URI of an NFT.
public struct FetchedNFTTokenUri: Codable, Equatable {
  public var gateway: String
  public var raw: String
}

/// Represents the media of an NFT.
public struct FetchedNFTMedia: Codable, Equatable {
  public var gateway: String
  public var thumbnail: String
  public var raw: String
  public var format: String
  public var bytes: Int
}

/// Represents the metadata of an NFT.
public struct FetchedNFTMetadata: Codable, Equatable {
  public var name: String
  public var description: String
  public var image: String
  public var external_url: String?
}

public struct FetchedSharePair: Codable, Equatable {
  public let id: String
  public let createdAt: String
  public let status: PortalSharePairStatus
}

public struct FetchedTransaction: Codable, Equatable {
  /// Represents metadata associated with a Transaction
  public struct FetchedTransactionMetadata: Codable, Equatable {
    /// Timestamp of the block in which the transaction was included (in ISO format)
    public var blockTimestamp: String
  }

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
  public var rawContract: FetchedTransactionRawContract
  /// Metadata associated with the transaction
  public var metadata: FetchedTransactionMetadata
  /// ID of the chain associated with the transaction
  public var chainId: Int
}

public struct FetchedTransactionRawContract: Codable, Equatable {
  /// Value involved in the contract
  public var value: String
  /// Address of the contract, if applicable
  public var address: String?
  /// Decimal representation of the contract value
  public var decimal: String
}

public struct PrepareEjectResponse: Codable {
  public let share: String
}

public struct ShareStatusUpdateRequest: Codable, Equatable {
  public let backupSharePairIds: [String]?
  public let signingSharePairIds: [String]?
  public let status: SharePairUpdateStatus
}

public struct ShareStatusUpdateResponse: Codable, Equatable {}

/*******************************
 * Deprecated functions
 */

/// A client from the Portal API.
public struct Client: Codable {
  public var id: String
  public var address: String
  public var custodian: Custodian
  public var signingStatus: String? = nil
  public var backupStatus: String? = nil
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

/// A contract network. For example, chainId 11155111 is the Sepolia network.
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
  /// Represents metadata associated with a Transaction
  public struct Metadata: Codable {
    /// Timestamp of the block in which the transaction was included (in ISO format)
    public var blockTimestamp: String
  }

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
  /// Metadata associated with the transaction
  public var metadata: Metadata
  /// ID of the chain associated with the transaction
  public var chainId: Int
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
  public var amount: String?
  public var assetType: String?
  public var changeType: String?
  public var contractAddress: String?
  public var decimals: Int?
  public var from: String?
  public var name: String?
  public var rawAmount: String?
  public var symbol: String?
  public var to: String?
  public var tokenId: Int?
}

public struct SimulatedTransactionError: Codable {
  public var message: String
}

public struct SimulateTransactionParam: Codable {
  public var to: String
  public var value: String?
  public var data: String?
  public var maxFeePerGas: String?
  public var maxPriorityFeePerGas: String?
  public var gas: String?
  public var gasPrice: String?

  public init(
    to: String,
    value: String? = nil,
    data: String? = nil,
    maxFeePerGas: String? = nil,
    maxPriorityFeePerGas: String? = nil,
    gas: String? = nil,
    gasPrice: String? = nil
  ) {
    self.to = to
    self.value = value
    self.data = data
    self.maxFeePerGas = maxFeePerGas
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.gas = gas
    self.gasPrice = gasPrice
  }
}

public struct SimulatedTransaction: Codable {
  public var changes: [SimulatedTransactionChange]
  public var gasUsed: String? = nil
  public var error: SimulatedTransactionError?
  public var requestError: SimulatedTransactionError?
}

public struct MetricsResponse: Codable {
  public var status: Bool
}

public struct MetricsTrackRequest: Codable {
  public let event: String
  public let properties: [String: AnyCodable]
}

public enum MetricsEvents: String {
  case portalInitialized = "Portal Initialized"
  case transactionSigned = "Transaction Signed"
  case walletBackedUp = "Wallet Backed Up"
  case walletCreated = "Wallet Created"
  case walletRecovered = "Wallet Recovered"

  // API Method events
  case getBackupShareMetadata = "Get Backup Share Metadata"
  case getBalances = "Get Balances"
  case getClient = "Get Client"
  case getEnabledDapps = "Get Enabled Dapps"
  case getNFTs = "Get NFTs"
  case getNetworks = "Get Networks"
  case getQuote = "Get Quote"
  case getSigningShareMetadata = "Get Signing Share Metadata"
  case getSources = "Get Sources"
  case getTransactions = "Get Transactions"
  case simulateTransaction = "Simulate Transaction"
  case storedClientBackupShare = "Stored Client Backup Share"
  case storedClientBackupShareKey = "Stored Client Backup Share Key"
  case storedClientSigningShare = "Stored Client Signing Share"
}

public enum GetTransactionsOrder: String {
  case asc
  case desc
}

public struct BackupSharePair: Codable {
  public var backupMethod: String
  public var createdAt: String
  public var id: String
  public var status: Status

  public enum Status: String, Codable {
    case completed
    case incomplete
  }
}

public struct SigningSharePair: Codable {
  public var createdAt: String
  public var id: String
  public var status: Status

  public enum Status: String, Codable {
    case completed
    case incomplete
  }
}

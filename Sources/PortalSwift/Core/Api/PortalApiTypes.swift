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
  public let bip122: ClientResponseNamespaceMetadataItem?
  public let stellar: ClientResponseNamespaceMetadataItem?
  public let tron: ClientResponseNamespaceMetadataItem?
}

public struct P2wpkhAddressInfo: Codable, Equatable {
  public let mainnet: String
  public let testnet: String
}

public struct BitcoinAddressInfo: Codable, Equatable {
  public let p2wpkh: P2wpkhAddressInfo
}

public struct ClientResponseNamespaceMetadataItem: Codable, Equatable {
  public let address: String
  public let curve: PortalCurve
  public let bitcoin: BitcoinAddressInfo?
  
  public init(address: String, curve: PortalCurve, bitcoin: BitcoinAddressInfo? = nil) {
    self.address = address
    self.curve = curve
    self.bitcoin = bitcoin
  }
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
  public var value: Float?
  /// Token Id of an ERC721 token, if applicable
  public var erc721TokenId: String?
  /// Metadata of an ERC1155 token, if applicable
  public var erc1155Metadata: [Erc1155Metadata?]?
  /// Token Id, if applicable
  public var tokenId: String?
  /// Type of asset involved in the transaction (e.g., ETH)
  public var asset: String?
  /// Category of the transaction (e.g., external)
  public var category: String
  /// Contract details related to the transaction
  public var rawContract: FetchedTransactionRawContract?
  /// Metadata associated with the transaction
  public var metadata: FetchedTransactionMetadata
  /// ID of the chain associated with the transaction
  public var chainId: Int
}

public struct Erc1155Metadata: Codable, Equatable {
  public let tokenId: String?
  public let value: String?
}

public struct FetchedTransactionRawContract: Codable, Equatable {
  /// Value involved in the contract
  public var value: String?
  /// Address of the contract, if applicable
  public var address: String?
  /// Decimal representation of the contract value
  public var decimal: String?
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

public struct SimulatedTransactionChange: Codable, Equatable {
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

public struct SimulatedTransactionError: Codable, Equatable {
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

public struct SimulatedTransaction: Codable, Equatable {
  public var changes: [SimulatedTransactionChange]
  public var gasUsed: String? = nil
  public var error: SimulatedTransactionError?
  public var requestError: SimulatedTransactionError?
}

public struct MetricsResponse: Codable, Equatable {
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

// MARK: - Evaluate Transaction

// Define the BlockaidResponse struct to model the response data
public struct BlockaidValidation: Codable {
  public struct Feature: Codable {
    let type: String
    let featureId: String
    let description: String
    let address: String?
  }

  let classification: String?
  let description: String?
  let features: [Feature]
  let reason: String?
  let resultType: String
  let status: String
}

public struct BlockaidAssetDiff: Codable {
  let asset: [String: AnyCodable]
  let `in`: [[String: AnyCodable]]
  let out: [[String: AnyCodable]]
}

public struct BlockaidSimulation: Codable {
  let accountAddress: String?
  let accountSummary: [String: AnyCodable]
  let addressDetails: [String: AnyCodable]
  let assetsDiffs: [String: [BlockaidAssetDiff]]
  let block: Int?
  let chain: String?
  let exposures: [String: AnyCodable]
  let status: String
  let totalUsdDiff: [String: AnyCodable]
  let totalUsdExposure: [String: AnyCodable]
}

public struct BlockaidValidateTrxRes: Codable {
  let validation: BlockaidValidation?
  let simulation: BlockaidSimulation?
  let block: Int?
  let chain: String
}

public struct EvaluateTransactionParam {
  let to: String
  let value: String?
  let data: String?
  let maxFeePerGas: String?
  let maxPriorityFeePerGas: String?
  let gas: String?
  let gasPrice: String?

  public init(to: String, value: String?, data: String?, maxFeePerGas: String?, maxPriorityFeePerGas: String?, gas: String?, gasPrice: String?) {
    self.to = to
    self.value = value
    self.data = data
    self.maxFeePerGas = maxFeePerGas
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.gas = gas
    self.gasPrice = gasPrice
  }

  func toDictionary() -> [String: String] {
    let dict: [String: String?] = [
      "to": to,
      "value": value,
      "data": data,
      "maxFeePerGas": maxFeePerGas,
      "maxPriorityFeePerGas": maxPriorityFeePerGas,
      "gas": gas
    ]

    // Filter out nil values
    return dict.compactMapValues { $0 }
  }
}

public enum EvaluateTransactionOperationType: String, CaseIterable {
  case validation
  case simulation
  case all
}

public struct FundParams: Codable {
  public init(amount: String, token: String) {
    self.amount = amount
    self.token = token
  }

  public let amount: String
  public let token: String
}

struct FundRequestBody: Codable, Equatable {
  let amount: String
  let chainId: String
  let token: String
}

public struct FundResponseData: Codable {
  public let explorerUrl: String
  public let txHash: String
}

public struct FundResponseMetadata: Codable {
  public let amount: String
  public let chainId: String
  public let clientId: String
  public let custodianId: String
  public let environmentId: String
  public let token: String
}

public struct FundResponseError: Codable {
  public let id: String
  public let message: String
}

public struct FundResponse: Codable {
  public let data: FundResponseData?
  public let metadata: FundResponseMetadata
  public let error: FundResponseError?
}

public struct BuildBitcoinP2wpkhTransactionResponse: Codable, Equatable {
  public let transaction: BitcoinP2wpkhTransaction
  public let metadata: BuildTransactionMetaData
  public let error: String?
}

public struct BitcoinP2wpkhTransaction: Codable, Equatable {
  public let signatureHashes: [String]
  public let rawTxHex: String
}

public struct BuildEip115TransactionResponse: Codable, Equatable {
  public let transaction: Eip115Transaction
  public let metadata: BuildTransactionMetaData
  public let error: String?
}

public struct Eip115Transaction: Codable, Equatable {
  public let from: String
  public let to: String
  public let data: String?
  public let value: String?
}

public struct BuildTransactionMetaData: Codable, Equatable {
  public let amount: String
  public let fromAddress: String
  public let toAddress: String
  public let tokenAddress: String?
  public let tokenDecimals: Int
  public let tokenSymbol: String?
  public let rawAmount: String
}

public struct BuildSolanaTransactionResponse: Codable, Equatable {
  public let transaction: String
  public let metadata: BuildTransactionMetaData
  public let error: String?
}

public struct BuildTransactionParam {
  let to: String
  let token: String
  let amount: String

  public init(to: String, token: String, amount: String) {
    self.to = to
    self.token = token
    self.amount = amount
  }

  func toDictionary() -> [String: String] {
    return [
      "to": to,
      "token": token,
      "amount": amount
    ]
  }
}

public struct BroadcastBitcoinP2wpkhTransactionResponseData: Codable, Equatable {
  public let txHash: String
}

public struct BroadcastBitcoinP2wpkhTransactionMetaData: Codable, Equatable {
  public let chainId: String
  public let clientId: String
}

public struct BroadcastBitcoinP2wpkhTransactionResponse: Codable, Equatable {
  public let data: BroadcastBitcoinP2wpkhTransactionResponseData
  public let metadata: BroadcastBitcoinP2wpkhTransactionMetaData
}

public struct BroadcastParam: Codable, Equatable {
  let signatures: [String]
  let rawTxHex: String
  
  public init(signatures: [String], rawTxHex: String) {
    self.signatures = signatures
    self.rawTxHex = rawTxHex
  }
}

// MARK: - NftAsset

public struct NftAsset: Codable, Equatable {
  let nftID, name, description: String?
  let imageURL: String?
  let chainID, contractAddress, tokenID: String?
  let collection: Collection?
  let lastSale: LastSale?
  let rarity: Rarity?
  let floorPrice: NftAssetFloorPrice?
  let detailedInfo: DetailedInfo?
}

// MARK: - Collection

public struct Collection: Codable, Equatable {
  let name, description: String?
  let imageURL: String?
}

// MARK: - DetailedInfo

public struct DetailedInfo: Codable, Equatable {
  public let ownerCount, tokenCount: Int?
  public let createdDate: String?
  public let attributes: [Attribute]?
  public let owners: [Owner]?
  public let extendedCollectionInfo: ExtendedCollectionInfo?
  public let extendedSaleInfo: ExtendedSaleInfo?
  public let marketplaceInfo: [MarketplaceInfo]?
  public let mediaInfo: MediaInfo?
}

// MARK: - Attribute

public struct Attribute: Codable, Equatable {
  let traitType, value: String?
//  let displayType: String?
}

// MARK: - ExtendedCollectionInfo

public struct ExtendedCollectionInfo: Codable, Equatable {
  public let bannerImageURL: String?
  public let externalURL: String?
  public let twitterUsername: String?
  public let discordURL: String?
  public let instagramUsername, mediumUsername: String?
  public let telegramURL: String?
  public let distinctOwnerCount, distinctNftCount, totalQuantity: Int?
}

// MARK: - ExtendedSaleInfo

public struct ExtendedSaleInfo: Codable, Equatable {
  public let fromAddress, toAddress: String?
  public let priceUsdCents: Int?
  public let transaction, marketplaceID, marketplaceName: String?
}

// MARK: - MarketplaceInfo

public struct MarketplaceInfo: Codable, Equatable {
  public let marketplaceID, marketplaceName, marketplaceCollectionID: String?
  public let nftURL, collectionURL: String?
  public let verified: Bool?
  public let floorPrice: MarketplaceInfoFloorPrice?
}

// MARK: - MarketplaceInfoFloorPrice

public struct MarketplaceInfoFloorPrice: Codable, Equatable {
  public let value: Double?
  public let paymentToken: PaymentToken?
  public let valueUsdCents: Int?
}

// MARK: - PaymentToken

public struct PaymentToken: Codable, Equatable {
  public let paymentTokenID, name, symbol: String?
  public let address: String?
  public let decimals: Int?
}

// MARK: - MediaInfo

public struct MediaInfo: Codable, Equatable {
  public let previews: Previews?
  public let animationURL: String?
  public let backgroundColor: String?
}

// MARK: - Previews

public struct Previews: Codable, Equatable {
  public let imageSmallURL, imageMediumURL, imageLargeURL, imageOpengraphURL: String?
  public let blurhash, predominantColor: String?
}

// MARK: - Owner

public struct Owner: Codable, Equatable {
  public let ownerAddress: String?
  public let quantity: Int?
  public let firstAcquiredDate, lastAcquiredDate: String?
}

// MARK: - NftAssetFloorPrice

public struct NftAssetFloorPrice: Codable, Equatable {
  let price: Double?
  let currency: String?
}

// MARK: - LastSale

public struct LastSale: Codable, Equatable {
  public let price: Double?
  public let currency: String?
  public let date: String?
}

// MARK: - Rarity

public struct Rarity: Codable, Equatable {
  public let rank: Int?
  public let score: Double?
}

// MARK: - Get Assets by Chain

public struct AssetsResponse: Decodable {
  public let nativeBalance: NativeBalance?
  public let tokenBalances: [TokenBalanceResponse]?
  public let nfts: [Nft]?
}

public struct NativeBalance: Decodable {
  public let balance: String?
  public let decimals: Int?
  public let name, rawBalance, symbol: String?
  public let metadata: NativeBalanceMetadata?
}

public struct NativeBalanceMetadata: Decodable {
  public let logo, thumbnail: String?
}

public struct Nft: Decodable {
  public let nftID, name, description: String?
  public let imageURL: String?
  public let chainID, contractAddress, tokenID: String?
  public let collection: Collection?
  public let lastSale: LastSale?
  public let rarity: Rarity?
  public let floorPrice: NftFloorPrice?
  public let detailedInfo: DetailedInfo?
}

public struct NftFloorPrice: Decodable {
  public let price: Double?
  public let currency: String?
}

public struct TokenBalanceResponse: Decodable {
  public let balance: String?
  public let decimals: Int?
  public let name, rawBalance, symbol: String?
  public let metadata: TokenBalanceMetadata?
}

public struct TokenBalanceMetadata: Decodable {
  public let tokenAddress: String?
  public let verifiedContract: Bool?
  public let totalSupply, rawTotalSupply: String?
  public let percentageRelativeToTotalSupply: Double?
}

// MARK: - Wallet_getCapabilities response

public typealias WalletCapabilitiesResponse = [String: WalletCapabilitiesValue]

// MARK: - WalletCapabilitiesValue

public struct WalletCapabilitiesValue: Codable, Equatable {
  let paymasterService: PaymasterService
}

// MARK: - PaymasterService

public struct PaymasterService: Codable, Equatable {
  let supported: Bool
}

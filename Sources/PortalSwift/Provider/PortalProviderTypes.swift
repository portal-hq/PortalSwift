import AnyCodable

public struct BlockData: Codable {
  public var number: String
  public var hash: String
  public var transactions: [String]?
  public var difficulty: String
  public var extraData: String
  public var gasLimit: String
  public var gasUsed: String
  public var logsBloom: String
  public var miner: String
  public var mixHash: String
  public var nonce: String
  public var parentHash: String
  public var receiptsRoot: String
  public var sha3Uncles: String
  public var size: String
  public var stateRoot: String
  public var timestamp: String
  public var totalDifficulty: String?
  public var transactionsRoot: String
  public var uncles: [String]
  public var baseFeePerGas: String?
}

// The specific return types for the 17 methods from the gateway that don't return strings
public struct BlockDataResponseFalse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: BlockData?
  public var error: PortalProviderRpcResponseError?
}

public struct BlockDataResponseTrue: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: BlockDataTrue?
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderRequestWithId: Codable {
  public let id: String
  public let method: PortalRequestMethod
  public let params: [AnyCodable]?
}

public struct PortalProviderRpcRequest: Codable {
  public var id: Int
  public var jsonrpc: String
  public var method: PortalRequestMethod
  public var params: [AnyCodable]?
}

public struct PortalProviderRpcBoolResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: Bool?
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderRpcResponse: Codable, Equatable {
  public var jsonrpc: String
  public var id: Int?
  public var result: String?
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderRpcResponseError: Codable, Equatable {
  public var code: Int
  public var message: String
}

public struct SolGetLatestBlockhashContext: Codable, Equatable {
  public var slot: Int
}

public struct SolGetLatestBlockhashValue: Codable, Equatable {
  public var blockhash: String
  public var lastValidBlockHeight: Int
}

public struct SolGetLatestBlockhashResult: Codable, Equatable {
  public var context: SolGetLatestBlockhashContext
  public var value: SolGetLatestBlockhashValue
}

public struct SolGetLatestBlockhashResponse: Codable, Equatable {
  public var jsonrpc: String
  public var id: Int?
  public var result: SolGetLatestBlockhashResult
  public var error: PortalProviderRpcResponseError?
}

public struct PortalProviderResult {
  public let id: String
  public let result: Any
}

/// A registered event handler.
public struct RegisteredEventHandler {
  var handler: (_ data: Any) throws -> Void
  var once: Bool
}

// Legacy types
// Consider removing these when legacy (strongly typed) request methods are removed.

/// An ETH request payload where params is of type [Any].
public struct ETHRequestPayload {
  public var id: String?
  public var method: ETHRequestMethods.RawValue
  public var params: [Any]
  public var signature: String?
  public var chainId: Int?

  public init(method: ETHRequestMethods.RawValue, params: [Any]) {
    self.method = method
    self.params = params
  }

  public init(method: ETHRequestMethods.RawValue, params: [Any], signature: String) {
    self.method = method
    self.params = params
    self.signature = signature
  }

  public init(method: ETHRequestMethods.RawValue, params: [Any], id: String) {
    self.method = method
    self.params = params
    self.id = id
  }

  public init(method: ETHRequestMethods.RawValue, params: [Any], id: String, chainId: Int) {
    self.method = method
    self.params = params
    self.id = id
    self.chainId = chainId
  }

  public init(method: ETHRequestMethods.RawValue, params: [Any], chainId: Int) {
    self.method = method
    self.params = params
    self.chainId = chainId
  }
}

public struct ETHChainParam: Codable {
  public var chainId: String
}

public struct ETHChainPayload: Codable {
  public var method: ETHRequestMethods.RawValue
  public var params: [ETHChainParam]
}

/// A param within ETHTransactionPayload.params.
public struct ETHTransactionParam: Codable {
  public var from: String
  public var to: String
  public var gas: String?
  public var gasPrice: String?
  public var maxPriorityFeePerGas: String?
  public var maxFeePerGas: String?
  public var value: String?
  public var data: String?
  public var nonce: String? = nil

  public init(from: String, to: String, gas: String, gasPrice: String, value: String, data: String, nonce: String? = nil) {
    self.from = from
    self.to = to
    self.gas = gas
    self.gasPrice = gasPrice
    self.value = value
    self.data = data
    self.nonce = nonce
  }

  public init(from: String, to: String, gasPrice: String, value: String, data: String, nonce: String? = nil) {
    self.from = from
    self.to = to
    self.gasPrice = gasPrice
    self.value = value
    self.data = data
    self.nonce = nonce
  }

  public init(from: String, to: String, value: String, data: String) {
    self.from = from
    self.to = to
    self.value = value
    self.data = data
  }

  public init(from: String, to: String) {
    self.from = from
    self.to = to
  }

  public init(from: String, to: String, value: String) {
    self.from = from
    self.to = to
    self.value = value
  }

  public init(from: String, to: String, data: String) {
    self.from = from
    self.to = to
    self.data = data
  }

  // Below is the variation for EIP-1559
  public init(from: String, to: String, gas: String, value: String, data: String, maxPriorityFeePerGas: String?, maxFeePerGas: String?, nonce: String? = nil) {
    self.from = from
    self.to = to
    self.gas = gas
    self.value = value
    self.data = data
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
    self.nonce = nonce
  }
}

/// An error response from Gateway.
public struct ETHGatewayErrorResponse: Codable {
  public var code: Int
  public var message: String
}

/// A response from Gateway.
public typealias ETHGatewayResponse = PortalProviderRpcResponse

/// The payload for a transaction request.
public struct ETHTransactionPayload: Codable {
  public var id: String?
  public var method: ETHRequestMethods.RawValue
  public var params: [ETHTransactionParam]
  public var chainId: Int? = nil

  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam]) {
    self.method = method
    self.params = params
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam], id: String) {
    self.method = method
    self.params = params
    self.id = id
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam], id: String, chainId: Int) {
    self.method = method
    self.params = params
    self.id = id
    self.chainId = chainId
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam], chainId: Int) {
    self.method = method
    self.params = params
    self.chainId = chainId
  }
}

/// A param within ETHAddressPayload.params.
public struct ETHAddressParam: Codable {
  public var address: String

  public init(address: String) {
    self.address = address
  }
}

/// The payload for an address request.
public struct ETHAddressPayload: Codable {
  public var id: String?
  public var method: ETHRequestMethods.RawValue
  public var params: [ETHAddressParam]
  public var chainId: Int? = nil

  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam]) {
    self.method = method
    self.params = params
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam], id: String) {
    self.method = method
    self.params = params
    self.id = id
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam], id: String, chainId: Int) {
    self.method = method
    self.params = params
    self.id = id
    self.chainId = chainId
  }

  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam], chainId: Int) {
    self.method = method
    self.params = params
    self.chainId = chainId
  }
}

/// The result of a request.
public struct RequestCompletionResult {
  public init(method: String, params: [Any]?, result: Any, id: String) {
    self.method = method
    self.params = params
    self.result = result
    self.id = id
  }

  public var method: String
  public var params: [Any]?
  public var result: Any
  public var id: String
}

/// The result of a transaction request.
public struct TransactionCompletionResult {
  public var method: String
  public var params: [ETHTransactionParam]
  public var result: Any
  public var id: String
}

/// The result of an address request.
public struct AddressCompletionResult {
  public var method: String
  public var params: [ETHAddressParam]
  public var result: Any
  public var id: String
}

public struct EthTransactionResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: TransactionData?
  public var error: PortalProviderRpcResponseError?
}

public struct EthBoolResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: Bool?
  public var error: PortalProviderRpcResponseError?
}

public struct BlockDataTrue: Codable {
  public let number: String
  public let hash: String
  public let transactions: [TransactionData]
  public let difficulty: String
  public let extraData: String
  public let gasLimit: String
  public let gasUsed: String
  public let logsBloom: String
  public let miner: String
  public let mixHash: String
  public let nonce: String
  public let parentHash: String
  public let receiptsRoot: String
  public let sha3Uncles: String
  public let size: String
  public let stateRoot: String
  public let timestamp: String
  public let totalDifficulty: String
  public let transactionsRoot: String
  public let uncles: [String]
  public let baseFeePerGas: String
  public let withdrawalsRoot: String
  public let withdrawals: [Withdrawal]
}

public struct TransactionData: Codable {
  public let blockHash: String
  public let blockNumber: String
  public let hash: String?
  public let chainId: String?
  public let from: String
  public let gas: String?
  public let gasPrice: String?
  public let input: String?
  public let nonce: String?
  public let r: String?
  public let s: String?
  public let to: String?
  public let transactionIndex: String
  public let type: String
  public let v: String?
  public let value: String?
  public let accessList: [String]?
  public let maxFeePerGas: String?
  public let maxPriorityFeePerGas: String?
  public let transactionHash: String?
  public let logs: [Log]?
  public let contractAddress: String?
  public let effectiveGasPrice: String?
  public let cumulativeGasUsed: String?
  public let gasUsed: String?
  public let logsBloom: String?
  public let status: String?
}

public struct Log: Codable {
  public let transactionHash: String?
  public let address: String?
  public let blockHash: String?
  public let blockNumber: String?
  public let data: String?
  public let logIndex: String?
  public let removed: Bool?
  public let topics: [String]?
  public let transactionIndex: String?
}

public struct Withdrawal: Codable {
  public let address: String
  public let amount: String
  public let index: String
  public let validatorIndex: String
}

public struct LogsResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: [Log]?
  public var error: PortalProviderRpcResponseError?
}

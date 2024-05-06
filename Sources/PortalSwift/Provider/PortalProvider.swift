//
//  PortalProvider.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

/// Portal's EVM blockchain provider.
public class PortalProvider {
  public var address: String? {
    do {
      return try self.keychain.getAddress()
    } catch {
      return nil
    }
  }

  public let apiKey: String
  public var autoApprove: Bool
  public var chainId: Chains.RawValue?
  public var delegate: PortalProviderDelegate?
  public var gatewayUrl: String?

  private let decoder = JSONDecoder()
  private var events: [Events.RawValue: [RegisteredEventHandler]] = [:]
  private var keychain: PortalKeychain
  private let logger = PortalLogger()
  private var mpcQueue: DispatchQueue
  private var processedRequestIds: [String] = []
  private var processedSignatureIds: [String] = []
  private var portalApi: HttpRequester
  private let requests: PortalRequests
  private let rpcConfig: [String: String]
  private let signer: PortalMpcSigner
  private let featureFlags: FeatureFlags?

  private var walletMethods: [ETHRequestMethods.RawValue] = [
    ETHRequestMethods.WalletAddEthereumChain.rawValue,
    ETHRequestMethods.WalletGetPermissions.rawValue,
    ETHRequestMethods.WalletRegisterOnboarding.rawValue,
    ETHRequestMethods.WalletRequestPermissions.rawValue,
    ETHRequestMethods.WalletSwitchEthereumChain.rawValue,
    ETHRequestMethods.WalletWatchAsset.rawValue,
  ]

  /// Creates an instance of PortalProvider.
  /// - Parameters:
  ///   - apiKey: The client API key. You can obtain this via Portal's REST API.
  ///   - chainId: The ID of the EVM network you are using.
  ///   - gatewayUrl: The gateway URL, such as Infura or Alchemy.
  ///   - apiHost: The hostname of the API to use.
  ///   - autoApprove: Auto approves all transactions.
  public init(
    apiKey: String,
    rpcConfig: [String: String],
    keychain: PortalKeychain,
    autoApprove: Bool,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    requests: PortalRequests? = nil,
    signer: PortalMpcSigner? = nil
  ) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.autoApprove = autoApprove
    self.keychain = keychain
    self.rpcConfig = rpcConfig

    // Other instance variables
    let apiUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.portalApi = HttpRequester(baseUrl: apiUrl)
    self.featureFlags = featureFlags
    self.requests = requests ?? PortalRequests()
    self.signer = signer ?? PortalMpcSigner(
      apiKey: apiKey,
      keychain: keychain,
      mpcUrl: mpcHost,
      version: version,
      featureFlags: featureFlags
    )
    // Create a serial dispatch queue with a unique label
    self.mpcQueue = DispatchQueue.global(qos: .background)

    self.dispatchConnect()
  }

  /*******************************************
   * Public functions
   *******************************************/

  /// Emits an event from the provider to registered event handlers.
  /// - Parameters:
  ///   - event: The event to be emitted.
  ///   - data: The data to pass to registered event handlers.
  /// - Returns: The Portal Provider instance.
  public func emit(event: Events.RawValue, data: Any) -> PortalProvider {
    let registeredEventHandlers = self.events[event]

    if registeredEventHandlers == nil {
      self.logger.info(String(format: "PortalProvider.emit() - ⚠️ Could not find any bindings for event '%@'. Ignoring...", event))
      return self
    } else {
      // Invoke all registered handlers for the event
      do {
        for registeredEventHandler in registeredEventHandlers! {
          try registeredEventHandler.handler(data)
        }
      } catch {
        self.logger.info("PortalProvider.emit() - 🚨 Error invoking registered handlers: \(error.localizedDescription)")
      }

      // Remove once instances
      self.events[event] = registeredEventHandlers?.filter(self.removeOnce)

      return self
    }
  }

  /// Registers a callback for an event.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func on(event: Events.RawValue, callback: @escaping (_ data: Any) -> Void) -> PortalProvider {
    if self.events[event] == nil {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: false
    ))

    return self
  }

  /// Registers a callback for an event. Deletes the registered callback after it's fired once.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func once(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) throws -> Void
  ) -> PortalProvider {
    if self.events[event] == nil {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: true
    ))

    return self
  }

  /// Removes the callback for the specified event.
  /// - Parameters:
  ///   - event: A specific event from the list of Events.
  /// - Returns: An instance of Portal Provider.
  public func removeListener(
    event: Events.RawValue
  ) -> PortalProvider {
    if self.events[event] == nil {
      self.logger.info(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
    }

    self.events[event] = nil

    return self
  }

  /// Makes a request.
  /// - Parameters:
  ///   - chainId: A CAIP-2 Blockchain ID associated with the request.
  ///   - withMethod: A member of the PortalRequestMethod enum
  ///   - andParams: An array of parameters for the request (either RPC parameters or a transaction if signing)
  /// - Returns: PortalProviderResult
  public func request(
    _ chainId: String,
    withMethod: PortalRequestMethod,
    andParams: [AnyCodable]? = [],
    connect: PortalConnect? = nil
  ) async throws -> PortalProviderResult {
    let blockchain = try PortalBlockchain(fromChainId: chainId)
    guard blockchain.isMethodSupported(withMethod) else {
      throw PortalProviderError.unsupportedRequestMethod(withMethod.rawValue)
    }

    let id = UUID().uuidString

    // This switch is here to handle methods that should be
    // resolved by the provider directly before passing the
    // request on to RPC or the signer.
    //
    // The default behavior is to use the `PortalBlockchain`
    // instance to determine if the method should be signed
    // or not.
    switch withMethod {
    case .eth_accounts, .eth_requestAccounts:
      let address = try await keychain.getAddress(chainId)
      return PortalProviderResult(id: id, result: [address])
    case .wallet_switchEthereumChain:
      return PortalProviderResult(id: id, result: "null")
    default:
      if blockchain.shouldMethodBeSigned(withMethod) {
        let payload = PortalProviderRequestWithId(id: id, method: withMethod, params: andParams)
        return try await self.handleSignRequest(chainId, withPayload: payload, forId: id, onBlockchain: blockchain, connect: connect)
      } else {
        return try await self.handleRpcRequest(chainId, withMethod: withMethod, andParams: andParams, forId: id)
      }
    }
  }

  /// Makes a request.
  /// - Parameters:
  ///   - chainId: A CAIP-2 Blockchain ID associated with the request.
  ///   - withMethod: The string literal of your RPC method
  ///   - andParams: An array of parameters for the request (either RPC parameters or a transaction if signing)
  /// - Returns: PortalProviderResult
  public func request(
    _ chainId: String,
    withMethod: String,
    andParams: [AnyCodable]? = [],
    connect _: PortalConnect? = nil
  ) async throws -> PortalProviderResult {
    guard let method = PortalRequestMethod(rawValue: withMethod) else {
      throw PortalProviderError.unsupportedRequestMethod("Received a request with unsupported method: \(withMethod)")
    }

    return try await self.request(chainId, withMethod: method, andParams: andParams)
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func dispatchConnect() {
    if let chainId = chainId {
      let hexChainId = String(format: "%02x", chainId)
      _ = self.emit(event: Events.Connect.rawValue, data: ["chainId": hexChainId])
    }
  }

  private func getApproval(_: String, forPayload: PortalProviderRequestWithId, connect: PortalConnect? = nil) async throws -> Bool {
    if self.autoApprove {
      return true
    }
    if connect == nil && self.events[Events.PortalSigningRequested.rawValue] == nil {
      throw ProviderSigningError.noBindingForSigningApprovalFound
    }

    return try await withCheckedThrowingContinuation { [self] (continuation: CheckedContinuation<Bool, Error>) in
      _ = self.on(event: Events.PortalSigningApproved.rawValue, callback: { approved in
        if approved is PortalProviderRequestWithId {
          let approvedPayload = approved as! PortalProviderRequestWithId

          if approvedPayload.id == forPayload.id, !self.processedRequestIds.contains(forPayload.id) {
            self.processedRequestIds.append(forPayload.id)

            // If the approved event is fired
            continuation.resume(returning: true)
          }
        }
      }).on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
        if approved is ETHRequestPayload {
          let rejectedPayload = approved as! ETHRequestPayload

          if rejectedPayload.id == forPayload.id, !self.processedRequestIds.contains(forPayload.id) {
            self.processedRequestIds.append(forPayload.id)
            // If the rejected event is fired
            continuation.resume(returning: false)
          }
        }
      })

      if connect != nil {
        _ = connect?.emit(event: Events.PortalSigningRequested.rawValue, data: forPayload)
      } else {
        _ = self.emit(event: Events.PortalSigningRequested.rawValue, data: forPayload)
      }
    }
  }

  private func getRpcUrl(_ chainId: String) throws -> String {
    guard let rpcUrl = rpcConfig[chainId] else {
      throw PortalProviderError.noRpcUrlFoundForChainId(chainId)
    }

    return rpcUrl
  }

  @available(*, deprecated, renamed: "getRpcUrl", message: "Please use the chain agnostic implementation of getRpcUrl()")
  private func getRpcUrl(_ chainId: Int) throws -> String {
    return try self.getRpcUrl("eip155:\(chainId)")
  }

  private func handleRpcRequest(
    _ chainId: String,
    withMethod: PortalRequestMethod,
    andParams: [AnyCodable]?,
    forId: String
  ) async throws -> PortalProviderResult {
    let rpcUrl = try getRpcUrl(chainId)

    if let url = URL(string: rpcUrl) {
      let payload = PortalProviderRpcRequest(
        id: 0,
        jsonrpc: "2.0",
        method: withMethod,
        params: andParams
      )
      let data = try await requests.post(url, withBearerToken: nil, andPayload: payload)

      switch withMethod {
      case .eth_getBlockByHash, .eth_getBlockByNumber, .eth_getUncleByBlockHashAndIndex, .eth_getUncleByBlockNumberAndIndex:
        if let params = andParams, params.count > 1, let elementAtIndex1 = andParams?[1] as? Bool, elementAtIndex1 {
          let rpcResponse = try decoder.decode(BlockDataResponseTrue.self, from: data)
          if let rpcError = rpcResponse.error {
            throw PortalRpcError(rpcError)
          }
          return PortalProviderResult(id: forId, result: rpcResponse)
        } else {
          let rpcResponse = try decoder.decode(BlockDataResponseFalse.self, from: data)
          if let rpcError = rpcResponse.error {
            throw PortalRpcError(rpcError)
          }
          return PortalProviderResult(id: forId, result: rpcResponse)
        }
      case .eth_getTransactionByBlockHashAndIndex, .eth_getTransactionByBlockNumberAndIndex, .eth_getTransactionByHash, .eth_getTransactionReceipt:
        let rpcResponse = try decoder.decode(EthTransactionResponse.self, from: data)
        if let rpcError = rpcResponse.error {
          throw PortalRpcError(rpcError)
        }
        return PortalProviderResult(id: forId, result: rpcResponse)
      case .eth_uninstallFilter, .net_listening:
        let rpcResponse = try decoder.decode(PortalProviderRpcBoolResponse.self, from: data)
        if let rpcError = rpcResponse.error {
          throw PortalRpcError(rpcError)
        }
        return PortalProviderResult(id: forId, result: rpcResponse)
      case .eth_getFilterChanges, .eth_getFilterLogs, .eth_getLogs:
        let rpcResponse = try decoder.decode(LogsResponse.self, from: data)
        if let rpcError = rpcResponse.error {
          throw PortalRpcError(rpcError)
        }
        return PortalProviderResult(id: forId, result: rpcResponse)
      case .sol_getLatestBlockhash:
        let rpcResponse = try decoder.decode(SolGetLatestBlockhashResponse.self, from: data)
        if let rpcError = rpcResponse.error {
          throw PortalRpcError(rpcError)
        }
        return PortalProviderResult(id: forId, result: rpcResponse)
      default:
        let rpcResponse = try decoder.decode(PortalProviderRpcResponse.self, from: data)
        if let rpcError = rpcResponse.error {
          throw PortalRpcError(rpcError)
        }
        return PortalProviderResult(id: forId, result: rpcResponse)
      }
    }

    throw URLError(.badURL)
  }

  private func handleSignRequest(
    _ onChainId: String,
    withPayload: PortalProviderRequestWithId,
    forId _: String,
    onBlockchain: PortalBlockchain,
    connect: PortalConnect? = nil
  ) async throws -> PortalProviderResult {
    guard try await self.getApproval(onChainId, forPayload: withPayload, connect: connect) else {
      throw ProviderSigningError.userDeclinedApproval
    }

    let rpcUrl = try getRpcUrl(onChainId)
    let payload = PortalSignRequest(method: withPayload.method, params: withPayload.params)

    let signature = try await self.signer.sign(
      onChainId,
      withPayload: payload,
      andRpcUrl: rpcUrl,
      usingBlockchain: onBlockchain
    )

    return PortalProviderResult(id: withPayload.id, result: signature)
  }

  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    !registeredEventHandler.once
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Makes a request.
  /// - Parameters:
  ///   - payload: A normal payload whose params are of type [Any].
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  @available(*, deprecated, renamed: "request", message: "Please use the async/await implementation of request().")
  public func request(
    payload: ETHRequestPayload,
    completion: @escaping (Result<RequestCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    Task {
      do {
        let chainId = "eip155:\(self.chainId ?? 11_155_111)"

        guard let method = PortalRequestMethod(rawValue: payload.method) else {
          throw PortalProviderError.unsupportedRequestMethod(payload.method)
        }
        let params = payload.params.map { param in
          AnyCodable(param)
        }
        let response = try await request(chainId, withMethod: method, andParams: params)

        completion(Result(data: RequestCompletionResult(
          method: payload.method,
          params: payload.params,
          result: response.result,
          id: response.id
        )))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Makes a request.
  /// - Parameters:
  ///   - payload: A transaction payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  @available(*, deprecated, renamed: "request", message: "Please use the async/await implementation of request().")
  public func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    Task {
      do {
        guard let method = PortalRequestMethod(rawValue: payload.method) else {
          throw PortalProviderError.unsupportedRequestMethod(payload.method)
        }
        let params = payload.params.map { param in
          AnyCodable(param)
        }
        let response = try await request("eip155:\(self.chainId ?? 11_155_111)", withMethod: method, andParams: params)

        completion(Result(data: TransactionCompletionResult(method: payload.method, params: payload.params, result: response.result, id: response.id)))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Makes a request.
  /// - Parameters:
  ///   - payload: An address payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  @available(*, deprecated, renamed: "request", message: "Please use the async/await implementation of request().")
  public func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    Task {
      do {
        guard let method = PortalRequestMethod(rawValue: payload.method) else {
          throw PortalProviderError.unsupportedRequestMethod(payload.method)
        }
        let params = payload.params.map { param in
          AnyCodable(param)
        }
        let response = try await request("eip155:\(self.chainId ?? 11_155_111)", withMethod: method, andParams: params)

        completion(Result(data: AddressCompletionResult(method: payload.method, params: payload.params, result: response.result, id: response.id)))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Sets the EVM network chainId.
  /// - Parameter value: The chainId.
  /// - Returns: An instance of Portal Provider.
  @available(*, deprecated, renamed: "NONE", message: "Please use the chain agnostic approach to using Portal by passing a CAIP-2 Blockchain ID to your request() calls.")
  public func setChainId(value: Int, connect: PortalConnect? = nil) throws -> PortalProvider {
    self.chainId = value
    let hexChainId = String(format: "%02x", value)

    let provider = self.emit(event: Events.ChainChanged.rawValue, data: ["chainId": hexChainId])

    do {
      let gatewayUrl = try getRpcUrl(value)
      self.gatewayUrl = gatewayUrl
    } catch {
      throw ProviderInvalidArgumentError.invalidGatewayUrl
    }
    self.chainId = value

    if connect != nil {
      connect?.emit(event: Events.PortalConnectChainChanged.rawValue, data: value)
    }
    return provider
  }
}

/**********************************
 * Supporting Structs
 **********************************/

/// A list of EVM networks.
public enum Chains: Int {
  case Mainnet = 1
  case Ropsten = 3
  case Rinkeby = 4
  case Goerli = 5
  case Sepolia = 11_155_111
  case Kovan = 42
}

/// The provider events that can be listened to.
public enum Events: String {
  case ChainChanged = "chainChanged"
  case PortalConnectChainChanged = "portalConnect_chainChanged"
  case Connect = "connect"
  case ConnectError = "portal_connectError"
  case Disconnect = "disconnect"
  case PortalSignatureReceived = "portal_signatureReceived"
  case PortalSigningApproved = "portal_signingApproved"
  case PortalSigningRejected = "portal_signingRejected"
  case PortalConnectSigningRequested = "portalConnect_signingRequested"
  case PortalSigningRequested = "portal_signingRequested"
  // Walletconnect V2
  case PortalDappSessionRequested = "portal_dappSessionRequested"
  case PortalDappSessionApproved = "portal_dappSessionApproved"
  case PortalDappSessionRejected = "portal_dappSessionRejected"
}

public enum PortalRequestMethod: String, Codable {
  // ETH Methods
  case eth_accounts
  case eth_blockNumber
  case eth_call
  case eth_chainId
  case eth_estimateGas
  case eth_gasPrice
  case eth_getBalance
  case eth_getBlockTransactionCountByNumber
  case eth_getCode
  case eth_getStorageAt
  case eth_getTransactionCount
  case eth_getUncleCountByBlockNumber
  case eth_newPendingTransactionFilter
  case eth_protocolVersion
  case eth_requestAccounts
  case eth_sendRawTransaction
  case eth_sendTransaction
  case eth_sign
  case eth_signTransaction
  case eth_signTypedData_v3
  case eth_signTypedData_v4
  case personal_sign

  case eth_getBlockByHash
  case eth_getTransactionByHash
  case eth_getTransactionReceipt
  case eth_getUncleByBlockHashAndIndex
  case eth_getUncleCountByBlockHash
  case eth_getTransactionByBlockNumberAndIndex
  case eth_getBlockByNumber
  case eth_getBlockTransactionCountByHash
  case net_listening
  case eth_getTransactionByBlockHashAndIndex
  case eth_getUncleByBlockNumberAndIndex
  case eth_getLogs
  case eth_uninstallFilter
  case eth_newFilter
  case eth_getFilterLogs
  case eth_newBlockFilter
  case eth_getFilterChanges

  // Wallet Methods (MetaMask stuff)
  case wallet_addEthereumChain
  case wallet_getPermissions
  case wallet_registerOnboarding
  case wallet_requestPermissions
  case wallet_switchEthereumChain
  case wallet_watchAsset

  // Net Methods
  case net_version

  // Web3 Methods
  case web3_clientVersion
  case web3_sha3

  // Solana RPC Methods
  case sol_getAccountInfo = "getAccountInfo"
  case sol_getBalance = "getBalance"
  case sol_getBlock = "getBlock"
  case sol_getBlockCommitment = "getBlockCommitment"
  case sol_getBlockHeight = "getBlockHeight"
  case sol_getBlockProduction = "getBlockProduction"
  case sol_getBlockTime = "getBlockTime"
  case sol_getBlocks = "getBlocks"
  case sol_getBlocksWithLimit = "getBlocksWithLimit"
  case sol_getClusterNodes = "getClusterNodes"
  case sol_getEpochInfo = "getEpochInfo"
  case sol_getEpochSchedule = "getEpochSchedule"
  case sol_getFeeForMessage = "getFeeForMessage"
  case sol_getFirstAvailableBlock = "getFirstAvailableBlock"
  case sol_getGenesisHash = "getGenesisHash"
  case sol_getHealth = "getHealth"
  case sol_getHighestSnapshotSlot = "getHighestSnapshotSlot"
  case sol_getIdentity = "getIdentity"
  case sol_getInflationGovernor = "getInflationGovernor"
  case sol_getInflationRate = "getInflationRate"
  case sol_getInflationReward = "getInflationReward"
  case sol_getLargestAccounts = "getLargestAccounts"
  case sol_getLatestBlockhash = "getLatestBlockhash"
  case sol_getLeaderSchedule = "getLeaderSchedule"
  case sol_getMaxRetransmitSlot = "getMaxRetransmitSlot"
  case sol_getMaxShredInsertSlot = "getMaxShredInsertSlot"
  case sol_getMinimumBalanceForRentExemption = "getMinimumBalanceForRentExemption"
  case sol_getMultipleAccounts = "getMultipleAccounts"
  case sol_getProgramAccounts = "getProgramAccounts"
  case sol_getRecentPerformanceSamples = "getRecentPerformanceSamples"
  case sol_getRecentPrioritizationFees = "getRecentPrioritizationFees"
  case sol_getSignatureStatuses = "getSignatureStatuses"
  case sol_getSignaturesForAddress = "getSignaturesForAddress"
  case sol_getSlot = "getSlot"
  case sol_getSlotLeader = "getSlotLeader"
  case sol_getSlotLeaders = "getSlotLeaders"
  case sol_getStakeActivation = "getStakeActivation"
  case sol_getStakeMinimumDelegation = "getStakeMinimumDelegation"
  case sol_getSupply = "getSupply"
  case sol_getTokenAccountBalance = "getTokenAccountBalance"
  case sol_getTokenAccountsByDelegate = "getTokenAccountsByDelegate"
  case sol_getTokenAccountsByOwner = "getTokenAccountsByOwner"
  case sol_getTokenLargestAccounts = "getTokenLargestAccounts"
  case sol_getTokenSupply = "getTokenSupply"
  case sol_getTransaction = "getTransaction"
  case sol_getTransactionCount = "getTransactionCount"
  case sol_getVersion = "getVersion"
  case sol_getVoteAccounts = "getVoteAccounts"
  case sol_isBlockhashValid = "isBlockhashValid"
  case sol_minimumLedgerSlot = "minimumLedgerSlot"
  case sol_requestAirdrop = "requestAirdrop"
  case sol_sendTransaction = "sendTransaction"
  case sol_simulateTransaction = "simulateTransaction"

  // Solana Wallet Methods
  case sol_signAndConfirmTransaction
  case sol_signAndSendTransaction
  case sol_signMessage
  case sol_signTransaction
}

/// All available provider methods.
public enum ETHRequestMethods: String {
  // ETH Methods
  case Accounts = "eth_accounts"
  case BlockNumber = "eth_blockNumber"
  case Call = "eth_call"
  case ChainId = "eth_chainId"
  case EstimateGas = "eth_estimateGas"
  case GasPrice = "eth_gasPrice"
  case GetBalance = "eth_getBalance"
  case GetBlockTransactionCountByNumber = "eth_getBlockTransactionCountByNumber"
  case GetCode = "eth_getCode"
  case GetStorageAt = "eth_getStorageAt"
  case GetTransactionCount = "eth_getTransactionCount"
  case GetUncleCountByBlockNumber = "eth_getUncleCountByBlockNumber"
  case NewPendingTransactionFilter = "eth_newPendingTransactionFilter"
  case PersonalSign = "personal_sign"
  case ProtocolVersion = "eth_protocolVersion"
  case RequestAccounts = "eth_requestAccounts"
  case SendRawTransaction = "eth_sendRawTransaction"
  case SendTransaction = "eth_sendTransaction"
  case Sign = "eth_sign"
  case SignTransaction = "eth_signTransaction"
  case SignTypedDataV3 = "eth_signTypedData_v3"
  case SignTypedDataV4 = "eth_signTypedData_v4"

  case GetBlockByHash = "eth_getBlockByHash"
  case GetTransactionByHash = "eth_getTransactionByHash"
  case GetTransactionReceipt = "eth_getTransactionReceipt"
  case GetUncleByBlockHashIndex = "eth_getUncleByBlockHashAndIndex"
  case GetUncleCountByBlockHash = "eth_getUncleCountByBlockHash"
  case GetTransactionByBlockNumberAndIndex = "eth_getTransactionByBlockNumberAndIndex"
  case GetBlockByNumber = "eth_getBlockByNumber"
  case GetBlockTransactionCountByHash = "eth_getBlockTransactionCountByHash"
  case NetListening = "net_listening"
  case GetTransactionByBlockHashAndIndex = "eth_getTransactionByBlockHashAndIndex"
  case GetUncleByBlockNumberAndIndex = "eth_getUncleByBlockNumberAndIndex"
  case GetLogs = "eth_getLogs"
  case UninstallFilter = "eth_uninstallFilter"
  case NewFilter = "eth_newFilter"
  case GetFilterLogs = "eth_getFilterLogs"
  case GetNewBlockFilter = "eth_newBlockFilter"
  case GetFilterChanges = "eth_getFilterChanges"

  // Wallet Methods (MetaMask stuff)
  case WalletAddEthereumChain = "wallet_addEthereumChain"
  case WalletGetPermissions = "wallet_getPermissions"
  case WalletRegisterOnboarding = "wallet_registerOnboarding"
  case WalletRequestPermissions = "wallet_requestPermissions"
  case WalletSwitchEthereumChain = "wallet_switchEthereumChain"
  case WalletWatchAsset = "wallet_watchAsset"

  // Net Methods
  case NetVersion = "net_version"

  // Web3 Methods
  case Web3ClientVersion = "web3_clientVersion"
  case Web3Sha3 = "web3_sha3"
}

/// A list of errors that can be thrown when instantiating PortalProvider.
public enum ProviderInvalidArgumentError: Error {
  case invalidGatewayUrl
}

/// A list of errors that can be thrown when making requests to Gateway.
public enum ProviderRpcError: Error {
  case chainDisconnected
  case disconnected
  case unauthorized
  case unsupportedMethod
  case userRejectedRequest
}

/// A list of errors that can be thrown when signing.
public enum ProviderSigningError: Error {
  case noBindingForSigningApprovalFound
  case userDeclinedApproval
  case walletRequestRejected
}

/// A list of JSON-RPC transaction methods.
public var TransactionMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.Call.rawValue, // string
  ETHRequestMethods.EstimateGas.rawValue, // string
  ETHRequestMethods.GetStorageAt.rawValue, // data
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
]

/// A list of JSON-RPC signing methods.
public var signerMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedDataV3.rawValue,
  ETHRequestMethods.SignTypedDataV4.rawValue,
]

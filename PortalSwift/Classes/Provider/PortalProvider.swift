//
//  PortalProvider.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

// enums
public enum Chains: Int {
  case Mainnet = 1
  case Ropsten = 3
  case Rinkeby = 4
  case Goerli = 5
  case Kovan = 42
}

public enum Events: String {
  case ChainChanged = "chainChanged"
  case Connect = "connect"
  case Disconnect = "disconnect"
  case PortalSigningApproved = "portal_signingApproved"
  case PortalSigningRejected = "portal_signingRejected"
  case PortalSigningRequested = "portal_signingRequested"
}

public enum ETHRequestMethods: String {
  // ETH Methods
  case Accounts = "eth_accounts"
  case BlockNumber = "eth_blockNumber"
  case Call = "eth_call"
  case ChainId = "eth_chainId"
  case Coinbase = "eth_coinbase"
  case CompileSolidity = "eth_compileSolidity"
  case CompileLLL = "eth_compileLLL"
  case CompileSerpent = "eth_compileSerpent"
  case EstimateGas = "eth_estimateGas"
  case GasPrice = "eth_gasPrice"
  case GetBalance = "eth_getBalance"
  case GetBlockByHash = "eth_getBlockByHash"
  case GetBlockByNumber = "eth_getBlockByNumber"
  case GetBlockTransactionCountByHash = "eth_getBlockTransactionCountByHash"
  case GetBlockTransactionCountByNumber = "eth_getBlockTransactionCountByNumber"
  case GetCode = "eth_getCode"
  case GetCompilers = "eth_getCompilers"
  case GetFilterChange = "eth_getFilterChange"
  case GetFilterLogs = "eth_getFilterLogs"
  case GetLogs = "eth_getLogs"
  case GetStorageAt = "eth_getStorageAt"
  case GetTransactionByHash = "eth_getTransactionByHash"
  case GetTransactionByBlockHashAndIndex = "eth_getTransactionByBlockHashAndIndex"
  case GetTransactionByBlockNumberAndIndex = "eth_getTransactionByBlockNumberAndIndex"
  case GetTransactionCount = "eth_getTransactionCount"
  case GetTransactionReceipt = "eth_getTransactionReceipt"
  case GetUncleByBlockHashIndex = "eth_getUncleByBlockHashAndIndex"
  case GetUncleByBlockNumberAndIndex = "eth_getUncleByBlockNumberAndIndex"
  case GetUncleCountByBlockHash = "eth_getUncleCountByBlockHash"
  case GetUncleCountByBlockNumber = "eth_getUncleCountByBlockNumber"
  case GetWork = "eth_getWork"
  case Hashrate = "eth_hashrate"
  case Mining = "eth_mining"
  case NewBlockFilter = "eth_newBlockFilter"
  case NewFilter = "eth_newFilter"
  case NewPendingTransactionFilter = "eth_newPendingTransactionFilter"
  case PersonalSign = "personal_sign"
  case ProtocolVersion = "eth_protocolVersion"
  case RequestAccounts = "eth_requestAccounts"
  case SendRawTransaction = "eth_sendRawTransaction"
  case SendTransaction = "eth_sendTransaction"
  case Sign = "eth_sign"
  case SignTransaction = "eth_signTransaction"
  case SignTypedData = "eth_signTypedData"
  case SubmitHashrate = "eth_submitHashrate"
  case SubmitWork = "eth_submitWork"
  case Synching = "eth_syncing"
  case UninstallFilter = "eth_uninstallFilter"

  // Wallet Methods (MetaMask stuff)
  case WalletAddEthereumChain = "wallet_addEthereumChain"
  case WalletGetPermissions = "wallet_getPermissions"
  case WalletRegisterOnboarding = "wallet_registerOnboarding"
  case WalletRequestPermissions = "wallet_requestPermissions"
  case WalletSwitchEthereumChain = "wallet_switchEthereumChain"
  case WalletWatchAsset = "wallet_watchAsset"

  // Net Methods
  case NetListening = "net_listening"
  case NetPeerCount = "net_peerCount"
  case NetVersion = "net_version"

  // Web3 Methods
  case Web3ClientVersion = "web3_clientVersion"
  case Web3Sha3 = "web3_sha3"
}

public enum ProviderInvalidArgumentError: Error {
  case invalidGatewayUrl
}

public enum ProviderRpcError: Error {
  case chainDisconnected
  case disconnected
  case unauthorized
  case unsupportedMethod
  case userRejectedRequest
}

public enum ProviderSigningError: Error {
  case noBindingForSigningApprovalFound
  case userDeclinedApproval
  case walletRequestRejected
}

// structs
public struct ETHRequestPayload: Codable {
  var method: ETHRequestMethods.RawValue
  var params: [String]

  public init(method: ETHRequestMethods.RawValue, params: [String]) {
    self.method = method
    self.params = params
  }
}

public struct ETHTransactionParams: Codable {

}

public struct ETHTransactionPayload: Codable {
  var method: ETHRequestMethods.RawValue
  var params: ETHTransactionParams
}

public struct GatewayRequestPayload: Codable {
  var jsonrpc: String = "2.0"
  var method: ETHRequestMethods.RawValue
  var params: [String]
}

public struct Network: Codable {
  var id: String
  var chainId: String
  var name: String
  var createdAt: String
  var updatedAt: String
}

public struct RegisteredEventHandler {
  var handler: (_ data: Any) throws -> Void
  var once: Bool
}

public class PortalProvider {
  public var chainId: Chains.RawValue
  public var gatewayUrl: String
  public var portal: HttpRequester
  public var rpc: HttpRequester

  private var apiKey: String = "NO_API_KEY_PROVIDED"
  private var apiUrl: String = "https://api.portalhq.io"
  private var alchemyId: String = ""
  private var autoApprove: Bool = false
  private var events: Dictionary<Events.RawValue, [RegisteredEventHandler]> = [:]
  private var httpHost: String = "https://api.portalhq.io"
  private var infuraId: String = ""
  private var signer: MpcSigner
  private var address: String = ""

  private var signerMethods: [ETHRequestMethods.RawValue] = [
    ETHRequestMethods.Accounts.rawValue,
    ETHRequestMethods.ChainId.rawValue,
    ETHRequestMethods.PersonalSign.rawValue,
    ETHRequestMethods.RequestAccounts.rawValue,
    ETHRequestMethods.SendTransaction.rawValue,
    ETHRequestMethods.Sign.rawValue,
    ETHRequestMethods.SignTransaction.rawValue,
    ETHRequestMethods.SignTypedData.rawValue,
  ]

  private var walletMethods: [ETHRequestMethods.RawValue] = [
    ETHRequestMethods.WalletAddEthereumChain.rawValue,
    ETHRequestMethods.WalletGetPermissions.rawValue,
    ETHRequestMethods.WalletRegisterOnboarding.rawValue,
    ETHRequestMethods.WalletRequestPermissions.rawValue,
    ETHRequestMethods.WalletSwitchEthereumChain.rawValue,
    ETHRequestMethods.WalletWatchAsset.rawValue,
  ]

  public init(
    apiKey: String,
    chainId: Chains.RawValue,
    gatewayUrl: String,
    apiHost: String = "api.portalhq.io",
    autoApprove: Bool
  ) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayUrl = gatewayUrl
    self.autoApprove = autoApprove
    self.rpc = HttpRequester(baseUrl: gatewayUrl)

    // Other instance variables
    self.portal = HttpRequester(baseUrl: apiUrl)

    if (gatewayUrl.isEmpty) {
      throw ProviderInvalidArgumentError.invalidGatewayUrl
    }

    self.portal = HttpRequester(baseUrl: String(format: "https://%@", apiHost))
    self.signer = MpcSigner(keychain: PortalKeychain())
    self.dispatchConnect()
  }

  // ------ Public Functions

  public func emit(event: Events.RawValue, data: Any) -> PortalProvider {
    let registeredEventHandlers = self.events[event]

    if (registeredEventHandlers == nil) {
      print(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
      return self
    } else {
      // Invoke all registered handlers for the event
        do {
            for registeredEventHandler in registeredEventHandlers! {
              try registeredEventHandler.handler(data)
            }
        } catch {
            print("Error invoking registered handlers")
        }


      // Remove once instances
      events[event] = registeredEventHandlers?.filter(self.removeOnce)

      return self
    }
  }

  public func getApiKey() -> String {
    return apiKey
  }

  public func on(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
    if (self.events[event] == nil) {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: false
    ))

    return self
  }

  public func once(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) throws -> Void
  ) -> PortalProvider {
    if (events[event] == nil) {
      events[event] = []
    }

    events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: true
    ))

    return self
  }

  public func removeListener(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
    if (events[event] == nil) {
      print(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
    }

    events[event] = events[event]!.filter{ (registeredEventHandler) -> Bool in
      return true
    }

    return self
  }

  public func request(
    payload: ETHRequestPayload,
    completion: @escaping (Any) -> Void
  ) throws -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)

    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      try handleGatewayRequest(payload: payload) {
        (result: Any) -> Void in completion(result)
      }
    } else if (isSignerMethod) {
      let result = try handleSigningRequest(payload: payload)
      completion(result)
    } else {
      throw ProviderRpcError.unsupportedMethod
    }
  }

    public func setAddress(value: String) -> Void {
//        self.address = value
//        if (self.signer != nil && self.isMPC) {
//            (self.signer as MPCSigner).setAddress(value: value)
//        }
    }

    public func setChainId(value: Int) -> PortalProvider {
        self.chainId = value
        let hexChainId = String(format:"%02x", value)
        let provider = emit(event: Events.ChainChanged.rawValue, data: ["chainId": hexChainId])
        return provider
    }

  // ------ Private Functions

  private func getApproval(
    payload: ETHRequestPayload,
    completion: @escaping (_ approved: Bool) throws -> Void
  ) throws -> Void {
    do {
      print("autoApprove", autoApprove)
      if (autoApprove) {
        try completion(true)
      } else if (events[Events.PortalSigningRequested.rawValue] == nil) {
        throw ProviderSigningError.noBindingForSigningApprovalFound
      }

      // Bind to signing approval callbacks
      let _ = once(event: Events.PortalSigningApproved.rawValue, callback: { (approved) in
        try completion(true)
      }).once(event: Events.PortalSigningRejected.rawValue, callback: { approved in
        try completion(false)
      })
    }
  }

  private func handleGatewayRequest(
    payload: ETHRequestPayload,
    completion: @escaping (Any) -> Void
  ) throws -> Void {
//    try rpc.post(
//      path: "",
//      body: GatewayRequestPayload(method: payload.method, params: payload.params),
//      headers: [:]
//    ) { (result: Any) -> Void in
//      completion(result)
//    }
  }

  private func handleSigningRequest(
    payload: ETHRequestPayload
  ) throws -> Any {
    try getApproval(payload: payload) { approved in
      if (!approved) {
        throw ProviderSigningError.userDeclinedApproval
      }
    }

    return try signer.sign(
      payload: payload,
      provider: self
    )
  }

  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }

  private func dispatchConnect() -> Void {
    let hexChainId = String(format:"%02x", chainId)
    _ = emit(event: Events.Connect.rawValue, data: ["chaindId": hexChainId])
  }
}

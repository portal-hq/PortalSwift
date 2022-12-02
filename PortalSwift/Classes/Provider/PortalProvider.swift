//
//  PortalProvider.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation


/// A list of EVM networks.
public enum Chains: Int {
  case Mainnet = 1
  case Ropsten = 3
  case Rinkeby = 4
  case Goerli = 5
  case Kovan = 42
}

/// The provider events that can be listened to.
public enum Events: String {
  case ChainChanged = "chainChanged"
  case Connect = "connect"
  case Disconnect = "disconnect"
  case PortalSigningApproved = "portal_signingApproved"
  case PortalSigningRejected = "portal_signingRejected"
  case PortalSigningRequested = "portal_signingRequested"
}

/// All available provider methods.
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

/// A normal ETH request payload 
public struct ETHRequestPayload {
  var method: ETHRequestMethods.RawValue
  var params: [Any]
  var signature: String?

  public init(method: ETHRequestMethods.RawValue, params: [Any]) {
    self.method = method
    self.params = params
  }

  public init(method: ETHRequestMethods.RawValue, params: [Any], signature: String) {
    self.method = method
    self.params = params
    self.signature = signature
  }
}

public struct ETHTransactionParam: Codable {
  var from: String
  var to: String
  var gas: String
  var gasPrice: String
  var value: String
  var data: String
  
  public init(from: String, to: String, gas: String, gasPrice: String, value: String, data: String) {
    self.from = from
    self.to = to
    self.gas = gas
    self.gasPrice = gasPrice
    self.value = value
    self.data = data
  }
}

public struct ETHGatewayErrorResponse {
  var code: Int
  var message: String
}

public struct ETHGatewayResponse {
  var jsonrpc: String = "2.0"
  var id: Int?
  var result: String?
  var error: ETHGatewayErrorResponse?
}

public struct ETHTransactionPayload: Codable {
  var method: ETHRequestMethods.RawValue
  var params: [ETHTransactionParam]
  
  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam]) {
    self.method = method
    self.params = params
  }
}

public struct ETHAddressParam: Codable {
  var address: String
  
  public init(address: String) {
    self.address = address
  }
}

public struct ETHAddressPayload: Codable {
  var method: ETHRequestMethods.RawValue
  var params: [ETHAddressParam]
  
  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam]) {
    self.method = method
    self.params = params
  }
}

public struct GatewayRequestPayload {
  var jsonrpc: String = "2.0"
  var id: Int = 1
  var method: ETHRequestMethods.RawValue
  var params: Any
}

public struct Network: Codable {
  var id: String
  var chainId: String
  var name: String
  var createdAt: String
  var updatedAt: String
}
public var TransactionMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.Call.rawValue, // string
  ETHRequestMethods.EstimateGas.rawValue, // string
  ETHRequestMethods.GetStorageAt.rawValue, // data
  ETHRequestMethods.SubmitWork.rawValue, // boolean
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
]

public var signerMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.Accounts.rawValue,
  ETHRequestMethods.ChainId.rawValue,
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.RequestAccounts.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedData.rawValue,
]

public struct RegisteredEventHandler {
  var handler: (_ data: Any) throws -> Void
  var once: Bool
}

public struct RequestCompletionResult {
  public var method: String
  public var params: [Any]
  public var result: Any
}

public struct GatewayCompletionResult {
  public var method: String
  public var params: [Any]
  public var result: ETHGatewayResponse
}

public struct TransactionCompletionResult {
  public var method: String
  public var params: [ETHTransactionParam]
  public var result: Any
}

public struct AddressCompletionResult {
  public var method: String
  public var params: [ETHAddressParam]
  public var result: Any
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
        print("Error invoking registered handlers", error)
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
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)

    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) { (method: String, params: [Any], result: Any) -> Void in
        completion(Result(data: RequestCompletionResult(method: method, params: params, result: result)))
      }
    } else if (isSignerMethod) {
      handleSigningRequest(payload: payload) { (result: Any) -> Void in
        completion(Result(data: RequestCompletionResult(method: payload.method, params: payload.params, result: result)))
      }
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }
  
  public func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)

    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) {
        (method: String, params: [ETHTransactionParam], result: Any) -> Void in         completion(Result(data: TransactionCompletionResult(method: method, params: params, result: result)))
      }
    } else if (isSignerMethod) {
      handleSigningRequest(payload: payload) { (result: Any) -> Void in
        completion(Result(data: TransactionCompletionResult(method: payload.method, params: payload.params, result: result)))
      }
      
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }
  
  public func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)

    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) {
        (method: String, params: [ETHAddressParam], result: Any) -> Void in
        completion(Result(data: AddressCompletionResult(method: method, params: params, result: result)))
      }
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }

  public func setAddress(value: String) -> Void {
     self.address = value
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
    completion: @escaping (Result<Bool>) -> Void
  ) -> Void {
      if (autoApprove) {
        completion(Result(data: true))
      } else if (events[Events.PortalSigningRequested.rawValue] == nil) {
        completion(Result(error: ProviderSigningError.noBindingForSigningApprovalFound))
      }

      // Bind to signing approval callbacks
      let _ = once(event: Events.PortalSigningApproved.rawValue, callback: { (approved) in
          completion(Result(data: true))
      }).once(event: Events.PortalSigningRejected.rawValue, callback: { approved in
            completion(Result(data: false))
      })
  }
  
  private func getApproval(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<Bool>) -> Void
  ) -> Void {
      if (autoApprove) {
        completion(Result(data: true))
      } else if (events[Events.PortalSigningRequested.rawValue] == nil) {
        completion(Result(error: ProviderSigningError.noBindingForSigningApprovalFound))
      }

      // Bind to signing approval callbacks
      let _ = once(event: Events.PortalSigningApproved.rawValue, callback: { (approved) in
          completion(Result(data: true))
      }).once(event: Events.PortalSigningRejected.rawValue, callback: { approved in
            completion(Result(data: false))
      })
  }


  
  private func handleGatewayRequest(
    payload: ETHTransactionPayload,
    completion: @escaping (String, [ETHTransactionParam], Any) -> Void
  ) -> Void {
    let body: Dictionary<String, Any> = [
      "method": payload.method,
      "params": payload.params.map { (p: ETHTransactionParam) in
        return [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data,
        ]
      }
    ]
    let request = HttpRequest<ETHTransactionPayload, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"]
    )

    request.send() {
      (result: Result<Any>) in
      completion(payload.method, payload.params, result.data ?? "")
    }
  }
  
  private func handleGatewayRequest(
    payload: ETHAddressPayload,
    completion: @escaping (String, [ETHAddressParam], Any) -> Void
  ) -> Void {
    let body: Dictionary<String, Any> = [
      "method": payload.method,
      "params": payload.params.map { (p: ETHAddressParam) in
        return [ "address": p.address ]
      }
    ]
    let request = HttpRequest<ETHAddressParam, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"]
    )

    request.send() {
      (result: Result<Any>) in
      completion(payload.method, payload.params, result.data ?? "")
    }
  }
  
  private func handleGatewayRequest(
    payload: ETHRequestPayload,
    completion: @escaping (String, [Any], Any) -> Void
  ) -> Void {
    let body: Dictionary<String, Any> = ["method": payload.method, "params": payload.params]
    let request = HttpRequest<Dictionary<String, Any>, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"]
    )

    request.send() {
      (result: Result<Any>) in
      completion(payload.method, payload.params, result.data ?? "")
    }
  }
  
  private func handleSigningRequest(
    payload: ETHRequestPayload,
    completion: @escaping (Result<Any>) -> Void
  ) -> Void {
    getApproval(payload: payload) { result in
      if (!result.data!) {
        completion(Result(error: ProviderSigningError.userDeclinedApproval))
        return
      }
    }

    var signResult: Any
    do {
      signResult = try signer.sign(
        payload: payload,
        provider: self
      )
      completion(Result(data: signResult))
      return
    } catch {
      completion(Result(error: error))
    }
  }
  
  private func handleSigningRequest(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<Any>) -> Void
  ) -> Void {
    getApproval(payload: payload) { result in
      if (!result.data!) {
        completion(Result(error: ProviderSigningError.userDeclinedApproval))
        return
      }
    }
    let signResult: SignerResult
    do {
      signResult = try signer.sign(
        payload: payload,
        provider: self
      )
      completion(Result(data: signResult.signature!))
      return

    } catch {
      completion(Result(error: error))
    }
  }

  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }

  private func dispatchConnect() -> Void {
    let hexChainId = String(format:"%02x", chainId)
    _ = emit(event: Events.Connect.rawValue, data: ["chaindId": hexChainId])
  }
}

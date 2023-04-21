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
  case EstimateGas = "eth_estimateGas"
  case GasPrice = "eth_gasPrice"
  case GetBalance = "eth_getBalance"
  case GetBlockByHash = "eth_getBlockByHash"
  case GetBlockTransactionCountByNumber = "eth_getBlockTransactionCountByNumber"
  case GetCode = "eth_getCode"
  case GetStorageAt = "eth_getStorageAt"
  case GetTransactionByHash = "eth_getTransactionByHash"
  case GetTransactionCount = "eth_getTransactionCount"
  case GetTransactionReceipt = "eth_getTransactionReceipt"
  case GetUncleByBlockHashIndex = "eth_getUncleByBlockHashAndIndex"
  case GetUncleCountByBlockHash = "eth_getUncleCountByBlockHash"
  case GetUncleCountByBlockNumber = "eth_getUncleCountByBlockNumber"
  case NewBlockFilter = "eth_newBlockFilter"
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
  
  //  case UninstallFilter = "eth_uninstallFilter"
  //  case NewFilter = "eth_newFilter"
  //  case GetTransactionByBlockNumberAndIndex = "eth_getTransactionByBlockNumberAndIndex"
  //  case GetLogs = "eth_getLogs"
  //  case GetBlockByNumber = "eth_getBlockByNumber"
  //  case GetFilterLogs = "eth_getFilterLogs"
  //  case GetBlockTransactionCountByHash = "eth_getBlockTransactionCountByHash"
  //  case NetListening = "net_listening"
  //  case GetTransactionByBlockHashAndIndex = "eth_getTransactionByBlockHashAndIndex"
  //  case GetFilterLogs = "eth_getFilterLogs"
  //  case GetUncleByBlockNumberAndIndex = "eth_getUncleByBlockNumberAndIndex"
  
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

/// An ETH request payload where params is of type [Any].
public struct ETHRequestPayload {
  public var method: ETHRequestMethods.RawValue
  public var params: [Any]
  public var signature: String?
  
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
  
  public init(from: String, to: String, gas: String, gasPrice: String, value: String, data: String) {
    self.from = from
    self.to = to
    self.gas = gas
    self.gasPrice = gasPrice
    self.value = value
    self.data = data
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
  public init(from: String, to: String, gas: String, value: String, data: String, maxPriorityFeePerGas: String?, maxFeePerGas: String?) {
    self.from = from
    self.to = to
    self.gas = gas
    self.value = value
    self.data = data
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
  }
}

/// An error response from Gateway.
public struct ETHGatewayErrorResponse: Codable {
  public var code: Int
  public var message: String
  
}


/// A response from Gateway.
public struct ETHGatewayResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: String?
  public var error: ETHGatewayErrorResponse?
}

/// The payload for a transaction request.
public struct ETHTransactionPayload: Codable {
  public var method: ETHRequestMethods.RawValue
  public var params: [ETHTransactionParam]
  
  public init(method: ETHRequestMethods.RawValue, params: [ETHTransactionParam]) {
    self.method = method
    self.params = params
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
  public var method: ETHRequestMethods.RawValue
  public var params: [ETHAddressParam]
  
  public init(method: ETHRequestMethods.RawValue, params: [ETHAddressParam]) {
    self.method = method
    self.params = params
  }
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
  ETHRequestMethods.Accounts.rawValue,
  ETHRequestMethods.ChainId.rawValue,
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.RequestAccounts.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedDataV3.rawValue,
  ETHRequestMethods.SignTypedDataV4.rawValue
]

/// A registered event handler.
public struct RegisteredEventHandler {
  var handler: (_ data: Any) throws -> Void
  var once: Bool
}

/// The result of a request.
public struct RequestCompletionResult {
  public var method: String
  public var params: [Any]
  public var result: Any
}

/// The result of a transaction request.
public struct TransactionCompletionResult {
  public var method: String
  public var params: [ETHTransactionParam]
  public var result: Any
}

/// The result of an address request.
public struct AddressCompletionResult {
  public var method: String
  public var params: [ETHAddressParam]
  public var result: Any
}

/// Portal's EVM blockchain provider.
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
  private var mpcHost: String = "mpc.portalhq.io"
  private var version: String = "v3"
  private var mpcQueue: DispatchQueue
  
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
    chainId: Chains.RawValue,
    gatewayUrl: String,
    apiHost: String = "api.portalhq.io",
    autoApprove: Bool,
    mpcHost: String = "mpc.portalhq.io",
    version: String = "v3"
  ) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayUrl = gatewayUrl
    self.autoApprove = autoApprove
    self.rpc = HttpRequester(baseUrl: gatewayUrl)
    self.mpcHost = mpcHost
    self.version = version
    
    // Other instance variables
    self.portal = HttpRequester(baseUrl: apiUrl)
    
    if (gatewayUrl.isEmpty) {
      throw ProviderInvalidArgumentError.invalidGatewayUrl
    }
    
    self.portal = HttpRequester(baseUrl: String(format: "https://%@", apiHost))
    self.signer = MpcSigner(keychain: PortalKeychain(), mpcUrl: self.mpcHost, version: version)
    // Create a serial dispatch queue with a unique label
    self.mpcQueue =  DispatchQueue.global(qos: .background)
    self.dispatchConnect()
  }
  
  // ------ Public Functions
  
  /// Emits an event from the provider to registered event handlers.
  /// - Parameters:
  ///   - event: The event to be emitted.
  ///   - data: The data to pass to registered event handlers.
  /// - Returns: The Portal Provider instance.
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
  
  /// Retrieves the API key.
  /// - Returns: The client API key.
  public func getApiKey() -> String {
    return apiKey
  }
  
  /// Registers a callback for an event.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
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
  
  /// Registers a callback for an event. Deletes the registered callback after it's fired once.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
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
  
  /// Removes the callback for the specified event.
  /// - Parameters:
  ///   - event: A specific event from the list of Events.
  /// - Returns: An instance of Portal Provider.
  public func removeListener(
    event: Events.RawValue
  ) -> PortalProvider {
    if (events[event] == nil) {
      print(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
    }
    
    events[event] = nil
    
    return self
  }
  
  /// Makes a request.
  /// - Parameters:
  ///   - payload: A normal payload whose params are of type [Any].
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHRequestPayload,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)
    
    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) { (method: String, params: [Any], result: Result<Any>) -> Void in
        if (result.data != nil) {
          completion(Result(data: RequestCompletionResult(method: method, params: params, result: result.data!)))
        } else {
          completion(Result(error: result.error!))
        }
        
      }
    } else if (isSignerMethod) {
      handleSigningRequest(payload: payload) { (result: Result<SignerResult>) -> Void in
        completion(Result(data: RequestCompletionResult(method: payload.method, params: payload.params, result: result)))
      }
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }
  
  /// Makes a request.
  /// - Parameters:
  ///   - payload: A transaction payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)
    
    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) {
        (method: String, params: [ETHTransactionParam], result: Result<Any>) -> Void in
        guard result.error == nil else {
          completion(Result(error: result.error!))
          return
        }
        if (result.data != nil) {
          completion(Result(data: TransactionCompletionResult(method: method, params: params, result: result.data!)))
        }
      }
    } else if (isSignerMethod) {
      handleSigningRequest(payload: payload) { (result: Result<Any>) -> Void in
        guard result.error == nil else {
          completion(Result(error: result.error!))
          return
        }
        completion(Result(data: TransactionCompletionResult(method: payload.method, params: payload.params, result: result)))
      }
      
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }
  
  
  
  /// Makes a request.
  /// - Parameters:
  ///   - payload: An address payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void
  ) -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)
    
    if (!isSignerMethod && !payload.method.starts(with: "wallet_")) {
      handleGatewayRequest(payload: payload) {
        (method: String, params: [ETHAddressParam], result: Result<Any>) -> Void in
        if (result.data != nil) {
          completion(Result(data: AddressCompletionResult(method: method, params: params, result: result.data!)))
        } else {
          completion(Result(error: result.error!))
        }
      }
    } else {
      completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }
  
  /// Sets the public address.
  /// - Parameter value: The public address.
  /// - Returns: Void
  public func setAddress(value: String) -> Void {
    self.address = value
  }
  
  /// Sets the EVM network chainId.
  /// - Parameter value: The chainId.
  /// - Returns: An instance of Portal Provider.
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
    completion: @escaping (String, [ETHTransactionParam], Result<Any>) -> Void
  ) -> Void {
    // Create the body of the request.
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
    
    // Create the request.
    let request = HttpRequest<ETHGatewayResponse, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.GatewayRequest
    )
    
    // Attempt to send the request.
    request.send() { (result: Result<ETHGatewayResponse>) in
      if (result.data != nil) {
        completion(payload.method, payload.params, Result(data: result.data!))
      } else {
        return completion(payload.method, payload.params, Result(error: result.error!))
      }
    }
  }
  
  private func handleGatewayRequest(
    payload: ETHAddressPayload,
    completion: @escaping (String, [ETHAddressParam], Result<Any>) -> Void
  ) -> Void {
    // Create the body of the request.
    let body: Dictionary<String, Any> = [
      "method": payload.method,
      "params": payload.params.map { (p: ETHAddressParam) in
        return [ "address": p.address ]
      }
    ]
    
    // Create the request.
    let request = HttpRequest<ETHGatewayResponse, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.GatewayRequest
    )
    
    // Attempt to send the request.
    request.send() { (result: Result<ETHGatewayResponse>) in
      if (result.data != nil) {
        completion(payload.method, payload.params, Result(data: result.data!))
      } else {
        return completion(payload.method, payload.params, Result(error: result.error!))
      }
    }
  }
  
  private func handleGatewayRequest(
    payload: ETHRequestPayload,
    completion: @escaping (String, [Any], Result<Any>) -> Void
  ) -> Void {
    // Create the body of the request.
    let body: Dictionary<String, Any> = [
      "method": payload.method,
      "params": payload.params
    ]
    
    // Create the request.
    let request = HttpRequest<ETHGatewayResponse, Dictionary<String, Any>>(
      url: self.rpc.baseUrl,
      method: "POST",
      body: body,
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.GatewayRequest
    )
    
    // Attempt to send the request.
    request.send() { (result: Result<ETHGatewayResponse>) in
      if (result.data != nil) {
        completion(payload.method, payload.params, Result(data: result.data!))
      } else {
        return completion(payload.method, payload.params, Result(error: result.error!))
      }
    }
  }
  
  
  private func handleSigningRequest(
    payload: ETHRequestPayload,
    completion: @escaping (Result<SignerResult>) -> Void
  ) -> Void {
    getApproval(payload: payload) { result in
      guard result.error == nil else {
        completion(Result(error: result.error!))
        return
      }
      if (!(result.data!)) {
        completion(Result(error: ProviderSigningError.userDeclinedApproval))
        return
      }
    }
    
    
    self.mpcQueue.async {
      // This code will be executed in a background thread
      var signResult = SignerResult()
      do {
        signResult = try self.signer.sign(
          payload: payload,
          provider: self
        )
      } catch {
        DispatchQueue.main.async {
          completion(Result(error: error))
          return
        }
      }
      // When the work is done, call the completion handler
      DispatchQueue.main.async {
        completion(Result(data: signResult))
        return
      }
    }
  }
  
  private func handleSigningRequest(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<Any>) -> Void
  ) -> Void {
    
    getApproval(payload: payload) { result in
      guard result.error == nil else {
        completion(Result(error: result.error!))
        return
      }
      
      if (!result.data!) {
        completion(Result(error: ProviderSigningError.userDeclinedApproval))
        return
      }
    }
    self.mpcQueue.async {
      // This code will be executed in a background thread
      var signResult = SignerResult()
      do {
        signResult = try self.signer.sign(
          payload: payload,
          provider: self
        )
      } catch {
        DispatchQueue.main.async {
          completion(Result(error: error))
          return
        }
      }
      // When the work is done, call the completion handler
      DispatchQueue.main.async {
        completion(Result(data: signResult.signature))
        return
      }
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

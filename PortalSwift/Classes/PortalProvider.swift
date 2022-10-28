//
//  PortalProvider.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/12/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
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

// structs
struct ClientConfig: Codable {
  var alchemyId: String
  var autoApprove: Bool
  var enableMpc: Bool
  var infuraId: String
}

public struct ETHRequestPayload: Codable {
  var method: ETHRequestMethods.RawValue
  var params: [String]
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
  public var isMPC: Bool = false
  public var portal: HttpRequester

  private var apiKey: String = "NO_API_KEY_PROVIDED"
  private var apiUrl: String = "https://api.portalhq.io"
  private var alchemyId: String = ""
  private var autoApprove: Bool = false
  private var chainId: Chains.RawValue
  private var events: Dictionary<Events.RawValue, [RegisteredEventHandler]> = [:]
  private var httpHost: String = "https://api.portalhq.io"
  private var infuraId: String = ""
  private var rpc: HttpRequester
  private var signer: Signer?
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
  
    public init(apiKey: String, chainId: Chains.RawValue, gatewayUrl: String) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.chainId = chainId
    self.rpc = HttpRequester(baseUrl: gatewayUrl)
    
    // Other instance variables
    self.portal = HttpRequester(baseUrl: apiUrl)
    
      if (self.apiKey.isEmpty || apiKey.count == 0) {
          throw RpcProviderError(code: 4100)
      }

    do {
      // Get ClientConfig from server
      try portal.get(
        path: "/api/clients/config",
        headers: [
          "Authorization": String(format: "Bearer %@", apiKey),
        ]
      ) { (config: ClientConfig?) in
        if (config == nil) {
          // TODO: Handle errors
          return
        }
        
        // Set instance variables dependent on ClientConfig
        self.alchemyId = config!.alchemyId
        self.autoApprove = config!.autoApprove
        self.infuraId = config!.infuraId
        self.isMPC = config!.enableMpc
        
        self.signer = self.isMPC ? MPCSigner() : HttpSigner(portal: self.portal)
        self.dispatchConnect()
      }
    } catch {}
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
      self.events[event] = registeredEventHandlers?.filter(self.removeOnce)
      
      return self
    }
  }
  
  public func getApiKey() -> String {
    return self.apiKey
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
    completion: @escaping (_ response: Any?) -> Void
  ) throws -> Void {
    let isSignerMethod = signerMethods.contains(payload.method)
    
    if (!isSignerMethod && payload.method.starts(with: "eth_")) {
      try handleGatewayRequest(payload: payload) { response in
        completion(response)
      }
    } else if (!isSignerMethod && payload.method.starts(with: "wallet_")) {
      try handleWalletRequest(payload: payload) { response in
        completion(response)
      }
    } else if (isSignerMethod) {
      try handleSigningRequest(payload: payload) { signature in
        completion(signature)
      }
    } else {
        throw RpcProviderError(code: 4200)
    }
  }
    
    public func setAddress(value: String) -> Void {
        self.address = value
//    TODO: assign address to signer when we implement signer
//        if (self.signer != nil && self.isMPC) {
//            (self.signer as MPCSigner).setAddress(value: value)
//        }
    }
    
    public func setChainId(value: Int) -> PortalProvider {
        self.chainId = value
        let hexChainId = String(format:"%02x", self.chainId)
        let provider = self.emit(event: Events.ChainChanged.rawValue, data: ["chainId": hexChainId])
        return provider
    }
  
  // ------ Private Functions
  
  private func getApproval(
    payload: ETHRequestPayload,
    completion: @escaping (_ approved: Bool) throws -> Void
  ) throws -> Void {
    do {
      if (autoApprove) {
        try completion(true)
      } else if (events[Events.PortalSigningRequested.rawValue] == nil) {
          throw PortalProviderErrors.AutoApproveDisabled(PortalProviderErrorMessages.AutoApproveDisabled.rawValue)
          try completion(false)
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
    completion: @escaping (_ response: [String]?) -> Void
  ) throws -> Void {
    try rpc.post(
      path: "",
      body: GatewayRequestPayload(method: payload.method, params: payload.params),
      headers: [:]
    ) { (response: [String]?) -> Void in
      completion(response)
    }
  }
  
  private func handleSigningRequest(
    payload: ETHRequestPayload,
    completion: @escaping (Signature?) -> Void
  ) throws -> Void {
    try getApproval(payload: payload) { approved in
      if (!approved) {
          throw RpcProviderError(code: 4001)
        return
      }
      
      do {
          // we let the signer handle the EthRequests
        try self.signer?.sign(
          payload: payload,
          provider: self
        ) { (signature: Signature?) -> Void in
            completion(signature)
        }
      } catch {}
    }
  }
  
  private func handleWalletRequest(
    payload: ETHRequestPayload,
    completion: @escaping (_ response: String?) -> Void
  ) throws -> Void {
    try getApproval(payload: payload) { approved in
      if (!approved) {
          throw PortalProviderErrors.WalletRequestRejected(PortalProviderErrorMessages.WalletRequestRejected.rawValue)
        return
      }
      do {
        try self.portal.post(
          path: "/api/clients/wallet",
          body: payload,
          headers: [
            "Authorization": String(format: "Bearer %@", self.apiKey)
          ]
        ) { (response: String?) -> Void in
          completion(response)
        }
      } catch {}
    }
  }
  
  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }
    
    private func dispatchConnect() -> Void {
        let hexChainId = String(format:"%02x", self.chainId)
        let portalProvider = self.emit(event: Events.Connect.rawValue, data: ["chaindId": hexChainId])
    }
}

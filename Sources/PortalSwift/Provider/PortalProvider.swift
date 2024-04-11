//
//  PortalProvider.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

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
  public let autoApprove: Bool
  public var chainId: Chains.RawValue
  public var gatewayUrl: String

  private var events: [Events.RawValue: [RegisteredEventHandler]] = [:]
  private var gateway: HttpRequester
  private let gatewayConfig: [Int: String]
  private var keychain: PortalKeychain
  private var mpcQueue: DispatchQueue
  private var processedRequestIds: [String] = []
  private var processedSignatureIds: [String] = []
  private var portalApi: HttpRequester
  private let signer: MpcSigner
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
    chainId: Chains.RawValue,
    gatewayConfig: [Int: String],
    keychain: PortalKeychain,
    autoApprove: Bool,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil
  ) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayConfig = gatewayConfig
    self.keychain = keychain
    self.autoApprove = autoApprove

    // Other instance variables
    let apiUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.portalApi = HttpRequester(baseUrl: apiUrl)
    self.featureFlags = featureFlags

    self.signer = MpcSigner(apiKey: apiKey, keychain: keychain, mpcUrl: mpcHost, version: version, featureFlags: featureFlags)
    // Create a serial dispatch queue with a unique label
    self.mpcQueue = DispatchQueue.global(qos: .background)

    do {
      self.gatewayUrl = try PortalProvider.getGatewayUrl(gatewayConfig: gatewayConfig, chainId: chainId)
      self.gateway = HttpRequester(baseUrl: self.gatewayUrl)
    }

    self.dispatchConnect()
  }

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
    gatewayConfig: [Int: String],
    keychain: PortalKeychain,
    autoApprove: Bool,
    gateway: HttpRequester,
    apiHost: String = "api.portalhq.io",
    mpcHost: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil
  ) throws {
    // User-defined instance variables
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayConfig = gatewayConfig
    self.keychain = keychain
    self.autoApprove = autoApprove
    self.gateway = gateway
    self.gatewayUrl = gateway.baseUrl
    self.featureFlags = featureFlags

    // Other instance variables
    let apiUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.portalApi = HttpRequester(baseUrl: apiUrl)

    self.signer = MpcSigner(apiKey: apiKey, keychain: keychain, mpcUrl: mpcHost, version: version, featureFlags: featureFlags)
    // Create a serial dispatch queue with a unique label
    self.mpcQueue = DispatchQueue.global(qos: .background)

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

    if registeredEventHandlers == nil {
      print(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
      return self
    } else {
      // Invoke all registered handlers for the event
      do {
        for registeredEventHandler in registeredEventHandlers! {
          try registeredEventHandler.handler(data)
        }
      } catch {
        print("[Portal] Error invoking registered handlers", error)
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
  public func on(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
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
      print(String(format: "[Portal] Could not find any bindings for event '%@'. Ignoring...", event))
    }

    self.events[event] = nil

    return self
  }

  /// Makes a request.
  /// - Parameters:
  ///   - payload: A normal payload whose params are of type [Any].
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHRequestPayload,
    completion: @escaping (Result<RequestCompletionResult>) -> Void,
    connect: PortalConnect? = nil
  ) {
    let isSignerMethod = signerMethods.contains(payload.method)
    let id = UUID().uuidString

    // Handle changing chains
    if payload.method == ETHRequestMethods.WalletSwitchEthereumChain.rawValue {
      let param = payload.params[0] as! [String: String]

      if let chainIdString = param["chainId"]?.replacingOccurrences(of: "0x", with: "") {
        if let chainId = Int(chainIdString, radix: 16) {
          do {
            _ = try self.setChainId(value: Int(chainId), connect: connect)

            let completionResult = RequestCompletionResult(
              method: payload.method,
              params: payload.params,
              result: "null",
              id: ""
            )

            _ = self.emit(event: Events.PortalSignatureReceived.rawValue, data: completionResult)

            return completion(Result(data: completionResult))
          } catch {
            return completion(Result(error: error))
          }
        } else {
          return completion(Result(error: ProviderRpcError.unsupportedMethod))
        }
      } else {
        return completion(Result(error: ProviderRpcError.unsupportedMethod))
      }
    }

    let payloadWithId = ETHRequestPayload(method: payload.method, params: payload.params, id: id, chainId: payload.chainId ?? self.chainId)

    if !isSignerMethod, !payloadWithId.method.starts(with: "wallet_") {
      self.handleGatewayRequest(payload: payloadWithId, connect: connect) { (method: String, params: [Any], result: Result<Any>, id: String) in
        if id == payloadWithId.id, !self.processedSignatureIds.contains(id) {
          self.processedSignatureIds.append(id)
          if result.data != nil {
            return completion(Result(data: RequestCompletionResult(method: method, params: params, result: result.data!, id: id)))
          } else {
            return completion(Result(error: result.error!))
          }
        }
      }
    } else if isSignerMethod {
      self.handleSigningRequest(payload: payloadWithId, connect: connect) { (result: Result<SignerResult>, id: String) in
        if id == payloadWithId.id, !self.processedSignatureIds.contains(id) {
          self.processedSignatureIds.append(id)

          guard result.error == nil else {
            return completion(Result(error: result.error!))
          }

          // Trigger `portal_signatureReceived` event
          _ = self.emit(
            event: Events.PortalSignatureReceived.rawValue,
            data: RequestCompletionResult(
              method: payloadWithId.method,
              params: payloadWithId.params,
              result: result,
              id: id
            )
          )

          // Trigger completion handler
          return completion(Result(data: RequestCompletionResult(method: payloadWithId.method, params: payloadWithId.params, result: result, id: id)))
        }
      }
    } else {
      return completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }

  /// Makes a request.
  /// - Parameters:
  ///   - payload: A transaction payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void,
    connect: PortalConnect? = nil
  ) {
    let isSignerMethod = signerMethods.contains(payload.method)
    let id = UUID().uuidString

    let payloadWithId = ETHTransactionPayload(method: payload.method, params: payload.params, id: id, chainId: payload.chainId ?? self.chainId)

    if !isSignerMethod, !payloadWithId.method.starts(with: "wallet_") {
      self.handleGatewayRequest(payload: payloadWithId, connect: connect) {
        (method: String, params: [ETHTransactionParam], result: Result<Any>, id: String) in
        if id == payloadWithId.id, !self.processedSignatureIds.contains(id) {
          self.processedSignatureIds.append(id)

          guard result.error == nil else {
            return completion(Result(error: result.error!))
          }
          if result.data != nil {
            return completion(Result(data: TransactionCompletionResult(method: method, params: params, result: result.data!, id: payloadWithId.id!)))
          }
        }
      }
    } else if isSignerMethod {
      self.handleSigningRequest(payload: payloadWithId, connect: connect) { (result: Result<Any>, id: String) in
        if id == payloadWithId.id, !self.processedSignatureIds.contains(id) {
          self.processedSignatureIds.append(id)

          guard result.error == nil else {
            return completion(Result(error: result.error!))
          }

          // Trigger `portal_signatureReceived` event
          _ = self.emit(
            event: Events.PortalSignatureReceived.rawValue,
            data: RequestCompletionResult(
              method: payloadWithId.method,
              params: payloadWithId.params,
              result: result,
              id: payloadWithId.id!
            )
          )

          // Trigger completion handler
          return completion(Result(data: TransactionCompletionResult(method: payloadWithId.method, params: payloadWithId.params, result: result, id: payloadWithId.id!)))
        }
      }
    } else {
      return completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }

  /// Makes a request.
  /// - Parameters:
  ///   - payload: An address payload.
  ///   - completion: Resolves with a Result.
  /// - Returns: Void
  public func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void,
    connect: PortalConnect? = nil
  ) {
    let isSignerMethod = signerMethods.contains(payload.method)
    let id = UUID().uuidString

    let payloadWithId = ETHAddressPayload(method: payload.method, params: payload.params, id: id, chainId: payload.chainId ?? self.chainId)

    if !isSignerMethod, !payloadWithId.method.starts(with: "wallet_") {
      self.handleGatewayRequest(payload: payloadWithId, connect: connect) {
        (method: String, params: [ETHAddressParam], result: Result<Any>, id: String) in
        if id == payloadWithId.id, !self.processedSignatureIds.contains(id) {
          self.processedSignatureIds.append(id)

          if result.data != nil {
            return completion(Result(data: AddressCompletionResult(method: method, params: params, result: result.data!, id: id)))
          } else {
            return completion(Result(error: result.error!))
          }
        }
      }
    } else {
      return completion(Result(error: ProviderRpcError.unsupportedMethod))
    }
  }

  /// Sets the EVM network chainId.
  /// - Parameter value: The chainId.
  /// - Returns: An instance of Portal Provider.
  public func setChainId(value: Int, connect: PortalConnect? = nil) throws -> PortalProvider {
    self.chainId = value
    let hexChainId = String(format: "%02x", value)

    let provider = self.emit(event: Events.ChainChanged.rawValue, data: ["chainId": hexChainId])

    do {
      let gatewayUrl = try PortalProvider.getGatewayUrl(gatewayConfig: self.gatewayConfig, chainId: value)
      self.gatewayUrl = gatewayUrl
      self.gateway = HttpRequester(baseUrl: gatewayUrl)
    } catch {
      throw ProviderInvalidArgumentError.invalidGatewayUrl
    }
    self.chainId = value

    if connect != nil {
      connect?.emit(event: Events.PortalConnectChainChanged.rawValue, data: value)
    }
    return provider
  }

  // ------ Private Functions
  private func getApproval(
    payload: ETHRequestPayload,
    completion: @escaping (Result<Bool>) -> Void,
    connect: PortalConnect? = nil
  ) {
    if self.autoApprove {
      return completion(Result(data: true))
    } else if connect == nil, self.events[Events.PortalSigningRequested.rawValue] == nil {
      return completion(Result(error: ProviderSigningError.noBindingForSigningApprovalFound))
    }

    // Bind to signing approval callbacks
    _ = self.on(event: Events.PortalSigningApproved.rawValue, callback: { approved in
      if approved is ETHRequestPayload {
        let approvedPayload = approved as! ETHRequestPayload

        if approvedPayload.id == payload.id, !self.processedRequestIds.contains(payload.id!) {
          self.processedRequestIds.append(payload.id!)

          // If the approved event is fired
          return completion(Result(data: true))
        }
      }
    }).on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
      if approved is ETHRequestPayload {
        let rejectedPayload = approved as! ETHRequestPayload

        if rejectedPayload.id == payload.id, !self.processedRequestIds.contains(payload.id!) {
          self.processedRequestIds.append(payload.id!)
          // If the rejected event is fired
          return completion(Result(data: false))
        }
      }
    })

    if connect != nil {
      connect!.emit(event: Events.PortalConnectSigningRequested.rawValue, data: payload)
    } else {
      // Execute event handlers
      let handlers = self.events[Events.PortalSigningRequested.rawValue]

      // Fail if there are no handlers
      if handlers == nil || handlers!.isEmpty {
        return completion(Result(data: false))
      }

      do {
        // Loop over the event handlers
        for eventHandler in handlers! {
          try eventHandler.handler(payload)
        }
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  private func getApproval(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<Bool>) -> Void,
    connect: PortalConnect? = nil
  ) {
    if self.autoApprove {
      return completion(Result(data: true))
    } else if connect == nil, self.events[Events.PortalSigningRequested.rawValue] == nil {
      return completion(Result(error: ProviderSigningError.noBindingForSigningApprovalFound))
    }

    // Bind to signing approval callbacks
    _ = self.on(event: Events.PortalSigningApproved.rawValue, callback: { approved in
      if approved is ETHTransactionPayload {
        let approvedPayload = approved as! ETHTransactionPayload

        if approvedPayload.id == payload.id, !self.processedRequestIds.contains(payload.id!) {
          self.processedRequestIds.append(payload.id!)
          // If the approved event is fired
          return completion(Result(data: true))
        }
      }
    }).on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
      if approved is ETHTransactionPayload {
        let rejectedPayload = approved as! ETHTransactionPayload

        if rejectedPayload.id == payload.id, !self.processedRequestIds.contains(payload.id!) {
          self.processedRequestIds.append(payload.id!)
          // If the rejected event is fired
          return completion(Result(data: false))
        }
      }
    })

    if connect != nil {
      connect!.emit(event: Events.PortalConnectSigningRequested.rawValue, data: payload)
    } else {
      // Execute event handlers
      let handlers = self.events[Events.PortalSigningRequested.rawValue]

      // Fail if there are no handlers
      if handlers == nil || handlers!.isEmpty {
        return completion(Result(data: false))
      }

      do {
        // Loop over the event handlers
        for eventHandler in handlers! {
          try eventHandler.handler(payload)
        }
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  private func handleGatewayRequest(
    payload: ETHTransactionPayload,
    completion: @escaping (String, [ETHTransactionParam], Result<Any>, String) -> Void,
    connect _: PortalConnect? = nil
  ) {
    // Create the body of the request.
    let body: [String: Any] = [
      "method": payload.method,
      "params": payload.params.map { (p: ETHTransactionParam) in
        [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data,
        ]
      },
    ]

    do {
      try self.gateway.post(
        path: "/",
        body: body,
        headers: ["Content-Type": "application/json"],
        requestType: HttpRequestType.GatewayRequest
      ) { (result: Result<ETHGatewayResponse>) in
        if result.data != nil {
          completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
        } else {
          completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
        }
      }
    } catch {
      completion(payload.method, payload.params, Result(error: error), payload.id!)
    }
  }

  private func handleGatewayRequest(
    payload: ETHAddressPayload,
    completion: @escaping (String, [ETHAddressParam], Result<Any>, String) -> Void,
    connect _: PortalConnect? = nil
  ) {
    // Create the body of the request.
    let body: [String: Any] = [
      "method": payload.method,
      "params": payload.params.map { (p: ETHAddressParam) in
        ["address": p.address]
      },
    ]

    do {
      try self.gateway.post(
        path: "/",
        body: body,
        headers: ["Content-Type": "application/json"],
        requestType: HttpRequestType.GatewayRequest
      ) { (result: Result<ETHGatewayResponse>) in
        if result.data != nil {
          completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
        } else {
          completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
        }
      }
    } catch {
      completion(payload.method, payload.params, Result(error: error), payload.id!)
    }
  }

  private func handleGatewayRequest(
    payload: ETHRequestPayload,
    completion: @escaping (String, [Any], Result<Any>, String) -> Void,
    connect _: PortalConnect? = nil
  ) {
    // Create the body of the request.
    let body: [String: Any] = [
      "method": payload.method,
      "params": payload.params,
    ]

    do {
      switch payload.method {
      case ETHRequestMethods.GetBlockByHash.rawValue, ETHRequestMethods.GetUncleByBlockHashIndex.rawValue, ETHRequestMethods.GetUncleByBlockNumberAndIndex.rawValue, ETHRequestMethods.GetBlockByNumber.rawValue:
        if let params = payload.params as? [Any], params.count > 1, let elementAtIndex1 = params[1] as? Bool, elementAtIndex1 {
          // The element at index 1 is a Bool and evaluates to true
          try self.gateway.post(
            path: "/",
            body: body,
            headers: ["Content-Type": "application/json"],
            requestType: HttpRequestType.GatewayRequest
          ) { (result: Result<BlockDataResponseTrue>) in
            if result.data != nil {
              completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
            } else {
              completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
            }
          }
        } else {
          try self.gateway.post(
            path: "/",
            body: body,
            headers: ["Content-Type": "application/json"],
            requestType: HttpRequestType.GatewayRequest
          ) { (result: Result<BlockDataResponseFalse>) in
            if result.data != nil {
              completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
            } else {
              completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
            }
          }
        }
      case ETHRequestMethods.GetTransactionReceipt.rawValue, ETHRequestMethods.GetTransactionByHash.rawValue, ETHRequestMethods.GetTransactionByBlockNumberAndIndex.rawValue,
           ETHRequestMethods.GetTransactionByBlockHashAndIndex.rawValue:
        try self.gateway.post(
          path: "/",
          body: body,
          headers: ["Content-Type": "application/json"],
          requestType: HttpRequestType.GatewayRequest
        ) { (result: Result<EthTransactionResponse>) in
          if result.data != nil {
            completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
          } else {
            completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
          }
        }
      case ETHRequestMethods.NetListening.rawValue, ETHRequestMethods.UninstallFilter.rawValue:
        try self.gateway.post(
          path: "/",
          body: body,
          headers: ["Content-Type": "application/json"],
          requestType: HttpRequestType.GatewayRequest
        ) { (result: Result<EthBoolResponse>) in
          if result.data != nil {
            completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
          } else {
            completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
          }
        }
      case ETHRequestMethods.GetLogs.rawValue, ETHRequestMethods.GetFilterLogs.rawValue, ETHRequestMethods.GetFilterChanges.rawValue:
        try self.gateway.post(
          path: "/",
          body: body,
          headers: ["Content-Type": "application/json"],
          requestType: HttpRequestType.GatewayRequest
        ) { (result: Result<LogsResponse>) in
          if result.data != nil {
            completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
          } else {
            completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
          }
        }
      default:
        try self.gateway.post(
          path: "/",
          body: body,
          headers: ["Content-Type": "application/json"],
          requestType: HttpRequestType.GatewayRequest
        ) { (result: Result<ETHGatewayResponse>) in
          if result.data != nil {
            completion(payload.method, payload.params, Result(data: result.data!), payload.id!)
          } else {
            completion(payload.method, payload.params, Result(error: result.error!), payload.id!)
          }
        }
      }
    } catch {
      completion(payload.method, payload.params, Result(error: error), payload.id!)
    }
  }

  private func handleSigningRequest(
    payload: ETHRequestPayload,
    completion: @escaping (Result<SignerResult>, String) -> Void,
    connect: PortalConnect? = nil
  ) {
    self.getApproval(payload: payload, connect: connect) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!), payload.id!)
      }
      if result.data != true {
        return completion(Result(error: ProviderSigningError.userDeclinedApproval), payload.id!)
      } else {
        self.mpcQueue.async {
          // This code will be executed in a background thread
          var signResult = SignerResult()
          do {
            signResult = try self.signer.sign(
              payload: payload,
              provider: self
            )
            // When the work is done, call the completion handler
            DispatchQueue.main.async {
              completion(Result(data: signResult), payload.id!)
            }

          } catch {
            DispatchQueue.main.async {
              completion(Result(error: error), payload.id!)
            }
          }
        }
      }
    }
  }

  private func handleSigningRequest(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<Any>, String) -> Void,
    connect: PortalConnect? = nil
  ) {
    self.getApproval(payload: payload, connect: connect) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!), payload.id!)
      }

      if !result.data! {
        return completion(Result(error: ProviderSigningError.userDeclinedApproval), payload.id!)
      } else {
        self.mpcQueue.async {
          // This code will be executed in a background thread
          var signResult = SignerResult()
          do {
            signResult = try self.signer.sign(
              payload: payload,
              provider: self
            )
            // When the work is done, call the completion handler
            DispatchQueue.main.async {
              completion(Result(data: signResult.signature!), payload.id!)
            }
          } catch {
            DispatchQueue.main.async {
              completion(Result(error: error), payload.id!)
            }
          }
        }
      }
    }
  }

  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    !registeredEventHandler.once
  }

  private func dispatchConnect() {
    let hexChainId = String(format: "%02x", chainId)
    _ = self.emit(event: Events.Connect.rawValue, data: ["chainId": hexChainId])
  }

  /// Determines the appropriate Gateway URL to use for the current chainId
  /// - Parameters:
  ///   - gatewayConfig: A dictionary of chainIds (keys) and gateway URLs (values).
  ///   - chainId: The chainId we should use, such as 11155111 (Sepolia).
  /// - Throws: PortalArgumentError.noGatewayConfigForChain with the chainId.
  /// - Returns: The URL to be used for Gateway requests.
  static func getGatewayUrl(gatewayConfig: [Int: String], chainId: Int) throws -> String {
    if gatewayConfig[chainId] == nil {
      throw PortalArgumentError.noGatewayConfigForChain(chainId: chainId)
    }

    return gatewayConfig[chainId]!
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
public struct ETHGatewayResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: String?
  public var error: ETHGatewayErrorResponse?
}

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
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.RequestAccounts.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedDataV3.rawValue,
  ETHRequestMethods.SignTypedDataV4.rawValue,
]

/// A registered event handler.
public struct RegisteredEventHandler {
  var handler: (_ data: Any) throws -> Void
  var once: Bool
}

/// The result of a request.
public struct RequestCompletionResult {
  public init(method: String, params: [Any], result: Any, id: String) {
    self.method = method
    self.params = params
    self.result = result
    self.id = id
  }

  public var method: String
  public var params: [Any]
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

// The specific return types for the 17 methods from the gateway that don't return strings
public struct BlockDataResponseFalse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: BlockData?
  public var error: ETHGatewayErrorResponse?
}

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

public struct BlockDataResponseTrue: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: BlockDataTrue?
  public var error: ETHGatewayErrorResponse?
}

public struct EthTransactionResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: TransactionData?
  public var error: ETHGatewayErrorResponse?
}

public struct EthBoolResponse: Codable {
  public var jsonrpc: String = "2.0"
  public var id: Int?
  public var result: Bool?
  public var error: ETHGatewayErrorResponse?
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
  public var error: ETHGatewayErrorResponse?
}

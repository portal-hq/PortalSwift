//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//

import AnyCodable
import Foundation

/// A list of JSON-RPC signing methods.
public var signMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedDataV3.rawValue,
  ETHRequestMethods.SignTypedDataV4.rawValue
]

public class PortalConnect: EventBus {
  public var address: String? {
    self.provider.address
  }

  public var chainId: Int

  @available(*, deprecated, renamed: "chainId", message: "Please use the public var on the PortalConnect instance.")
  public func setChainId(value: Int) throws {
    _ = try self.provider.setChainId(value: value, connect: self)
  }

  public var connected: Bool {
    self.client?.isConnected ?? false
  }

  public var client: WebSocketClient? = nil
  public var uri: String?

  private let apiKey: String
  private let logger = PortalLogger()
  private let provider: PortalProvider
  private var rpcConfig: [String: String]
  private var topic: String?
  private let webSocketServer: String

  public init(
    _ apiKey: String,
    _ chainId: Int,
    _ keychain: PortalKeychain,
    _ rpcConfig: [String: String],
    _ featureFlags: FeatureFlags?,
    _ webSocketServer: String = "connect.portalhq.io",
    _ autoApprove: Bool = false,
    _ apiHost: String = "api.portalhq.io",
    _ mpcHost: String = "mpc.portalhq.io",
    _ version: String = "v6"
  ) throws {
    self.apiKey = apiKey
    self.chainId = chainId
    self.webSocketServer = webSocketServer
    self.rpcConfig = rpcConfig

    // Initialize the PortalProvider
    self.provider = try PortalProvider(
      apiKey: apiKey,
      rpcConfig: rpcConfig,
      keychain: keychain,
      autoApprove: autoApprove,
      apiHost: apiHost,
      mpcHost: mpcHost,
      version: version,
      featureFlags: featureFlags
    )

    super.init(label: "PortalConnect")

    // Set up webSocketClient
    let connectionString = webSocketServer.starts(with: "localhost") ? "ws://\(webSocketServer)" : "wss://\(webSocketServer)"
    self.client = WebSocketClient(
      apiKey: apiKey,
      connect: self,
      webSocketServer: connectionString
    )

    guard self.address != nil else {
      print("[PortalConnect] ⚠️ Address not found in Keychain. This may cause some features not to work as expected.")
      return
    }

    // Fired by the Provider
    on(event: Events.PortalConnectSigningRequested.rawValue) { payload in
      self.emit(event: Events.PortalSigningRequested.rawValue, data: payload)
    }

    on(event: Events.PortalConnectChainChanged.rawValue) { payload in
      let event = ChainChangedMessage(
        event: "portal_chainChanged",
        data: ChainChangedData(
          topic: self.topic,
          uri: self.uri,
          chainId: String(payload as! Int)
        )
      )
      do {
        let message = try JSONEncoder().encode(event)

        self.client?.send(message)
      } catch {
        print("[PortalConnect] Error encoding PortalChainChanged: \(error)")
      }
    }

    // Fired by SDK Consumers
    on(event: Events.PortalSigningApproved.rawValue) { payload in
      _ = self.provider.emit(event: Events.PortalSigningApproved.rawValue, data: payload)
    }

    on(event: Events.PortalSigningRejected.rawValue) { payload in
      _ = self.provider.emit(event: Events.PortalSigningRejected.rawValue, data: payload)
    }
  }

  @available(*, deprecated, renamed: "createPortalConnectInstance", message: "Please use portal.createPortalConnectInstance().")
  public convenience init(
    _ apiKey: String,
    _ chainId: Int,
    _ keychain: PortalKeychain,
    _ gatewayConfig: [Int: String],
    _ featureFlags: FeatureFlags?,
    _ webSocketServer: String = "connect.portalhq.io",
    _ autoApprove: Bool = false,
    _ apiHost: String = "api.portalhq.io",
    _ mpcHost: String = "mpc.portalhq.io",
    _ version: String = "v6"
  ) throws {
    //  Handle the legacy use case of using Ethereum references as keys
    let rpcConfig: [String: String] = Dictionary(gatewayConfig.map { key, value in
      let newKey = "eip155:\(key)"
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })

    try self.init(
      apiKey,
      chainId,
      keychain,
      rpcConfig,
      featureFlags,
      webSocketServer,
      autoApprove,
      apiHost,
      mpcHost,
      version
    )
  }

  deinit {
    client?.sendFinalMessageAndDisconnect()
  }

  public func connect(_ uri: String) {
    do {
      self.logger.info("⚠️ PortalConnect.connect() - Trying to connect.")
      if self.connected, uri == self.uri {
        self.logger.info("PortalConnect.connect() - Connection is already in progress or established. Ignoring request to connect.")
        return
      }
      if self.client == nil {
        self.client = WebSocketClient(apiKey: self.apiKey, connect: self, webSocketServer: self.webSocketServer)
      } else {
        self.unbindClientEvents()
      }
      guard let client = self.client else {
        throw PortalConnectError.noWebSocketClientFound
      }

      self.uri = uri
      client.resetEventBus()

      self.bindClientEvents()

      self.logger.info("⚠️ PortalConnect.connect() - Invoking client.connect()")
      client.connect(uri: uri)
    } catch {
      self.logger.error("⚠️ PortalConnect.connect() - Unable to connect: \(error.localizedDescription)")
    }
  }

  public func disconnect(_ userInitiated: Bool = false) {
    self.client?.disconnect(userInitiated)
  }

  public func addChainsToProposal(data: ConnectData) -> ConnectData {
    let chainsToAdd = self.rpcConfig.keys

    // Convert existing chains and chainsToAdd to sets
    let existingChainsSet = Set<String>(data.params.params.requiredNamespaces.eip155?.chains ?? [])
    let chainsToAddSet = Set(chainsToAdd)

    // Merge the two sets and convert back to an array
    let newChains = Array(existingChainsSet.union(chainsToAddSet))

    // Create a new Eip155 instance with the updated chains
    let newEip155 = Eip155(chains: newChains,
                           methods: data.params.params.requiredNamespaces.eip155?.methods ?? [],
                           events: data.params.params.requiredNamespaces.eip155?.events ?? [],
                           rpcMap: data.params.params.requiredNamespaces.eip155?.rpcMap ?? [:])

    // Create a new Namespaces instance with the updated Eip155
    let newNamespaces = Namespaces(eip155: newEip155)

    // Create a new Params instance with the updated Namespaces
    let newParams = Params(id: data.params.id,
                           pairingTopic: data.params.params.pairingTopic,
                           expiry: data.params.params.expiry,
                           requiredNamespaces: newNamespaces,
                           optionalNamespaces: data.params.params.optionalNamespaces,
                           relays: data.params.params.relays,
                           proposer: data.params.params.proposer, verifyContext: data.params.params.verifyContext)

    let newProposal = SessionProposal(id: data.params.id, params: newParams)
    // Create a new ConnectData instance with the updated Params
    let newConnectData = ConnectData(id: data.id,
                                     topic: data.topic,
                                     params: newProposal)

    return newConnectData
  }

  public func emitGetSessionRequest(requestId: String, topic: String) {
    let request = [
      "event": "portal_getSessionRequest",
      "data": [
        "requestId": requestId,
        "topic": topic
      ]
    ] as [String: Any]

    do {
      let jsonData = try JSONSerialization.data(withJSONObject: request, options: [])
      let jsonString = String(data: jsonData, encoding: .utf8)
      self.client?.send(jsonString ?? "")
    } catch {
      print("[PortalConnect] Error serializing JSON for getSessionRequest: \(error)")
    }
  }

  func handleDappSessionRequested(data: ConnectData) {
    once(event: Events.PortalDappSessionApproved.rawValue) { [weak self] callbackData in
      guard let self = self else { return }
      guard let connectData = callbackData as? ConnectData else {
        print("[PortalConnect] Received data is not of type ConnectData")
        self.emit(event: Events.ConnectError.rawValue, data: ErrorData(id: data.id, topic: data.topic, params: ConnectError(message: "Received data is not of type ConnectData", code: 504)))
        return
      }
      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionApproved",
        data: SessionResponseData(
          id: connectData.id,
          topic: connectData.topic,
          address: self.address!,
          chainId: String(self.chainId),
          params: connectData.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)

        self.client?.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }

    once(event: Events.PortalDappSessionRejected.rawValue) { [weak self] callbackData in
      guard let self = self else { return }
      guard let connectData = callbackData as? ConnectData else {
        print("[PortalConnect] Received data is not of type ConnectData")
        self.emit(event: Events.ConnectError.rawValue, data: ErrorData(id: data.id, topic: data.topic, params: ConnectError(message: "Received data is not of type ConnectData", code: 504)))
        return
      }

      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionRejected",
        data: SessionResponseData(
          id: connectData.id,
          topic: connectData.topic,
          address: self.address!,
          chainId: String(self.chainId),
          params: connectData.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client?.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
    }

    emit(event: Events.PortalDappSessionRequested.rawValue, data: data)
  }

  func handleClose() {
    self.topic = nil
    self.client?.topic = nil

    self.client?.close()
  }

  func handleConnected(data: ConnectedData) {
    self.topic = data.topic
    self.client?.topic = data.topic

    emit(event: Events.Connect.rawValue, data: data)
  }

  func handleDisconnected(data: DisconnectData) {
    self.topic = nil
    self.client?.topic = nil

    self.client?.close()
    emit(event: Events.Disconnect.rawValue, data: data)
  }

  func handleError(data: ErrorData) {
    emit(event: Events.ConnectError.rawValue, data: data)
  }

  func handleConnectError(data: ConnectError) {
    let errorData = ErrorData(id: "0", topic: self.topic ?? "0", params: data)
    emit(event: Events.ConnectError.rawValue, data: errorData)
  }

  func handleSessionRequest(data: SessionRequestData) {
    Task {
      do {
        let (id, method, params, topic, chainId) = (
          data.id,
          data.params.request.method,
          data.params.request.params,
          data.topic,
          data.params.chainId
        )
        print("[handleSessionRequest]", id, topic)

        guard let client = self.client else {
          throw PortalConnectError.noWebSocketClientFound
        }

        on(event: Events.PortalSigningRejected.rawValue) { [weak self] _ in
          guard let self = self else { return }
          let event = SignatureReceivedMessage(
            event: "portal_signatureRejected",
            data: SignatureReceivedData(
              topic: topic,
              transactionHash: "",
              transactionId: id
            )
          )
          do {
            let message = try JSONEncoder().encode(event)
            self.client?.send(message)
          } catch {
            self.logger.error("⚠️ PortalConnect.on(portal_signingRejected) -  Error encoding SignatureReceivedMessage: \(error)")
          }
        }

        // use the default chain when there is no chainId sent from Wallet Connect
        let newChainId = chainId ?? self.chainId
        let result = try await self.handleProviderRequest(method: method, params: params, chainId: newChainId)

        guard let signature = result as? String else {
          throw PortalConnectError.unableToParseSignResponse
        }

        let event = SignatureReceivedMessage(
          event: "signatureReceived",
          data: SignatureReceivedData(
            topic: topic,
            transactionHash: signature,
            transactionId: id
          )
        )

        let message = try JSONEncoder().encode(event)

        client.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
          self.emit(event: Events.PortalSignatureReceived.rawValue, data: signature)
        }
      } catch {
        self.logger.error("⚠️ Error processing session request: \(error)")
      }
    }
  }

  func handleSessionRequestAddress(data: SessionRequestAddressData) {
    Task {
      do {
        let (id, method, params, topic, chainId) = (
          data.id,
          data.params.request.method,
          data.params.request.params,
          data.topic,
          data.params.chainId
        )

        on(event: Events.PortalSigningRejected.rawValue) { [weak self] _ in
          guard let self = self else { return }
          let event = SignatureReceivedMessage(
            event: "portal_signatureRejected",
            data: SignatureReceivedData(
              topic: topic,
              transactionHash: "",
              transactionId: id
            )
          )
          do {
            let message = try JSONEncoder().encode(event)
            self.client?.send(message)
          } catch {
            self.logger.error("⚠️ PortalConnect.on(portal_signingRejected) -  Error encoding SignatureReceivedMessage: \(error)")
          }
        }

        // use the default chain when there is no chainId sent from Wallet Connect
        let newChainId = chainId ?? self.chainId
        let result = try await self.handleProviderRequest(method: method, params: params, chainId: newChainId)

        guard let signature = result as? String else {
          throw PortalConnectError.unableToParseSignResponse
        }

        let event = SignatureReceivedMessage(
          event: "signatureReceived",
          data: SignatureReceivedData(
            topic: topic,
            transactionHash: signature,
            transactionId: id
          )
        )

        let message = try JSONEncoder().encode(event)
        self.client?.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
//          self.emit(event: Events.PortalSignatureReceived.rawValue, data: result.data!)
        }
      } catch {
        self.logger.error("⚠️ Error processing session request: \(error)")
      }
    }
  }

  func handleSessionRequestTransaction(data: SessionRequestTransactionData) {
    Task {
      do {
        let (id, method, params, topic, chainId) = (
          data.id,
          data.params.request.method,
          data.params.request.params,
          data.topic,
          data.params.chainId
        )

        print("⚠️ Method: \(method), Params: \(params)")

        on(event: Events.PortalSigningRejected.rawValue) { [weak self] _ in
          guard let self = self else { return }
          let event = SignatureReceivedMessage(
            event: "portal_signatureRejected",
            data: SignatureReceivedData(
              topic: topic,
              transactionHash: "",
              transactionId: id
            )
          )
          do {
            let message = try JSONEncoder().encode(event)
            self.client?.send(message)
          } catch {
            self.logger.error("⚠️ PortalConnect.on(portal_signingRejected) -  Error encoding SignatureReceivedMessage: \(error)")
          }
        }

        // use the default chain when there is no chainId sent from Wallet Connect
        let newChainId = chainId ?? self.chainId
        let response = try await self.handleProviderRequest(method: method, params: params, chainId: newChainId)

        guard let transactionHash = response as? String else {
          throw PortalConnectError.unableToParseSignResponse
        }

        let event = SignatureReceivedMessage(
          event: "signatureReceived",
          data: SignatureReceivedData(
            topic: topic,
            transactionHash: transactionHash,
            transactionId: id
          )
        )

        let message = try JSONEncoder().encode(event)
        self.client?.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
          self.emit(event: Events.PortalSignatureReceived.rawValue, data: transactionHash)
        }
      } catch {
        self.logger.error("⚠️ Error processing session request: \(error)")
      }
    }
  }

  public func viewWillDisappear() {
    self.client?.sendFinalMessageAndDisconnect()
  }

  private func unbindClientEvents() {
    self.client?.off("close")
    self.client?.off("portal_dappSessionRequested")
    self.client?.off("connected")
    self.client?.off("disconnected")
    self.client?.off("error")
    self.client?.off("portal_connectError")
    self.client?.off("session_request")
    self.client?.off("session_request_address")
    self.client?.off("session_request_transaction")
  }

  private func bindClientEvents() {
    self.client?.on("close", self.handleClose)
    self.client?.on("portal_dappSessionRequested", self.handleDappSessionRequested)
    self.client?.on("connected", self.handleConnected)
    self.client?.on("disconnected", self.handleDisconnected)
    self.client?.on("error", self.handleConnectError)
    self.client?.on("portal_connectError", self.handleError)
    self.client?.on("session_request", self.handleSessionRequest)
    self.client?.on("session_request_address", self.handleSessionRequestAddress)
    self.client?.on("session_request_transaction", self.handleSessionRequestTransaction)
  }

  private func handleProviderRequest(method: String, params: [Any], chainId: Int) async throws -> Any {
    let encodedParams = params.map { param in
      AnyCodable(param)
    }
    guard let method = PortalRequestMethod(rawValue: method) else {
      throw PortalConnectError.unsupportedRequestMethod(method)
    }
    let response = try await self.provider.request(
      "eip155:\(chainId)",
      withMethod: method,
      andParams: encodedParams,
      connect: self
    )

    return response.result
  }
}

enum PortalConnectError: Error {
  case noWebSocketClientFound
  case unableToParseSignResponse
  case unsupportedRequestMethod(String)
}

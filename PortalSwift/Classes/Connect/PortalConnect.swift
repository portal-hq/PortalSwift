//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//

import Foundation

/// A list of JSON-RPC signing methods.
public var signMethods: [ETHRequestMethods.RawValue] = [
  ETHRequestMethods.PersonalSign.rawValue,
  ETHRequestMethods.SendTransaction.rawValue,
  ETHRequestMethods.Sign.rawValue,
  ETHRequestMethods.SignTransaction.rawValue,
  ETHRequestMethods.SignTypedDataV3.rawValue,
  ETHRequestMethods.SignTypedDataV4.rawValue,
]

public class PortalConnect: EventBus {
  public var client: WebSocketClient
  public var connected: Bool = false
  public var uri: String?

  private var address: String?
  private var portal: Portal
  private var topic: String?
  public var connectState: ConnectState {
    return client.connectState
  }

  public init(
    _ portal: Portal,
    _ webSocketServer: String = "connect.portalhq.io"
  ) {
    // Set up webSocketClient
    let connectionString = webSocketServer.starts(with: "localhost") ? "ws://\(webSocketServer)" : "wss://\(webSocketServer)"
    client = WebSocketClient(
      portal: portal,
      webSocketServer: connectionString
    )

    self.portal = portal
    address = portal.mpc.getAddress()

    super.init(label: "PortalConnect")

    guard address != nil else {
      print("[PortalConnect] ⚠️ Address not found in Keychain. This may cause some features not to work as expected.")
      return
    }

    // Fired by the Provider

    on(event: Events.PortalConnectSigningRequested.rawValue) { payload in
      self.emit(event: Events.PortalSigningRequested.rawValue, data: payload)
    }

    // Fired by SDK Consumers

    on(event: Events.PortalSigningApproved.rawValue) { payload in
      _ = self.portal.provider.emit(event: Events.PortalSigningApproved.rawValue, data: payload)
    }

    on(event: Events.PortalSigningRejected.rawValue) { payload in
      _ = self.portal.provider.emit(event: Events.PortalSigningRejected.rawValue, data: payload)
    }
  }

  deinit {
    client.sendFinalMessageAndDisconnect()
  }

  public func connect(_ uri: String) {
    switch connectState {
    case .connecting, .connected:
      print("Connection is already in progress or established.")
      return
    case .disconnected:
      break
    }

    self.uri = uri

    client.resetEventBus()

    client.on("close", handleClose)
    client.on("portal_dappSessionRequested", handleDappSessionRequested)
    client.on("portal_dappSessionRequestedV1", handleDappSessionRequestedV1)
    client.on("connected", handleConnected)
    client.on("connectedV1", handleConnectedV1)
    client.on("disconnected", handleDisconnected)
    client.on("error", handleError)
    client.on("session_request", handleSessionRequest)
    client.on("session_request_address", handleSessionRequestAddress)
    client.on("session_request_transaction", handleSessionRequestTransaction)

    client.connect(uri: uri)
  }

  public func disconnect(_ userInitiated: Bool = false) {
    client.disconnect(userInitiated)
  }

  func handleDappSessionRequested(data: ConnectData) {
    once(event: Events.PortalDappSessionApproved.rawValue) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionApproved",
        data: SessionResponseData(
          id: data.id,
          topic: data.topic,
          address: self.address!,
          chainId: String(self.portal.chainId),
          params: data.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)

        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }

    once(event: Events.PortalDappSessionRejected.rawValue) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionRejected",
        data: SessionResponseData(
          id: data.id,
          topic: data.topic,
          address: self.address!,
          chainId: String(self.portal.chainId),
          params: data.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
    }

    emit(event: Events.PortalDappSessionRequested.rawValue, data: data)
  }

  func handleDappSessionRequestedV1(data: ConnectV1Data) {
    once(event: Events.PortalDappSessionApprovedV1.rawValue) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseV1Message(
        event: "portal_dappSessionApproved",
        data: SessionResponseV1Data(
          id: data.id,
          topic: data.topic,
          address: self.address!,
          chainId: String(self.portal.chainId)
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }

    once(event: Events.PortalDappSessionRejectedV1.rawValue) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseV1Message(
        event: "portal_dappSessionRejected",
        data: SessionResponseV1Data(
          id: data.id,
          topic: data.topic,
          address: self.address!,
          chainId: String(self.portal.chainId)
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
    }

    emit(event: Events.PortalDappSessionRequestedV1.rawValue, data: data)
  }

  func handleClose() {
    connected = false
    topic = nil
    client.topic = nil

    client.close()
  }

  func handleConnected(data: ConnectedData) {
    connected = true
    topic = data.topic
    client.topic = data.topic

    emit(event: Events.Connect.rawValue, data: data)
  }

  func handleConnectedV1(data: ConnectedV1Data) {
    connected = true
    topic = data.topic
    client.topic = data.topic

    emit(event: Events.Connect.rawValue, data: data)
  }

  func handleDisconnected(data: DisconnectData) {
    connected = false
    topic = nil
    client.topic = nil

    client.close()
    emit(event: Events.Disconnect.rawValue, data: data)
  }

  func handleError(data: ErrorData) {
    emit(event: Events.ConnectError.rawValue, data: data)
  }

  func handleSessionRequest(data: SessionRequestData) {
    let (id, method, params, topic) = (
      data.id,
      data.params.request.method,
      data.params.request.params,
      data.topic
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
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }

    handleProviderRequest(method: method, params: params) { [weak self] result in
      guard let self = self else { return }

      if result.error != nil {
        print("[PortalConnect] \(result.error!)")
        return
      }

      let signature = ((result.data as! RequestCompletionResult).result as! Result<SignerResult>).data!.signature!

      let event = SignatureReceivedMessage(
        event: "signatureReceived",
        data: SignatureReceivedData(
          topic: topic,
          transactionHash: signature,
          transactionId: id
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
          self.emit(event: Events.PortalSignatureReceived.rawValue, data: result.data!)
        }
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }

  func handleSessionRequestAddress(data: SessionRequestAddressData) {
    let (id, method, params, topic) = (
      data.id,
      data.params.request.method,
      data.params.request.params,
      data.topic
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
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }

    handleProviderRequest(method: method, params: params) { [weak self] result in
      guard let self = self else { return }

      if result.error != nil {
        print("[PortalConnect] \(result.error!)")
        return
      }

      let signature = ((result.data as! RequestCompletionResult).result as! Result<SignerResult>).data!.signature!
      let event = SignatureReceivedMessage(
        event: "signatureReceived",
        data: SignatureReceivedData(
          topic: topic,
          transactionHash: signature,
          transactionId: id
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
          self.emit(event: Events.PortalSignatureReceived.rawValue, data: result.data!)
        }
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }

  func handleSessionRequestTransaction(data: SessionRequestTransactionData) {
    let (id, method, params, topic) = (
      data.id,
      data.params.request.method,
      data.params.request.params,
      data.topic
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
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }

    handleProviderRequest(method: method, params: params) { [weak self] result in
      guard let self = self else { return }

      if result.error != nil {
        print("[PortalConnect] \(result.error!)")
        return
      }

      let txHash = result.data as! String
      let event = SignatureReceivedMessage(
        event: "signatureReceived",
        data: SignatureReceivedData(
          topic: topic,
          transactionHash: txHash,
          transactionId: id
        )
      )

      do {
        let message = try JSONEncoder().encode(event)

        self.client.send(message)

        // emit the PortalSignatureReceived event on the PortalConnect EventBus as a convenience
        if signMethods.contains(method) {
          self.emit(event: Events.PortalSignatureReceived.rawValue, data: result.data!)
        }
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }

  public func viewWillDisappear() {
    client.sendFinalMessageAndDisconnect()
  }

  private func handleProviderRequest(method: String, params: [ETHAddressParam], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHAddressPayload(method: method, params: params), connect: self) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: result.data!))
    }
  }

  private func handleProviderRequest(method: String, params: [ETHTransactionParam], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHTransactionPayload(method: method, params: params), connect: self) { (result: Result<TransactionCompletionResult>) in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: (result.data!.result as! Result<Any>).data as! String))
    }
  }

  private func handleProviderRequest(method: String, params: [Any], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHRequestPayload(method: method, params: params), connect: self) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: result.data!))
    }
  }
}

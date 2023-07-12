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

public class PortalConnect: ConnectEventBus {
  private var address: String?
  private var client: WebSocketClient
  private var connected: Bool = false
  private var portal: Portal
  private var topic: String?

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

    on(.ConnectSigningRequested) { payload in
      self.emit(.SigningRequested, data: payload)
    }

    // Fired by SDK Consumers

    on(.SigningApproved) { payload in
      print("[PortalConnect] Received signing approval for payload \(payload)")
      _ = self.portal.provider.emit(event: Events.PortalSigningApproved.rawValue, data: payload)
    }

    on(.SigningRejected) { payload in
      print("[PortalConnect] Received signing rejection for payload \(payload)")
      _ = self.portal.provider.emit(event: Events.PortalSigningRejected.rawValue, data: payload)
    }
  }

  deinit {
    client.sendFinalMessageAndDisconnect()
  }

  public func connect(_ uri: String) {
    (client as WebSocketEventBus).resetEvents()

    client.on(.Close, handleClose)
    client.on(.DappSessionRequested, handleDappSessionRequested)
    client.on(.Connected, handleConnected)
    client.on(.Disconnected, handleDisconnected)
    client.on(.Error, handleError)
    client.on(.SessionRequest, handleSessionRequest)
    client.on(.SessionRequestAddress, handleSessionRequestAddress)
    client.on(.SessionRequestTransaction, handleSessionRequestTransaction)

    client.connect(uri: uri)
  }

  public func disconnect(_ userInitiated: Bool = false) {
    client.disconnect(userInitiated)
  }

  func handleClose(_: Any) {
    connected = false
    topic = nil
    client.topic = nil

    client.close()
  }

  func handleConnected(_ data: Any) {
    guard let messageData = data as? ConnectedData else {
      return
    }

    connected = true
    topic = messageData.topic
    client.topic = messageData.topic

    emit(.Connect, data: data)
  }

  func handleDappSessionRequested(_ data: Any) {
    guard let messageData = data as? ConnectData else {
      return
    }

    once(.DappSessionApproved) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionApproved",
        data: SessionResponseData(
          id: messageData.id,
          topic: messageData.topic,
          address: self.address!,
          chainId: String(self.portal.chainId),
          params: messageData.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)

        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }

    once(.DappSessionRejected) { [weak self] _ in
      guard let self = self else { return }

      // If the approved event is fired
      let event = DappSessionResponseMessage(
        event: "portal_dappSessionRejected",
        data: SessionResponseData(
          id: messageData.id,
          topic: messageData.topic,
          address: self.address!,
          chainId: String(self.portal.chainId),
          params: messageData.params
        )
      )

      do {
        let message = try JSONEncoder().encode(event)
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
    }

    emit(.DappSessionRequested, data: data)
  }

  func handleDisconnected(_ data: Any) {
    guard let _ = data as? DisconnectData else {
      return
    }

    connected = false
    topic = nil
    client.topic = nil

    client.close()
    emit(.Disconnect, data: data)
  }

  func handleError(_ data: Any) {
    guard let messageData = data as? ErrorData else {
      return
    }

    emit(.ConnectError, data: messageData)
  }

  func handleSessionRequest(_ data: Any) {
    guard let messageData = data as? SessionRequestData else {
      print("Session Request Data not found: \(data)...")
      return
    }

    let (id, method, params, topic) = (
      messageData.id,
      messageData.params.request.method,
      messageData.params.request.params,
      messageData.topic
    )

    on(.SigningRejected) { [weak self] _ in
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
          self.emit(.SignatureReceived, data: result.data!)
        }
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }

  func handleSessionRequestAddress(_ data: Any) {
    guard let messageData = data as? SessionRequestAddressData else {
      return
    }

    let (id, method, params, topic) = (
      messageData.id,
      messageData.params.request.method,
      messageData.params.request.params,
      messageData.topic
    )

    on(.SigningRejected) { [weak self] _ in
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
          self.emit(.SignatureReceived, data: result.data!)
        }
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }

  func handleSessionRequestTransaction(_ data: Any) {
    guard let messageData = data as? SessionRequestTransactionData else {
      return
    }

    let (id, method, params, topic) = (
      messageData.id,
      messageData.params.request.method,
      messageData.params.request.params,
      messageData.topic
    )

    on(.SigningRejected) { [weak self] _ in
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
          self.emit(.SignatureReceived, data: result.data!)
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

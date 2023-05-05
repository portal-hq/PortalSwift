//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//

import Foundation

struct SignatureReceivedMessage: Codable {
  let event: String
  let data: SignatureReceivedData
}

struct SignatureReceivedData: Codable {
  let topic: String
  let transactionHash: String
  let transactionId: Int
}

public class PortalConnect {
  private var client: WebSocketClient
  private var connected: Bool = false
  private var portal: Portal
  
  public init(_ portal: Portal, _ webSocketServer: String = "connect.portalhq.io") {
    // Set up webSocketClient
    let connectionString = webSocketServer.starts(with: "localhost") ? "ws://\(webSocketServer)" : "wss://\(webSocketServer)"
    client = WebSocketClient(
      portal: portal,
      webSocketServer: connectionString
    )
    
    self.portal = portal
  }
  
  public func connect(_ uri: String) {
    client.on("close", handleClose)
    client.on("connected", handleConnected)
    client.on("connectedV1", handleConnectedV1)
    client.on("disconnected", handleDisconnected)
    client.on("session_request", handleSessionRequest)
    client.on("session_request_address", handleSessionRequestAddress)
    client.on("session_request_transaction", handleSessionRequestTransaction)
    
    client.connect(uri: uri)
  }
  
  func handleClose() {
    connected = false
    client.close()
  }
  
  func handleConnected(data: ConnectData) {
    connected = true
  }
  
  func handleConnectedV1(data: ConnectV1Data) {
    connected = true
  }
  
  func handleDisconnected(data: DisconnectData) {
    connected = false
    client.close()
  }
  
  func handleSessionRequest(data: SessionRequestData) {
    let (id, method, params, topic) = (
      data.id,
      data.params.request.method,
      data.params.request.params,
      data.topic
    )
      
    handleProviderRequest(method: method, params: params) { result in
      if (result.error != nil) {
        print("[PortalConnect] \(result.error!)")
        return
      }
      
      print("[PortalConnect] Signing result: \(result.data)")
      
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
      
    handleProviderRequest(method: method, params: params) { result in
      if (result.error != nil) {
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
      
    handleProviderRequest(method: method, params: params) { result in
      if (result.error != nil) {
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
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    }
  }
  
  private func handleProviderRequest(method: String, params: [ETHAddressParam], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHAddressPayload(method: method, params: params)) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: result.data!))
    }
  }
  
  private func handleProviderRequest(method: String, params: [ETHTransactionParam], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHTransactionPayload(method: method, params: params)) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: result.data!))
    }
  }
  
  private func handleProviderRequest(method: String, params: [Any], completion: @escaping (Result<Any>) -> Void) {
    portal.provider.request(payload: ETHRequestPayload(method: method, params: params)) { result in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: result.data!))
    }
  }
}

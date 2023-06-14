//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//

import Foundation

public class PortalConnect {
  private var client: WebSocketClient
  private var connected: Bool = false
  private var portal: Portal
  private var address: String?
  
  public init(_ portal: Portal, _ webSocketServer: String = "connect.portalhq.io") {
    // Set up webSocketClient
    let connectionString = webSocketServer.starts(with: "localhost") ? "ws://\(webSocketServer)" : "wss://\(webSocketServer)"
    client = WebSocketClient(
      portal: portal,
      webSocketServer: connectionString
    )
    
    self.portal = portal
    self.address = portal.mpc.getAddress() ?? nil
    
    guard self.address != nil else {
      print("[PortalConnect] ⚠️ Address not found in Keychain. This may cause some features not to work as expected.")
      return
    }
  }
  
  public func connect(_ uri: String) {
    client.on("close", handleClose)
    client.on("portal_dappSessionRequested", handleDappSessionRequested)
    client.on("portal_dappSessionRequestedV1", handleDappSessionRequestedV1)
    client.on("connected", handleConnected)
    client.on("connectedV1", handleConnectedV1)
    client.on("disconnected", handleDisconnected)
    client.on("session_request", handleSessionRequest)
    client.on("session_request_address", handleSessionRequestAddress)
    client.on("session_request_transaction", handleSessionRequestTransaction)
    
    client.connect(uri: uri)
  }
  
  public func on(event: Events.RawValue, callback: @escaping (_ data: Any) -> Void) {
    _ = portal.provider.on(event: event, callback: callback)
  }
  
  public func emit(event: Events.RawValue, data: Any) {
    _ = portal.provider.emit(event: event, data: data)
  }
  
  func handleDappSessionRequested(data: ConnectData) {
    print("recieved event portal_dappSessionRequested")
    _ = portal.provider.once(event: Events.PortalDappSessionApproved.rawValue, callback: { [self] approved in
      // If the approved event is fired
      let event = DappSessionResponseMessage(event: "portal_dappSessionApproved", data: SessionResponseData(id: data.id, topic: data.topic, address: self.address!, chainId: String(portal.chainId), params: data.params))
      
      do {
        let message = try JSONEncoder().encode(event)
        
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }).once(event: Events.PortalDappSessionRejected.rawValue, callback: { [self] approved in
      // If the approved event is fired
      let event = DappSessionResponseMessage(event: "portal_dappSessionRejected", data: SessionResponseData(id: data.id, topic: data.topic, address: self.address!, chainId: String(portal.chainId), params: data.params))
      
      do {
        let message = try JSONEncoder().encode(event)
        
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
      
    })
    _ = portal.provider.emit(event: Events.PortalDappSessionRequested.rawValue, data: data)
      
    }
  
  func handleDappSessionRequestedV1(data: ConnectV1Data) {
    print("recieved event portal_dappSessionRequestedV1")
    _ = portal.provider.once(event: Events.PortalDappSessionApprovedV1.rawValue, callback: { [self] approved in
      // If the approved event is fired
      let event = DappSessionResponseV1Message(event: "portal_dappSessionApproved", data: SessionResponseV1Data(id: data.id, topic: data.topic, address: self.address!, chainId: String(portal.chainId)))
      
      do {
        let message = try JSONEncoder().encode(event)
        
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestApprovedMessage: \(error)")
      }
    }).once(event: Events.PortalDappSessionRejectedV1.rawValue, callback: { [self] approved in
      // If the approved event is fired
      let event = DappSessionResponseV1Message(event: "portal_dappSessionRejected", data: SessionResponseV1Data(id: data.id, topic: data.topic, address: self.address!, chainId: String(portal.chainId)))
      
      do {
        let message = try JSONEncoder().encode(event)
        
        self.client.send(message)
      } catch {
        print("[PortalConnect] Error encoding DappSessionRequestRejectedMessage: \(error)")
      }
      
    })
    _ = portal.provider.emit(event: Events.PortalDappSessionRequestedV1.rawValue, data: data)
      
    }
  
  func handleClose() {
    connected = false
    client.close()
  }
  
  func handleConnected(data: ConnectData) {
    connected = true
    _ = portal.provider.emit(event: Events.Connect.rawValue, data: data)
  }
  
  func handleConnectedV1(data: ConnectedV1Data) {
    connected = true
    _ = portal.provider.emit(event: Events.Connect.rawValue, data: data)
  }
  
  func handleDisconnected(data: DisconnectData) {
    connected = false
    client.close()
    _ = portal.provider.emit(event: Events.Disconnect.rawValue, data: data)
  }
  
  func handleSessionRequest(data: SessionRequestData) {
    print("recieved event for session_request")
    let (id, method, params, topic) = (
      data.id,
      data.params.request.method,
      data.params.request.params,
      data.topic
    )
  
    _ = portal.provider.on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
      print("are we triggered?")
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
        return
      } catch {
        print("[PortalConnect] Error encoding SignatureReceivedMessage: \(error)")
      }
    })
    
    handleProviderRequest(method: method, params: params) { result in
      if (result.error != nil) {
        print("[PortalConnect] \(result.error!)")
        return
      }
      
      print("[PortalConnect] Signing result: \(String(describing: result.data))")
      
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
    _ = portal.provider.on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
      
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
    })
    
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
    
    _ = portal.provider.on(event: Events.PortalSigningRejected.rawValue, callback: { approved in
      
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
    })
      
    handleProviderRequest(method: method, params: params) { result in
      if (result.error != nil) {
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
    portal.provider.request(payload: ETHTransactionPayload(method: method, params: params)) { (result: Result<TransactionCompletionResult>) in
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      completion(Result(data: (result.data!.result as! Result<Any>).data as! String))
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

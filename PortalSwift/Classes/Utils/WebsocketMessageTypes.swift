//
//  WebsocketMessageTypes.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 6/9/23.
//

import Foundation

// Both
struct WebSocketMessage: Codable {
  let event: String
  let data: WebSocketMessageData?
}

enum WebSocketMessageData: Codable {
  case connectData(data: ConnectData)
  case disconnectData(data: DisconnectData)
  case sessionRequestData(data: SessionRequestData)
}

enum WebSocketRequestData: Codable {
  case connect(data: ConnectRequestData)
}

struct ConnectRequestData: Codable {
  let address: String
  let chainId: Int
  let uri: String
}

struct WebSocketConnectedMessage: Codable {
  var event: String = "connected"
  let data: ConnectedData
}
struct ConnectedData: Codable {
  let id: String
  let topic: String
  let params: Pairing
}

struct Pairing: Codable {
  let active: Bool
  let expiry: Int32?
  let peerMetadata: PeerMetadata
  let relay: ProtocolOptions?
  let topic: String?
}

struct WebSocketConnectedV1Message: Codable {
  var event: String = "connected"
  let data: ConnectedV1Data
}

struct ConnectedV1Data: Codable {
  let id: String
  let topic: String
  let params: PeerMetadata
}

struct WebSocketDappSessionRequestMessage: Codable {
  var event: String = "portal_dappSessionRequest"
  let data: ConnectData
}

struct ConnectData: Codable {
  let id: String
  let topic: String
  let params: SessionProposal
}

struct WebSocketDappSessionRequestV1Message: Codable {
  var event: String = "portal_dappSessionRequestV1"
  let data: ConnectV1Data
}

struct ConnectV1Data: Codable {
  let id: String
  let topic: String
  let params: ConnectV1Params
}

struct WebSocketDisconnectMessage: Codable {
  var event: String = "disconnect"
  let data: DisconnectData
}

struct WebSocketSessionRequestMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestData
}

struct WebSocketSessionRequestAddressMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestAddressData
}

struct WebSocketSessionRequestTransactionMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestTransactionData
}

struct WebSocketRequest: Codable {
  let event: String
  let data: WebSocketRequestData?
}

struct WebSocketConnectRequest: Codable {
  let event: String
  let data: ConnectRequestData
}

// Responses

struct SignatureReceivedMessage: Codable {
  let event: String
  let data: SignatureReceivedData
}

struct DappSessionResponseMessage: Codable {
  let event: String
  let data: SessionResponseData
}

struct DappSessionResponseV1Message: Codable {
  let event: String
  let data: SessionResponseV1Data
}

struct SignatureReceivedData: Codable {
  let topic: String
  let transactionHash: String
  let transactionId: String
}

// Specific Types for v1 or v2

// V2

struct SessionProposal: Codable {
    let id: Int
    let params: Params
}

struct Params: Codable {
    let id: Int
    let pairingTopic: String
    let expiry: Int
    let requiredNamespaces: Namespaces
    let optionalNamespaces: Namespaces
    let relays: [Relay]
    let proposer: Proposer
}

struct Namespaces: Codable {
    let eip155: Eip155
}

struct Eip155: Codable {
    let chains: [String]
    let methods: [String]
    let events: [String]
    let rpcMap: [String: String]
}

struct Relay: Codable {
  let `protocol`: String
}

struct Proposer: Codable {
    let publicKey: String
    let metadata: Metadata
}

struct Metadata: Codable {
    let description: String
    let url: String
    let icons: [String]
    let name: String
}

struct SessionResponseData: Codable {
  let id: String
  let topic: String
  let address: String
  let chainId: String
  let params: SessionProposal?
}

struct SessionResponseV1Data: Codable {
  let id: String
  let topic: String
  let address: String
  let chainId: String
}


// V1
struct ConnectV1Params: Codable {
  let id: Int
  let jsonrpc: String
  let method: String
  let params: [PyaloadV1Request]
}

struct PyaloadV1Request: Codable {
  let peerId: String
  let peerMeta: PeerMetadata
  let chainId: Int
}

struct PeerMetadata: Codable {
  let name: String
  let description: String
  let url: String
  let icons: [String]
}

//struct ConnectedV1Data: Codable {
//  let address: String
//  let chainId: String
//  let payloadId: String
//  let connected: Bool
//}


struct DisconnectData: Codable {
  let id: String
  let topic: String
}



struct ProtocolOptions: Codable {
  let `protocol`: String
  let data: String?
}

struct ProviderRequestAddressData: Codable {
  let method: String
  let params: [ETHAddressParam]
}

struct ProviderRequestTransactionData: Codable {
  let method: String
  let params: [ETHTransactionParam]
}

struct ProviderRequestData: Codable {
  let method: String
  let params: [String]
}

struct ProviderRequestParams: Codable {
  let chainId: Int?
  let request: ProviderRequestData
}

struct ProviderRequestTransactionParams: Codable {
  let chainId: Int?
  let request: ProviderRequestTransactionData
}

struct ProviderRequestAddressParams: Codable {
  let chainId: Int?
  let request: ProviderRequestAddressData
}

struct ProviderRequestPayload: Codable {
  let event: String
  let data: ProviderRequestData
}

struct ProviderRequestTransactionPayload: Codable {
  let event: String
  let data: ProviderRequestTransactionData
}

struct ProviderRequestAddressPayload: Codable {
  let event: String
  let data: ProviderRequestAddressData
}

struct SessionRequestData: Codable {
  let id: String
  let params: ProviderRequestParams
  let topic: String
}

struct SessionRequestTransactionData: Codable {
  let id: String
  let params: ProviderRequestTransactionParams
  let topic: String
}

struct SessionRequestAddressData: Codable {
  let id: String
  let params: ProviderRequestAddressParams
  let topic: String
}


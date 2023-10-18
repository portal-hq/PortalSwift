//
//  WebsocketMessageTypes.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 6/9/23.
//

import Foundation

// Both
public struct WebSocketMessage: Codable {
  public let event: String
  public let data: WebSocketMessageData?
}

public enum WebSocketMessageData: Codable {
  case connectData(data: ConnectData)
  case disconnectData(data: DisconnectData)
  case sessionRequestData(data: SessionRequestData)
}

public enum WebSocketRequestData: Codable {
  case connect(data: ConnectRequestData)
}

public struct ConnectRequestData: Codable {
  public let address: String
  public let chainId: Int
  public let uri: String
}

public struct DisconnectRequestData: Codable {
  public let topic: String?
  public let userInitiated: Bool
}

public struct WebSocketConnectedMessage: Codable {
  public var event: String = "connected"
  public let data: ConnectedData
}

public struct ConnectedData: Codable {
  public let id: String
  public let topic: String
  public let params: Pairing
}

public struct ErrorData: Codable {
  public let id: String
  public let topic: String
  public let params: ConnectError
}

public struct ConnectError: Codable {
  public let message: String
  public let code: Int
}

public struct Pairing: Codable {
  public let active: Bool
  public let expiry: Int32?
  public let peerMetadata: PeerMetadata
  public let relay: ProtocolOptions?
  public let topic: String?
}

public struct WebSocketConnectedV1Message: Codable {
  public var event: String = "connected"
  public let data: ConnectedV1Data
}

public struct ConnectedV1Data: Codable {
  public let id: String
  public let topic: String
  public let params: PeerMetadata
}

public struct WebSocketDappSessionRequestMessage: Codable {
  public var event: String = "portal_dappSessionRequested"
  public let data: ConnectData
}

public struct ConnectData: Codable {
  public let id: String
  public let topic: String
  public var params: SessionProposal
}

public struct WebSocketDappSessionRequestV1Message: Codable {
  public var event: String = "portal_dappSessionRequestedV1"
  public let data: ConnectV1Data
}

public struct ConnectV1Data: Codable {
  public let id: String
  public let topic: String
  public let params: PeerMetadata
}

public struct WebSocketDisconnectMessage: Codable {
  public var event: String = "disconnect"
  public let data: DisconnectData
}

public struct WebSocketDisconnectRequest: Codable {
  public let event: String
  public let data: DisconnectRequestData
}

public struct WebSocketErrorMessage: Codable {
  public var event: String = "portal_connectError"
  public let data: ErrorData
}

public struct WebSocketSessionRequestMessage: Codable {
  public var event: String = "session_request"
  public let data: SessionRequestData
}

public struct WebSocketSessionRequestAddressMessage: Codable {
  public var event: String = "session_request"
  public let data: SessionRequestAddressData
}

public struct WebSocketSessionRequestTransactionMessage: Codable {
  public var event: String = "session_request"
  public let data: SessionRequestTransactionData
}

public struct WebSocketRequest: Codable {
  public let event: String
  public let data: WebSocketRequestData?
}

public struct WebSocketConnectRequest: Codable {
  public let event: String
  public let data: ConnectRequestData
}

// Responses

public struct SignatureReceivedMessage: Codable {
  public let event: String
  public let data: SignatureReceivedData
}

public struct ChainChangedMessage: Codable {
  public let event: String
  public let data: ChainChangedData
}

public struct DappSessionResponseMessage: Codable {
  public let event: String
  public let data: SessionResponseData
}

public struct DappSessionResponseV1Message: Codable {
  public let event: String
  public let data: SessionResponseV1Data
}

public struct SignatureReceivedData: Codable {
  public let topic: String
  public let transactionHash: String
  public let transactionId: String
}

public struct ChainChangedData: Codable {
  public let topic: String?
  public let uri: String?
  public let chainId: String
}

// Specific Types for v1 or v2

// V2

public struct SessionProposal: Codable {
  public var id: Int
  public var params: Params
}

public struct Params: Codable {
  public let id: Int
  public let pairingTopic: String
  public let expiry: Int
  public var requiredNamespaces: Namespaces
  public var optionalNamespaces: OptionalNamespaces?
  public let relays: [Relay]
  public let proposer: Proposer
  public let verifyContext: VerifyContext?
}

public struct Namespaces: Codable {
  public var eip155: Eip155?
}

public struct Eip155: Codable {
  public var chains: [String]?
  public var methods: [String]?
  public var events: [String]?
  public var rpcMap: [String: String]?
}

public struct OptionalNamespaces: Codable {
  public var eip155: OptionalEip155?
}

public struct OptionalEip155: Codable {
  public var chains: [String]?
  public var methods: [String]?
  public var events: [String]?
  public var rpcMap: [String: String]?
}

public struct Relay: Codable {
  public let `protocol`: String
}

public struct Proposer: Codable {
  public let publicKey: String
  public let metadata: Metadata
}

public struct Metadata: Codable {
  public let description: String
  public let url: String
  public let icons: [String]
  public let name: String
}

public struct VerifyContext: Codable {
  public let verified: Verified
}

public struct Verified: Codable {
  public let verifyUrl: String
  public let validation: String
  public let origin: String
}

public struct SessionResponseData: Codable {
  public let id: String
  public let topic: String
  public let address: String
  public let chainId: String
  public let params: SessionProposal?
}

public struct SessionResponseV1Data: Codable {
  public let id: String
  public let topic: String
  public let address: String
  public let chainId: String
}

// V1
public struct PeerMetadata: Codable {
  public let name: String
  public let description: String
  public let url: String
  public let icons: [String]
}

public struct DisconnectData: Codable {
  public let id: String
  public let topic: String
}

public struct ProtocolOptions: Codable {
  public let `protocol`: String
  public let data: String?
}

public struct ProviderRequestAddressData: Codable {
  public let method: String
  public let params: [ETHAddressParam]
}

public struct ProviderRequestTransactionData: Codable {
  public let method: String
  public let params: [ETHTransactionParam]
}

public struct ProviderRequestData: Codable {
  public let method: String
  public let params: [String]
}

public struct ProviderRequestParams: Codable {
  public let chainId: Int?
  public let request: ProviderRequestData
}

public struct ProviderRequestTransactionParams: Codable {
  public let chainId: Int?
  public let request: ProviderRequestTransactionData
}

public struct ProviderRequestAddressParams: Codable {
  public let chainId: Int?
  public let request: ProviderRequestAddressData
}

public struct ProviderRequestPayload: Codable {
  public let event: String
  public let data: ProviderRequestData
}

public struct ProviderRequestTransactionPayload: Codable {
  public let event: String
  public let data: ProviderRequestTransactionData
}

public struct ProviderRequestAddressPayload: Codable {
  public let event: String
  public let data: ProviderRequestAddressData
}

public struct SessionRequestData: Codable {
  public let id: String
  public let params: ProviderRequestParams
  public let topic: String
}

public struct SessionRequestTransactionData: Codable {
  public let id: String
  public let params: ProviderRequestTransactionParams
  public let topic: String
}

public struct SessionRequestAddressData: Codable {
  public let id: String
  public let params: ProviderRequestAddressParams
  public let topic: String
}

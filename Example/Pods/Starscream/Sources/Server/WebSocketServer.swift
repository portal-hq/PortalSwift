//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WebSocketServer.swift
//  Starscream
//
//  Created by Dalton Cherry on 4/5/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

#if canImport(Network)
  import Foundation
  import Network

  /// WebSocketServer is a Network.framework implementation of a WebSocket server
  @available(watchOS, unavailable)
  @available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
  public class WebSocketServer: Server, ConnectionDelegate {
    public var onEvent: ((ServerEvent) -> Void)?
    private var connections = [String: ServerConnection]()
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.vluxe.starscream.server.networkstream", attributes: [])

    public init() {}

    public func start(address: String, port: UInt16) -> Error? {
      // TODO: support TLS cert adding/binding
      let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
      let p = NWEndpoint.Port(rawValue: port)!
      parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host.name(address, nil), port: p)

      guard let listener = try? NWListener(using: parameters, on: p) else {
        return WSError(type: .serverError, message: "unable to start the listener at: \(address):\(port)", code: 0)
      }
      listener.newConnectionHandler = { [weak self] conn in
        let transport = TCPTransport(connection: conn)
        let c = ServerConnection(transport: transport)
        c.delegate = self
        self?.connections[c.uuid] = c
      }
//        listener.stateUpdateHandler = { state in
//            switch state {
//            case .ready:
//                print("ready to get sockets!")
//            case .setup:
//                print("setup to get sockets!")
//            case .cancelled:
//                print("server cancelled!")
//            case .waiting(let error):
//                print("waiting error: \(error)")
//            case .failed(let error):
//                print("server failed: \(error)")
//            @unknown default:
//                print("wat?")
//            }
//        }
      self.listener = listener
      listener.start(queue: self.queue)
      return nil
    }

    public func didReceive(event: ServerEvent) {
      self.onEvent?(event)
      switch event {
      case let .disconnected(conn, _, _):
        guard let conn = conn as? ServerConnection else {
          return
        }
        self.connections.removeValue(forKey: conn.uuid)
      default:
        break
      }
    }
  }

  @available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
  public class ServerConnection: Connection, HTTPServerDelegate, FramerEventClient, FrameCollectorDelegate, TransportEventClient {
    let transport: TCPTransport
    private let httpHandler = FoundationHTTPServerHandler()
    private let framer = WSFramer(isServer: true)
    private let frameHandler = FrameCollector()
    private var didUpgrade = false
    public var onEvent: ((ConnectionEvent) -> Void)?
    public weak var delegate: ConnectionDelegate?
    private let id: String
    var uuid: String {
      return self.id
    }

    init(transport: TCPTransport) {
      self.id = UUID().uuidString
      self.transport = transport
      transport.register(delegate: self)
      self.httpHandler.register(delegate: self)
      self.framer.register(delegate: self)
      self.frameHandler.delegate = self
    }

    public func write(data: Data, opcode: FrameOpCode) {
      let wsData = self.framer.createWriteFrame(opcode: opcode, payload: data, isCompressed: false)
      self.transport.write(data: wsData, completion: { _ in })
    }

    // MARK: - TransportEventClient

    public func connectionChanged(state: ConnectionState) {
      switch state {
      case .connected:
        break
      case .waiting:
        break
      case let .failed(error):
        print("server connection error: \(error ?? WSError(type: .protocolError, message: "default error, no extra data", code: 0))") // handleError(error)
      case .viability:
        break
      case .shouldReconnect:
        break
      case let .receive(data):
        if self.didUpgrade {
          self.framer.add(data: data)
        } else {
          self.httpHandler.parse(data: data)
        }
      case .cancelled:
        print("server connection cancelled!")
      // broadcast(event: .cancelled)
      case .peerClosed:
        self.delegate?.didReceive(event: .disconnected(self, "Connection closed by peer", UInt16(FrameOpCode.connectionClose.rawValue)))
      }
    }

    // MARK: - HTTPServerDelegate

    public func didReceive(event: HTTPEvent) {
      switch event {
      case let .success(headers):
        self.didUpgrade = true
        let response = self.httpHandler.createResponse(headers: [:])
        self.transport.write(data: response, completion: { _ in })
        self.delegate?.didReceive(event: .connected(self, headers))
        self.onEvent?(.connected(headers))
      case let .failure(error):
        self.onEvent?(.error(error))
      }
    }

    // MARK: - FrameCollectorDelegate

    public func frameProcessed(event: FrameEvent) {
      switch event {
      case let .frame(frame):
        self.frameHandler.add(frame: frame)
      case let .error(error):
        self.onEvent?(.error(error))
      }
    }

    public func didForm(event: FrameCollector.Event) {
      switch event {
      case let .text(string):
        self.delegate?.didReceive(event: .text(self, string))
        self.onEvent?(.text(string))
      case let .binary(data):
        self.delegate?.didReceive(event: .binary(self, data))
        self.onEvent?(.binary(data))
      case let .pong(data):
        self.delegate?.didReceive(event: .pong(self, data))
        self.onEvent?(.pong(data))
      case let .ping(data):
        self.delegate?.didReceive(event: .ping(self, data))
        self.onEvent?(.ping(data))
      case let .closed(reason, code):
        self.delegate?.didReceive(event: .disconnected(self, reason, code))
        self.onEvent?(.disconnected(reason, code))
      case let .error(error):
        self.onEvent?(.error(error))
      }
    }

    public func decompress(data _: Data, isFinal _: Bool) -> Data? {
      return nil
    }
  }
#endif

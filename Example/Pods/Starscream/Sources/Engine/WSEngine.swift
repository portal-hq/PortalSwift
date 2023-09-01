//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WSEngine.swift
//  Starscream
//
//  Created by Dalton Cherry on 6/15/19
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

import Foundation

public class WSEngine: Engine, TransportEventClient, FramerEventClient,
  FrameCollectorDelegate, HTTPHandlerDelegate
{
  private let transport: Transport
  private let framer: Framer
  private let httpHandler: HTTPHandler
  private let compressionHandler: CompressionHandler?
  private let certPinner: CertificatePinning?
  private let headerChecker: HeaderValidator
  private var request: URLRequest!

  private let frameHandler = FrameCollector()
  private var didUpgrade = false
  private var secKeyValue = ""
  private let writeQueue = DispatchQueue(label: "com.vluxe.starscream.writequeue")
  private let mutex = DispatchSemaphore(value: 1)
  private var canSend = false
  private var isConnecting = false

  weak var delegate: EngineDelegate?
  public var respondToPingWithPong: Bool = true

  public init(transport: Transport,
              certPinner: CertificatePinning? = nil,
              headerValidator: HeaderValidator = FoundationSecurity(),
              httpHandler: HTTPHandler = FoundationHTTPHandler(),
              framer: Framer = WSFramer(),
              compressionHandler: CompressionHandler? = nil)
  {
    self.transport = transport
    self.framer = framer
    self.httpHandler = httpHandler
    self.certPinner = certPinner
    self.headerChecker = headerValidator
    self.compressionHandler = compressionHandler
    framer.updateCompression(supports: compressionHandler != nil)
    self.frameHandler.delegate = self
  }

  public func register(delegate: EngineDelegate) {
    self.delegate = delegate
  }

  public func start(request: URLRequest) {
    self.mutex.wait()
    let isConnecting = self.isConnecting
    let isConnected = self.canSend
    self.mutex.signal()
    if isConnecting || isConnected {
      return
    }

    self.request = request
    self.transport.register(delegate: self)
    self.framer.register(delegate: self)
    self.httpHandler.register(delegate: self)
    self.frameHandler.delegate = self
    guard let url = request.url else {
      return
    }
    self.mutex.wait()
    self.isConnecting = true
    self.mutex.signal()
    self.transport.connect(url: url, timeout: request.timeoutInterval, certificatePinning: self.certPinner)
  }

  public func stop(closeCode: UInt16 = CloseCode.normal.rawValue) {
    let capacity = MemoryLayout<UInt16>.size
    var pointer = [UInt8](repeating: 0, count: capacity)
    writeUint16(&pointer, offset: 0, value: closeCode)
    let payload = Data(bytes: pointer, count: MemoryLayout<UInt16>.size)
    self.write(data: payload, opcode: .connectionClose, completion: { [weak self] in
      self?.reset()
      self?.forceStop()
    })
  }

  public func forceStop() {
    self.mutex.wait()
    self.isConnecting = false
    self.mutex.signal()

    self.transport.disconnect()
  }

  public func write(string: String, completion: (() -> Void)?) {
    let data = string.data(using: .utf8)!
    self.write(data: data, opcode: .textFrame, completion: completion)
  }

  public func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
    self.writeQueue.async { [weak self] in
      guard let s = self else { return }
      s.mutex.wait()
      let canWrite = s.canSend
      s.mutex.signal()
      if !canWrite {
        return
      }

      var isCompressed = false
      var sendData = data
      if let compressedData = s.compressionHandler?.compress(data: data) {
        sendData = compressedData
        isCompressed = true
      }

      let frameData = s.framer.createWriteFrame(opcode: opcode, payload: sendData, isCompressed: isCompressed)
      s.transport.write(data: frameData, completion: { _ in
        completion?()
      })
    }
  }

  // MARK: - TransportEventClient

  public func connectionChanged(state: ConnectionState) {
    switch state {
    case .connected:
      self.secKeyValue = HTTPWSHeader.generateWebSocketKey()
      let wsReq = HTTPWSHeader.createUpgrade(request: self.request, supportsCompression: self.framer.supportsCompression(), secKeyValue: self.secKeyValue)
      let data = self.httpHandler.convert(request: wsReq)
      self.transport.write(data: data, completion: { _ in })
    case .waiting:
      break
    case let .failed(error):
      self.handleError(error)
    case let .viability(isViable):
      self.broadcast(event: .viabilityChanged(isViable))
    case let .shouldReconnect(status):
      self.broadcast(event: .reconnectSuggested(status))
    case let .receive(data):
      if self.didUpgrade {
        self.framer.add(data: data)
      } else {
        let offset = self.httpHandler.parse(data: data)
        if offset > 0 {
          let extraData = data.subdata(in: offset ..< data.endIndex)
          self.framer.add(data: extraData)
        }
      }
    case .cancelled:
      self.mutex.wait()
      self.isConnecting = false
      self.mutex.signal()

      self.broadcast(event: .cancelled)
    case .peerClosed:
      self.broadcast(event: .peerClosed)
    }
  }

  // MARK: - HTTPHandlerDelegate

  public func didReceiveHTTP(event: HTTPEvent) {
    switch event {
    case let .success(headers):
      if let error = headerChecker.validate(headers: headers, key: secKeyValue) {
        self.handleError(error)
        return
      }
      self.mutex.wait()
      self.isConnecting = false
      self.didUpgrade = true
      self.canSend = true
      self.mutex.signal()
      self.compressionHandler?.load(headers: headers)
      if let url = request.url {
        HTTPCookie.cookies(withResponseHeaderFields: headers, for: url).forEach {
          HTTPCookieStorage.shared.setCookie($0)
        }
      }

      self.broadcast(event: .connected(headers))
    case let .failure(error):
      self.handleError(error)
    }
  }

  // MARK: - FramerEventClient

  public func frameProcessed(event: FrameEvent) {
    switch event {
    case let .frame(frame):
      self.frameHandler.add(frame: frame)
    case let .error(error):
      self.handleError(error)
    }
  }

  // MARK: - FrameCollectorDelegate

  public func decompress(data: Data, isFinal: Bool) -> Data? {
    return self.compressionHandler?.decompress(data: data, isFinal: isFinal)
  }

  public func didForm(event: FrameCollector.Event) {
    switch event {
    case let .text(string):
      self.broadcast(event: .text(string))
    case let .binary(data):
      self.broadcast(event: .binary(data))
    case let .pong(data):
      self.broadcast(event: .pong(data))
    case let .ping(data):
      self.broadcast(event: .ping(data))
      if self.respondToPingWithPong {
        self.write(data: data ?? Data(), opcode: .pong, completion: nil)
      }
    case let .closed(reason, code):
      self.broadcast(event: .disconnected(reason, code))
      self.stop(closeCode: code)
    case let .error(error):
      self.handleError(error)
    }
  }

  private func broadcast(event: WebSocketEvent) {
    self.delegate?.didReceive(event: event)
  }

  // This call can be coming from a lot of different queues/threads.
  // be aware of that when modifying shared variables
  private func handleError(_ error: Error?) {
    if let wsError = error as? WSError {
      self.stop(closeCode: wsError.code)
    } else {
      self.stop()
    }

    self.delegate?.didReceive(event: .error(error))
  }

  private func reset() {
    self.mutex.wait()
    self.isConnecting = false
    self.canSend = false
    self.didUpgrade = false
    self.mutex.signal()
  }
}

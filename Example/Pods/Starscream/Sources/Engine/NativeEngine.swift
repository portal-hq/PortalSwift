//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  NativeEngine.swift
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class NativeEngine: NSObject, Engine, URLSessionDataDelegate, URLSessionWebSocketDelegate {
  private var task: URLSessionWebSocketTask?
  weak var delegate: EngineDelegate?

  public func register(delegate: EngineDelegate) {
    self.delegate = delegate
  }

  public func start(request: URLRequest) {
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    self.task = session.webSocketTask(with: request)
    self.doRead()
    self.task?.resume()
  }

  public func stop(closeCode: UInt16) {
    let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
    self.task?.cancel(with: closeCode, reason: nil)
  }

  public func forceStop() {
    self.stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
  }

  public func write(string: String, completion: (() -> Void)?) {
    self.task?.send(.string(string), completionHandler: { _ in
      completion?()
    })
  }

  public func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
    switch opcode {
    case .binaryFrame:
      self.task?.send(.data(data), completionHandler: { _ in
        completion?()
      })
    case .textFrame:
      let text = String(data: data, encoding: .utf8)!
      self.write(string: text, completion: completion)
    case .ping:
      self.task?.sendPing(pongReceiveHandler: { _ in
        completion?()
      })
    default:
      break // unsupported
    }
  }

  private func doRead() {
    self.task?.receive { [weak self] result in
      switch result {
      case let .success(message):
        switch message {
        case let .string(string):
          self?.broadcast(event: .text(string))
        case let .data(data):
          self?.broadcast(event: .binary(data))
        @unknown default:
          break
        }
      case let .failure(error):
        self?.broadcast(event: .error(error))
        return
      }
      self?.doRead()
    }
  }

  private func broadcast(event: WebSocketEvent) {
    self.delegate?.didReceive(event: event)
  }

  public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
    let p = `protocol` ?? ""
    self.broadcast(event: .connected([HTTPWSHeader.protocolName: p]))
  }

  public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
    var r = ""
    if let d = reason {
      r = String(data: d, encoding: .utf8) ?? ""
    }
    self.broadcast(event: .disconnected(r, UInt16(closeCode.rawValue)))
  }

  public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
    self.broadcast(event: .error(error))
  }
}

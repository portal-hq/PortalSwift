//
//  FakeWebSocketEngine.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Starscream

// MARK: - FakeWebSocketEngine

/// A `Starscream.Engine` that never opens a TCP connection, injected into `WebSocketClient`
/// through its `engine:` seam so the real `Starscream.WebSocket` sits between the SDK and this
/// double.
///
/// Going through the real socket rather than mocking `WebSocketClient` itself matters: the
/// upgrade request the SDK builds per connect is what `start(request:)` receives, so a test can
/// read the exact `Authorization` header that would have gone on the wire (`startRequests`),
/// count how many times a connect or reconnect actually reached the transport
/// (`startCallsCount`), and see the close codes the SDK used to tear the connection down
/// (`stopCloseCodes`). Outbound frames are captured in `writtenStrings`/`writtenData` instead
/// of being sent. Nothing is emitted back automatically — tests drive events explicitly through
/// `WebSocketClient.didReceive(event:client:)` or, to exercise the socket's callback hop, via
/// `deliver(_:)`. All state is lock-guarded because Starscream calls the engine from whatever
/// thread the SDK connected on.
final class FakeWebSocketEngine: Engine {
  private let lock = NSLock()
  private var _startRequests: [URLRequest] = []
  private var _stopCloseCodes: [UInt16] = []
  private var _forceStopCallsCount = 0
  private var _registerCallsCount = 0
  private var _writtenStrings: [String] = []
  private var _writtenData: [(data: Data, opcode: FrameOpCode)] = []
  private var _onStart: ((URLRequest) -> Void)?
  private weak var _delegate: EngineDelegate?

  init() {}

  // MARK: - Recording

  /// Every request passed to `start(request:)`, in call order. Index 0 is the first connect;
  /// each reconnect appends a freshly built request.
  var startRequests: [URLRequest] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._startRequests
  }

  /// How many times `start(request:)` was called — one per connect or reconnect that reached
  /// the transport.
  var startCallsCount: Int {
    self.startRequests.count
  }

  /// The most recent request passed to `start(request:)`, if any.
  var lastStartRequest: URLRequest? {
    self.startRequests.last
  }

  /// The `Authorization` header of each start request, in call order (`nil` when absent), so a
  /// test can compare the bearer per connect without digging through `URLRequest`.
  var authorizationHeaders: [String?] {
    self.startRequests.map { $0.value(forHTTPHeaderField: "Authorization") }
  }

  /// The close code passed to each `stop(closeCode:)`, in call order.
  var stopCloseCodes: [UInt16] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._stopCloseCodes
  }

  /// How many times `stop(closeCode:)` was called.
  var stopCallsCount: Int {
    self.stopCloseCodes.count
  }

  /// How many times `forceStop()` was called.
  var forceStopCallsCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._forceStopCallsCount
  }

  /// How many times a delegate was registered. The real socket registers on every `connect()`.
  var registerCallsCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._registerCallsCount
  }

  /// Every string frame written through `write(string:completion:)`, in call order. The SDK's
  /// connect/disconnect messages arrive here as JSON.
  var writtenStrings: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._writtenStrings
  }

  /// Every binary frame written through `write(data:opcode:completion:)`, with its opcode, in
  /// call order.
  var writtenData: [(data: Data, opcode: FrameOpCode)] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._writtenData
  }

  /// The delegate the real socket registered, if it is still alive. `deliver(_:)` uses it.
  var registeredDelegate: EngineDelegate? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._delegate
  }

  /// Runs inside `start(request:)` after the request is recorded, e.g. to `deliver(.connected)`
  /// in response to a connect. Invoked outside the lock.
  var onStart: ((URLRequest) -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onStart
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onStart = newValue
    }
  }

  /// Forgets every recorded call and written frame. The registered delegate and `onStart` are
  /// kept so the socket stays wired to this engine.
  func reset() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._startRequests.removeAll()
    self._stopCloseCodes.removeAll()
    self._forceStopCallsCount = 0
    self._registerCallsCount = 0
    self._writtenStrings.removeAll()
    self._writtenData.removeAll()
  }

  /// Pushes `event` to the registered delegate the way a live transport would.
  ///
  /// The real `Starscream.WebSocket` forwards it to the SDK on its `callbackQueue` (the main
  /// queue) asynchronously, so a test must `waitUntil` the effect rather than assert
  /// immediately. Returns `false` when no delegate is registered (nothing has connected yet).
  @discardableResult
  func deliver(_ event: WebSocketEvent) -> Bool {
    guard let delegate = self.registeredDelegate else {
      return false
    }
    delegate.didReceive(event: event)
    return true
  }

  // MARK: - Engine

  func register(delegate: EngineDelegate) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._registerCallsCount += 1
    self._delegate = delegate
  }

  func start(request: URLRequest) {
    self.lock.lock()
    self._startRequests.append(request)
    let hook = self._onStart
    self.lock.unlock()

    hook?(request)
  }

  func stop(closeCode: UInt16) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._stopCloseCodes.append(closeCode)
  }

  func forceStop() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._forceStopCallsCount += 1
  }

  func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
    self.lock.lock()
    self._writtenData.append((data: data, opcode: opcode))
    self.lock.unlock()

    completion?()
  }

  func write(string: String, completion: (() -> Void)?) {
    self.lock.lock()
    self._writtenStrings.append(string)
    self.lock.unlock()

    completion?()
  }
}

// MARK: - FakeStarscreamClient

/// The `client` argument for `WebSocketClient.didReceive(event:client:)` when a test drives the
/// delegate directly instead of going through a socket.
///
/// The SDK ignores that parameter, so this exists to satisfy the delegate signature without
/// constructing a real `Starscream.WebSocket`. It still records what it is asked to do, so a
/// test can prove the SDK never writes through the delegate's client argument. Lock-guarded
/// for symmetry with the engine; the SDK may call it from any thread.
final class FakeStarscreamClient: Starscream.WebSocketClient {
  private let lock = NSLock()
  private var _connectCallsCount = 0
  private var _disconnectCloseCodes: [UInt16] = []
  private var _writtenStrings: [String] = []
  private var _writtenData: [Data] = []
  private var _pings: [Data] = []
  private var _pongs: [Data] = []

  init() {}

  /// How many times `connect()` was called.
  var connectCallsCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._connectCallsCount
  }

  /// The close code passed to each `disconnect(closeCode:)`, in call order.
  var disconnectCloseCodes: [UInt16] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._disconnectCloseCodes
  }

  /// Every string written through `write(string:completion:)` or `write(stringData:completion:)`
  /// (decoded as UTF-8), in call order.
  var writtenStrings: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._writtenStrings
  }

  /// Every binary payload written through `write(data:completion:)`, in call order.
  var writtenData: [Data] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._writtenData
  }

  /// Every ping payload written, in call order.
  var pings: [Data] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._pings
  }

  /// Every pong payload written, in call order.
  var pongs: [Data] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._pongs
  }

  // MARK: - Starscream.WebSocketClient

  func connect() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._connectCallsCount += 1
  }

  func disconnect(closeCode: UInt16) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._disconnectCloseCodes.append(closeCode)
  }

  func write(string: String, completion: (() -> Void)?) {
    self.lock.lock()
    self._writtenStrings.append(string)
    self.lock.unlock()

    completion?()
  }

  func write(stringData: Data, completion: (() -> Void)?) {
    self.lock.lock()
    self._writtenStrings.append(String(decoding: stringData, as: UTF8.self))
    self.lock.unlock()

    completion?()
  }

  func write(data: Data, completion: (() -> Void)?) {
    self.lock.lock()
    self._writtenData.append(data)
    self.lock.unlock()

    completion?()
  }

  func write(ping: Data, completion: (() -> Void)?) {
    self.lock.lock()
    self._pings.append(ping)
    self.lock.unlock()

    completion?()
  }

  func write(pong: Data, completion: (() -> Void)?) {
    self.lock.lock()
    self._pongs.append(pong)
    self.lock.unlock()

    completion?()
  }
}

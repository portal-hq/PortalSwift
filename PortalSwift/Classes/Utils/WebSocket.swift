//
//  WebSocket.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/29/23.
//

import Foundation

@available(iOS 13.0, *)
class WebSocket: NSObject, URLSessionWebSocketDelegate {
  /// Instance variables
  private var session: URLSession?
  private var task: URLSessionWebSocketTask?
  private var url: URL
  
  /// Lifecycle variables
  private var onClose: () -> Void = {}
  private var onDisconnect: () -> Void = {}
  
  public var onMessage: (String) -> Void = { message in }
  public var onConnect: () -> Void = {}
  
  init(url: String) {
    self.url = URL(string: url)!
  }
  
  /// Creates a WebSocket connection for the URL assigned to this instance
  /// - Accepts an onMessage function argument for handling new WebSocket messages
  public func connect(
    onMessage: @escaping (String) -> Void
  ) {
    session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    task = session!.webSocketTask(with: self.url)
    
    self.onMessage = onMessage
  }
  
  public func send(_ message: String) async -> Result<Bool> {
    do {
      task!.resume()
      try await task!.send(URLSessionWebSocketTask.Message.string(message))
      return Result(data: true)
    } catch {
      return Result(error: error)
    }
  }
  
  /**
   * Required URLSessionWebSocketDelegate functions
   */
  
  /// Handles connection via webSocket
  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    print(
      "[PortalConnect] WebSocket connection established with URL: \(self.url.absoluteURL)"
    )
  }
  
  /// Handles disconnect of the webSocket
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    print("[PortalConnect] WebSocket is disconnected: \(error?.localizedDescription ?? "")")
  }
  
  /// Handles the closure of the webSocket connection
  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    print("[PortalConnect] WebSocket is closed with code \(closeCode.rawValue), reason: \(reason ?? Data())")
  }
  
  /// Handles inbound messages over the webSocket
  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didReceive message: URLSessionWebSocketTask.Message
  ) {
    switch message {
    case .string(let text):
      print("Received message: \(text)")
      self.onMessage(text)
    case .data(let data):
      print("Received data: \(data)")
    @unknown default:
      fatalError("Unknown message type")
    }
  }
}

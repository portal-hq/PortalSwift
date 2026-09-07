//
//  CredentialTestSupport.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

// MARK: - InvalidationListenerRecorder

/// Subscribes to `onCredentialsInvalidated(_:listener:)` for one credential and records every
/// delivery, so tests can assert the once-only, main-actor contract of the host notification.
///
/// The recorder counts deliveries and, separately, deliveries that observed
/// `Thread.isMainThread == true`, so a test can pin both "exactly once" and "on the main actor"
/// from the same object. `onDeliver` runs inside the listener after the counters are updated,
/// which is how a test makes a listener cancel itself, block on a semaphore, or subscribe
/// another listener mid-callback. The subscription handle is exposed so the test can cancel it
/// or compare it against `PortalSessionInvalidationHandle.spent`. The listener captures the
/// recorder weakly: the registry keeps listeners alive until they fire, and a test-scoped
/// recorder must not be pinned by it.
final class InvalidationListenerRecorder {
  private let lock = NSLock()
  private var _deliveries = 0
  private var _mainThreadDeliveries = 0

  /// The handle returned by the subscription. `.spent` for a `StaticCredentials` or a
  /// credential that was already reported.
  private(set) var handle: PortalSessionInvalidationHandle = .spent

  /// Runs inside the listener after the delivery has been counted.
  var onDeliver: (() -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onDeliver
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onDeliver = newValue
    }
  }

  private var _onDeliver: (() -> Void)?

  /// How many times the listener ran.
  var deliveries: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deliveries
  }

  /// Alias for `deliveries`, for matrix lines written as `recorder.count`.
  var count: Int {
    self.deliveries
  }

  /// How many deliveries observed `Thread.isMainThread == true`.
  var mainThreadDeliveries: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._mainThreadDeliveries
  }

  /// `true` when at least one delivery happened and every delivery was on the main thread.
  var allDeliveredOnMainThread: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deliveries > 0 && self._deliveries == self._mainThreadDeliveries
  }

  /// Subscribes to `credentials` immediately.
  init(credentials: PortalCredentials, onDeliver: (() -> Void)? = nil) {
    self._onDeliver = onDeliver
    self.handle = onCredentialsInvalidated(credentials) { [weak self] in
      self?.record()
    }
  }

  /// Cancels the subscription through the exposed handle.
  func cancel() {
    self.handle.cancel()
  }

  private func record() {
    self.lock.lock()
    self._deliveries += 1
    if Thread.isMainThread {
      self._mainThreadDeliveries += 1
    }
    let hook = self._onDeliver
    self.lock.unlock()

    hook?()
  }
}

// MARK: - PeerResetError

/// An error whose `localizedDescription` is exactly the text Starscream produces for a
/// TCP "connection reset by peer", which is the string `WebSocketClient.handleError` matches
/// on to decide whether to reconnect. Kept in one place so the peer-reset tests cannot drift
/// from the production comparison by a single character (note the typographic apostrophe).
struct PeerResetError: LocalizedError {
  /// The exact Starscream wording, including the U+2019 apostrophe.
  static let starscreamText = "The operation couldn’t be completed. Connection reset by peer"

  var errorDescription: String? {
    Self.starscreamText
  }
}

// MARK: - MpcJSON

/// Builders for the JSON envelopes the MPC binary and the enclave wrapper return, so tests
/// that script `MobileSpy` results do not hand-write (and mistype) the wire shape.
///
/// Every builder goes through `JSONSerialization` so ids and messages containing quotes or
/// backslashes are escaped correctly, and the keys are sorted so two builds of the same
/// envelope compare equal as strings.
enum MpcJSON {
  /// The id the Go binary (`errs.ErrAuthFailed`) and the enclave wrapper use for a rejected
  /// bearer; `PortalMpcError.isAuthFailure` matches it exactly.
  static let authFailedId = "AUTH_FAILED"

  /// A sign/generate/backup/recover envelope carrying an error:
  /// `{"data":null,"error":{"id":<id>,"message":<message>}}`. Decodes as `SignResult`,
  /// `GenerateResult`, `RotateResult` and the other `data`/`error` result types.
  static func error(id: String, message: String = "mpc operation failed") -> String {
    self.encode([
      "data": NSNull(),
      "error": ["id": id, "message": message]
    ])
  }

  /// The envelope the MPC layer returns when the client's credential was rejected, with the
  /// same message the enclave wrapper synthesises for an HTTP 401.
  static var authFailed: String {
    self.error(id: self.authFailedId, message: "401 - Unauthorized")
  }

  /// A presign envelope carrying an error, shaped like `PresignResponse`:
  /// `{"id":null,"expiresAt":null,"data":null,"error":{"id":<id>,"message":<message>}}`.
  static func presignError(id: String, message: String = "presign failed") -> String {
    self.encode([
      "id": NSNull(),
      "expiresAt": NSNull(),
      "data": NSNull(),
      "error": ["id": id, "message": message]
    ])
  }

  /// A presign envelope carrying an `AUTH_FAILED` error.
  static var presignAuthFailed: String {
    self.presignError(id: self.authFailedId, message: "401 - Unauthorized")
  }

  /// A successful sign envelope: `{"data":<signature>,"error":null}`.
  static func signSuccess(_ signature: String) -> String {
    self.encode([
      "data": signature,
      "error": NSNull()
    ])
  }

  /// A successful presign envelope shaped like `PresignResponse`.
  static func presignSuccess(id: String, expiresAt: String, data: String) -> String {
    self.encode([
      "id": id,
      "expiresAt": expiresAt,
      "data": data,
      "error": NSNull()
    ])
  }

  private static func encode(_ object: [String: Any]) -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
      let string = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return string
  }
}

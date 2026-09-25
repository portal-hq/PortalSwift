//
//  FakeAuthWebSession.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
@testable import PortalSwift

/// Thrown by `FakeAuthWebSession` when `authenticate` is reached with nothing left in `results`,
/// so a test that under-scripted the browser fails loudly instead of hanging.
enum FakeAuthWebSessionError: LocalizedError {
  case noScriptedResult

  var errorDescription: String? {
    switch self {
    case .noScriptedResult:
      return "FakeAuthWebSession: authenticate was called but `results` is empty. Script a callback URL or a failure first."
    }
  }
}

/// A scripted `AuthWebSessionProviding` standing in for the system browser in
/// `PortalAuth.signInWithGoogle()` / `signInWithApple()` tests.
///
/// `results` is a FIFO of callback URLs (or failures) — one per `authenticate` call — and every
/// call is recorded in `calls` with the exact arguments the module passed (URL, callback
/// scheme, anchor identity, ephemeral flag) plus whether it arrived on the main thread. Set
/// `holdUntilReleased` to park the call after recording it, so a test can observe the in-flight
/// guard, cancellation or a preference flip mid-sign-in; `release()` lets it continue and
/// `cancel()` fails it with `PortalAuthSignInError.closed`, exactly as the real adapter does when
/// the calling task is cancelled. Parking uses a continuation, never a blocked thread.
///
/// `factory` is the `() -> AuthWebSessionProviding` closure `PortalAuth`'s internal init takes;
/// it returns this same instance and counts `factoryInvocations`, which is how a test proves
/// the URL-only `loginWith*` path never builds a browser session.
final class FakeAuthWebSession: AuthWebSessionProviding, @unchecked Sendable {
  /// One `authenticate` call as the module made it.
  struct Call {
    let url: URL
    let callbackURLScheme: String
    /// The anchor passed in; compare identity with `===`.
    let anchor: ASPresentationAnchor
    let prefersEphemeral: Bool
    /// `Thread.isMainThread` at the moment of the call.
    let onMainThread: Bool
  }

  private let lock = NSLock()
  private var _results: [Swift.Result<URL, Error>]
  private var _calls: [Call] = []
  private var _holdUntilReleased = false
  private var parked: [CheckedContinuation<Void, Error>] = []
  private var _cancelCalls = 0
  private var _factoryInvocations = 0
  private var _onAuthenticate: ((Call) -> Void)?

  /// - Parameter results: The outcome of each successive `authenticate` call, in order.
  init(results: [Swift.Result<URL, Error>] = []) {
    self._results = results
  }

  // MARK: Scripting

  /// The outcome of each remaining `authenticate` call, FIFO. Settable so a test can re-script
  /// between attempts.
  var results: [Swift.Result<URL, Error>] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._results
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._results = newValue
    }
  }

  /// When `true`, an `authenticate` call is recorded and then parked until `release()` (proceeds
  /// to its scripted result) or `cancel()` (throws `.closed`). `release()` sets it back to `false`.
  var holdUntilReleased: Bool {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._holdUntilReleased
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._holdUntilReleased = newValue
    }
  }

  /// Runs inside `authenticate` right after the call is recorded, before any hold.
  var onAuthenticate: ((Call) -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onAuthenticate
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onAuthenticate = newValue
    }
  }

  /// Lets every parked `authenticate` call continue to its scripted result and clears
  /// `holdUntilReleased`, so the next call is not held. Idempotent.
  func release() {
    self.lock.lock()
    self._holdUntilReleased = false
    let waiters = self.parked
    self.parked = []
    self.lock.unlock()

    for waiter in waiters {
      waiter.resume()
    }
  }

  // MARK: Observation

  /// Every `authenticate` call, in order (recorded before any hold).
  var calls: [Call] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._calls
  }

  /// How many `authenticate` calls are parked right now.
  var parkedCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.parked.count
  }

  /// How many times `cancel()` was called.
  var cancelCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._cancelCalls
  }

  /// How many times `factory` was invoked.
  var factoryInvocations: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._factoryInvocations
  }

  /// The `webSessionFactory` to hand `PortalAuth`'s internal init: returns this instance and
  /// counts the invocation.
  var factory: () -> AuthWebSessionProviding {
    { [self] in
      self.lock.lock()
      self._factoryInvocations += 1
      self.lock.unlock()
      return self
    }
  }

  // MARK: AuthWebSessionProviding

  func authenticate(
    url: URL,
    callbackURLScheme: String,
    anchor: ASPresentationAnchor,
    prefersEphemeralWebBrowserSession: Bool
  ) async throws -> URL {
    // Recording happens in a synchronous helper: `NSLock` (and `Thread.isMainThread`) must not
    // be touched directly from an async body, and the main-thread flag has to be read before
    // the first suspension point to describe the thread the module called from.
    let (call, hook, hold) = self.recordCall(
      url: url,
      callbackURLScheme: callbackURLScheme,
      anchor: anchor,
      prefersEphemeral: prefersEphemeralWebBrowserSession
    )

    hook?(call)

    if hold {
      try await self.park()
    }

    return try self.nextResult()
  }

  /// Counts the call and fails every parked `authenticate` with `PortalAuthSignInError.closed`,
  /// as the real adapter does when the sign-in task is cancelled. A no-op otherwise.
  func cancel() {
    self.lock.lock()
    self._cancelCalls += 1
    let waiters = self.parked
    self.parked = []
    self.lock.unlock()

    for waiter in waiters {
      waiter.resume(throwing: PortalAuthSignInError.closed)
    }
  }

  // MARK: Private

  /// Records the call under the lock and snapshots the hook and hold flag with it, so the three
  /// are consistent even if a test flips `holdUntilReleased` concurrently.
  private func recordCall(
    url: URL,
    callbackURLScheme: String,
    anchor: ASPresentationAnchor,
    prefersEphemeral: Bool
  ) -> (call: Call, hook: ((Call) -> Void)?, hold: Bool) {
    let call = Call(
      url: url,
      callbackURLScheme: callbackURLScheme,
      anchor: anchor,
      prefersEphemeral: prefersEphemeral,
      onMainThread: Thread.isMainThread
    )

    self.lock.lock()
    defer { self.lock.unlock() }
    self._calls.append(call)
    return (call, self._onAuthenticate, self._holdUntilReleased)
  }

  /// Suspends until `release()` or `cancel()`. The hold flag is re-checked under the lock so a
  /// `release()` that raced the arrival is not missed.
  private func park() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.lock.lock()
      guard self._holdUntilReleased else {
        self.lock.unlock()
        continuation.resume()
        return
      }
      self.parked.append(continuation)
      self.lock.unlock()
    }
  }

  private func nextResult() throws -> URL {
    self.lock.lock()
    guard !self._results.isEmpty else {
      self.lock.unlock()
      throw FakeAuthWebSessionError.noScriptedResult
    }
    let result = self._results.removeFirst()
    self.lock.unlock()

    return try result.get()
  }
}

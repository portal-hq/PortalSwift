//
//  FakeWebAuthenticationSessionHandle.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
@testable import PortalSwift

/// A fake `ASWebAuthenticationSession` for the `ASWebAuthenticationSessionAdapter` seam.
///
/// The adapter builds sessions through its `SessionFactory`; `factory(recording:)` returns one
/// that builds these fakes instead. Each fake records how it was configured at the moment
/// `start()` ran — `providerWasSetAtStart`, `ephemeralAtStart`, `startedOnMainThread` — because
/// the contract under test is *ordering*: the provider and the ephemeral flag must be assigned
/// before `start()`, and `start()` must run on the main thread. `complete(url:error:)` fires the
/// completion handler the adapter installed, any number of times, so a test can prove the
/// continuation resumes exactly once.
///
/// `presentationContextProvider` is **weak**, exactly like the real property. That is what
/// makes the retention test meaningful: the adapter has to keep its
/// `AuthPresentationAnchorProvider` alive itself, or this reference goes `nil` before the run
/// loop turns. For the same reason the `Recorder` holds the handles it saw weakly — a test that
/// wants a handle after the adapter finished keeps its own strong reference.
final class FakeWebAuthenticationSessionHandle: WebAuthenticationSessionHandle {
  /// Collects the handles a `factory(recording:)` built and the arguments it was built with.
  final class Recorder: @unchecked Sendable {
    private final class WeakBox {
      weak var value: FakeWebAuthenticationSessionHandle?
      init(_ value: FakeWebAuthenticationSessionHandle) {
        self.value = value
      }
    }

    /// The `(url, callbackURLScheme)` of one factory invocation.
    struct Invocation {
      let url: URL
      let callbackURLScheme: String?
    }

    private let lock = NSLock()
    private var boxes: [WeakBox] = []
    private var _invocations: [Invocation] = []
    private var _startReturns = true
    private var _onCreate: ((FakeWebAuthenticationSessionHandle) -> Void)?

    init() {}

    /// The value every newly built handle's `start()` returns. Set it before `authenticate`
    /// runs — the handle is built on the main actor after the call begins.
    var startReturns: Bool {
      get {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self._startReturns
      }
      set {
        self.lock.lock()
        defer { self.lock.unlock() }
        self._startReturns = newValue
      }
    }

    /// Runs with each handle right after it is built, before the adapter configures it.
    var onCreate: ((FakeWebAuthenticationSessionHandle) -> Void)? {
      get {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self._onCreate
      }
      set {
        self.lock.lock()
        defer { self.lock.unlock() }
        self._onCreate = newValue
      }
    }

    /// Every factory invocation's arguments, in order.
    var invocations: [Invocation] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._invocations
    }

    /// How many handles the factory built (including ones since deallocated).
    var createdCount: Int {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.boxes.count
    }

    /// The handles still alive, in creation order. Held weakly (see the type documentation).
    var handles: [FakeWebAuthenticationSessionHandle] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.boxes.compactMap { $0.value }
    }

    /// The most recently built handle, if it is still alive.
    var latest: FakeWebAuthenticationSessionHandle? {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.boxes.last?.value
    }

    fileprivate func record(_ handle: FakeWebAuthenticationSessionHandle, url: URL, callbackURLScheme: String?) {
      self.lock.lock()
      self.boxes.append(WeakBox(handle))
      self._invocations.append(Invocation(url: url, callbackURLScheme: callbackURLScheme))
      let hook = self._onCreate
      self.lock.unlock()

      hook?(handle)
    }
  }

  private let lock = NSLock()
  private let completionHandler: (URL?, Error?) -> Void
  private var _startReturns: Bool
  private var _startCalls = 0
  private var _startedOnMainThread: Bool?
  private var _providerWasSetAtStart: Bool?
  private var _ephemeralAtStart: Bool?
  private var _cancelCalls = 0
  private var _cancelCallsAfterStart = 0
  private var _onStart: (() -> Void)?

  /// The URL the adapter asked the session to open.
  let url: URL
  /// The callback scheme the adapter passed.
  let callbackURLScheme: String?

  /// Weak, like `ASWebAuthenticationSession.presentationContextProvider`. Assigned by the
  /// adapter on the main actor; read it from a test after `start()` has run.
  weak var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?

  /// Assigned by the adapter on the main actor before `start()`.
  var prefersEphemeralWebBrowserSession = false

  /// - Parameters:
  ///   - url: What the adapter asked to open.
  ///   - callbackURLScheme: The scheme the adapter passed.
  ///   - startReturns: What `start()` reports; `false` models a session the system refused.
  ///   - completionHandler: The adapter's completion, fired by `complete(url:error:)`.
  init(
    url: URL,
    callbackURLScheme: String?,
    startReturns: Bool = true,
    completionHandler: @escaping (URL?, Error?) -> Void
  ) {
    self.url = url
    self.callbackURLScheme = callbackURLScheme
    self._startReturns = startReturns
    self.completionHandler = completionHandler
  }

  /// Builds an adapter `SessionFactory` that creates a fake per call and reports each one to
  /// `recorder`, so the test can reach the handle to `complete(url:error:)` it.
  static func factory(recording recorder: Recorder) -> ASWebAuthenticationSessionAdapter.SessionFactory {
    { url, callbackURLScheme, completionHandler in
      let handle = FakeWebAuthenticationSessionHandle(
        url: url,
        callbackURLScheme: callbackURLScheme,
        startReturns: recorder.startReturns,
        completionHandler: completionHandler
      )
      recorder.record(handle, url: url, callbackURLScheme: callbackURLScheme)
      return handle
    }
  }

  // MARK: Scripting and observation

  /// What `start()` returns.
  var startReturns: Bool {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._startReturns
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._startReturns = newValue
    }
  }

  /// How many times `start()` was called.
  var startCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._startCalls
  }

  /// `Thread.isMainThread` when `start()` ran; `nil` before the first `start()`.
  var startedOnMainThread: Bool? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._startedOnMainThread
  }

  /// Whether `presentationContextProvider` was non-nil when `start()` ran; `nil` before it.
  var providerWasSetAtStart: Bool? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._providerWasSetAtStart
  }

  /// `prefersEphemeralWebBrowserSession` when `start()` ran; `nil` before it.
  var ephemeralAtStart: Bool? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._ephemeralAtStart
  }

  /// How many times `cancel()` was called.
  var cancelCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._cancelCalls
  }

  /// How many of those `cancel()` calls arrived after `start()` had run. A cancel before `start()`
  /// is a no-op on the system class, so only these dismiss a presented session.
  var cancelCallsAfterStart: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._cancelCallsAfterStart
  }

  /// Runs inside `start()`, before the call is recorded and outside the handle's lock: the
  /// moment just before the system would present the browser. Lets a test reproduce a
  /// cancellation that lands between the adapter's `.running` transition and `start()` — a
  /// `cancel()` made from here counts as *before* start, as it would on the system class.
  var onStart: (() -> Void)? {
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

  /// Fires the adapter's completion handler with `url` / `error`, on the calling thread. May be
  /// called any number of times; the adapter must resume its continuation only once.
  func complete(url: URL?, error: Error?) {
    self.completionHandler(url, error)
  }

  // MARK: WebAuthenticationSessionHandle

  func start() -> Bool {
    let providerSet = self.presentationContextProvider != nil
    let ephemeral = self.prefersEphemeralWebBrowserSession

    // Outside the lock: the hook may call back into the adapter, which calls `cancel()` here.
    // Before the call is recorded, so a cancel made from the hook reads as one that arrived
    // before `start()`.
    self.onStart?()

    self.lock.lock()
    defer { self.lock.unlock() }
    self._startCalls += 1
    self._startedOnMainThread = Thread.isMainThread
    self._providerWasSetAtStart = providerSet
    self._ephemeralAtStart = ephemeral
    return self._startReturns
  }

  func cancel() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._cancelCalls += 1
    if self._startCalls > 0 {
      self._cancelCallsAfterStart += 1
    }
  }
}

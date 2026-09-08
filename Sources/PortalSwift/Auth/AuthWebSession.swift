//
//  AuthWebSession.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
#if canImport(UIKit)
  import UIKit
#endif

// MARK: - AuthWebSessionProviding

/// The one thing `PortalAuth.signInWithGoogle()` / `signInWithApple()` need from the system
/// browser: open `url`, wait for a redirect to `callbackURLScheme`, hand the callback URL
/// back. Behind a protocol so the sign-in orchestration can be unit-tested with a fake that
/// never presents UI; the production implementation is `ASWebAuthenticationSessionAdapter`.
protocol AuthWebSessionProviding: AnyObject {
  /// Presents the browser anchored to `anchor` and returns the callback URL.
  ///
  /// - Throws: `PortalAuthSignInError.closed` when the user dismissed the browser or the task
  ///   was cancelled, `.unavailable` when the session could not be presented,
  ///   `.callbackIncomplete` when the browser finished with neither URL nor error; any other
  ///   system error is passed through unchanged.
  func authenticate(
    url: URL,
    callbackURLScheme: String,
    anchor: ASPresentationAnchor,
    prefersEphemeralWebBrowserSession: Bool
  ) async throws -> URL

  /// Dismisses an in-flight session, failing `authenticate` with `.closed`. A no-op when
  /// nothing is in flight or the session has already completed.
  func cancel()
}

// MARK: - WebAuthenticationSessionHandle

/// The slice of `ASWebAuthenticationSession` the adapter drives, so a test can substitute a
/// fake that records how it was configured and fires the completion on demand.
protocol WebAuthenticationSessionHandle: AnyObject {
  var presentationContextProvider: ASWebAuthenticationPresentationContextProviding? { get set }
  var prefersEphemeralWebBrowserSession: Bool { get set }
  func start() -> Bool
  func cancel()
}

extension ASWebAuthenticationSession: WebAuthenticationSessionHandle {}

// MARK: - AuthPresentationAnchorProvider

/// Answers `ASWebAuthenticationSession`'s request for a window with the anchor the host
/// registered through `PortalAuth.setAuthPresentationAnchor(_:)`.
///
/// `ASWebAuthenticationSession.presentationContextProvider` is a *weak* property, so this
/// object must be kept alive by whoever starts the session for as long as the session runs;
/// the adapter stores it until the completion fires. A throwaway provider would deallocate
/// before the run loop turned and every sign-in would fail with
/// `presentationContextNotProvided`.
final class AuthPresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  private let anchor: ASPresentationAnchor

  init(anchor: ASPresentationAnchor) {
    self.anchor = anchor
    super.init()
  }

  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    self.anchor
  }
}

// MARK: - ASWebAuthenticationSessionAdapter

/// The production `AuthWebSessionProviding`: one `ASWebAuthenticationSession` per
/// `authenticate` call, bridged to `async`.
///
/// The adapter is a small state machine guarded by one `NSLock`:
///
/// - `idle` → `authenticate` registers its continuation (`pending`) and hops to the main
///   actor, where the session is built through `sessionFactory`, configured
///   (`presentationContextProvider` and `prefersEphemeralWebBrowserSession` are set *before*
///   `start()`), retained together with its `AuthPresentationAnchorProvider` (`running`), and
///   started. `start() == false` fails the call with `PortalAuthSignInError.unavailable`.
/// - Only the transition out of `running`/`pending` resumes the continuation, so it resumes
///   exactly once even if the system fires the completion more than once. Finishing also
///   releases the session and the provider.
/// - Task cancellation calls `cancel()`, which dismisses the session and fails the call with
///   `.closed` itself rather than waiting for the system to report `canceledLogin`; a
///   cancellation that lands before the main-actor hop fails the call the same way and the
///   session is never started. One that lands between the transition to `running` and
///   `start()` has cancelled a session that was not yet started (a no-op on the system class),
///   so `begin` re-checks after `start()` and dismisses the session it just presented.
///   `cancel()` once the call has finished is a no-op.
///
/// Errors from the completion go through `mapError(_:)`: `canceledLogin` → `.closed`,
/// `presentationContextNotProvided` / `presentationContextInvalid` → `.unavailable`,
/// anything else unchanged. Only iOS 12/13 APIs are used (the iOS 17.4 callback API is not),
/// so the adapter compiles at both the SwiftPM (iOS 15) and CocoaPods (iOS 13) floors.
final class ASWebAuthenticationSessionAdapter: AuthWebSessionProviding, @unchecked Sendable {
  /// Builds the session for `(url, callbackURLScheme, completionHandler)`. The default wraps
  /// `ASWebAuthenticationSession.init(url:callbackURLScheme:completionHandler:)`.
  typealias SessionFactory = (URL, String?, @escaping (URL?, Error?) -> Void) -> WebAuthenticationSessionHandle

  private enum State {
    /// No `authenticate` call in flight.
    case idle
    /// A call has registered its continuation and is waiting for the main-actor hop.
    case pending(CheckedContinuation<URL, Error>)
    /// The session has been built and started; both it and the provider are retained here.
    case running(CheckedContinuation<URL, Error>, WebAuthenticationSessionHandle, AuthPresentationAnchorProvider)
  }

  private let sessionFactory: SessionFactory
  private let lock = NSLock()
  private var state: State = .idle

  /// The production adapter, backed by a real `ASWebAuthenticationSession`.
  convenience init() {
    self.init(sessionFactory: { url, callbackURLScheme, completionHandler in
      ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
    })
  }

  /// Test seam: builds sessions through `sessionFactory` instead of `ASWebAuthenticationSession`.
  init(sessionFactory: @escaping SessionFactory) {
    self.sessionFactory = sessionFactory
  }

  // MARK: AuthWebSessionProviding

  func authenticate(
    url: URL,
    callbackURLScheme: String,
    anchor: ASPresentationAnchor,
    prefersEphemeralWebBrowserSession: Bool
  ) async throws -> URL {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        self.lock.lock()
        guard case .idle = self.state else {
          self.lock.unlock()
          // A second call on a busy adapter would otherwise orphan its continuation.
          continuation.resume(throwing: PortalAuthSignInError.signInInProgress)
          return
        }
        self.state = .pending(continuation)
        self.lock.unlock()

        // Entered on an already-cancelled task: `withTaskCancellationHandler` ran `cancel()`
        // before this body, at `.idle`, where it was a no-op — and the unstructured `Task` below
        // does not inherit cancellation. Without this check the browser sheet would be presented
        // for a sign-in nobody is waiting for and the caller would wait for the user to dismiss
        // it. `Task.isCancelled` is valid here because the continuation body runs synchronously
        // in the caller's task.
        if Task.isCancelled {
          self.cancel()
          return
        }

        Task { @MainActor in
          self.begin(
            url: url,
            callbackURLScheme: callbackURLScheme,
            anchor: anchor,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
          )
        }
      }
    } onCancel: {
      self.cancel()
    }
  }

  func cancel() {
    self.lock.lock()
    let previous = self.state
    switch previous {
    case .idle:
      self.lock.unlock()
      return
    case .pending, .running:
      self.state = .idle
    }
    self.lock.unlock()

    switch previous {
    case .idle:
      return
    case let .pending(continuation):
      continuation.resume(throwing: PortalAuthSignInError.closed)
    case let .running(continuation, handle, _):
      handle.cancel()
      continuation.resume(throwing: PortalAuthSignInError.closed)
    }
  }

  // MARK: Error mapping

  /// Maps the system's `ASWebAuthenticationSessionError` codes onto the cross-SDK sign-in
  /// codes; every other error (including unknown codes in the same domain) passes through.
  static func mapError(_ error: Error) -> Error {
    guard let sessionError = error as? ASWebAuthenticationSessionError else {
      return error
    }

    switch sessionError.code {
    case .canceledLogin:
      return PortalAuthSignInError.closed
    case .presentationContextNotProvided, .presentationContextInvalid:
      return PortalAuthSignInError.unavailable
    default:
      return error
    }
  }

  // MARK: Private

  /// Builds, configures, retains and starts the session. Runs on the main actor because
  /// `ASWebAuthenticationSession` presents UI.
  @MainActor
  private func begin(
    url: URL,
    callbackURLScheme: String,
    anchor: ASPresentationAnchor,
    prefersEphemeralWebBrowserSession: Bool
  ) {
    let handle = self.sessionFactory(url, callbackURLScheme) { [weak self] callbackURL, error in
      self?.complete(callbackURL: callbackURL, error: error)
    }
    let provider = AuthPresentationAnchorProvider(anchor: anchor)
    handle.presentationContextProvider = provider
    handle.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

    self.lock.lock()
    guard case let .pending(continuation) = self.state else {
      // Cancelled between the registration and this hop: the continuation has already been
      // failed with `.closed`, so the session is discarded without ever being started.
      self.lock.unlock()
      return
    }
    self.state = .running(continuation, handle, provider)
    self.lock.unlock()

    guard handle.start() else {
      self.finish(.failure(PortalAuthSignInError.unavailable))
      return
    }

    // `cancel()` may have run between the transition to `.running` above and `start()`. It
    // then cancelled a session that had not started — a no-op on `ASWebAuthenticationSession`
    // — and failed the continuation with `.closed`, and `start()` has just presented the browser
    // anyway. If this handle is no longer the active run, dismiss it; every later completion is
    // already ignored by `finish`.
    self.lock.lock()
    let stillActive: Bool
    if case let .running(_, activeHandle, _) = self.state, activeHandle === handle {
      stillActive = true
    } else {
      stillActive = false
    }
    self.lock.unlock()

    if !stillActive {
      handle.cancel()
    }
  }

  private func complete(callbackURL: URL?, error: Error?) {
    if let error = error {
      self.finish(.failure(Self.mapError(error)))
    } else if let callbackURL = callbackURL {
      self.finish(.success(callbackURL))
    } else {
      self.finish(.failure(PortalAuthSignInError.callbackIncomplete))
    }
  }

  /// Resumes the in-flight continuation exactly once and releases the session and provider.
  /// A completion that arrives after the call has already finished is ignored.
  private func finish(_ result: Swift.Result<URL, Error>) {
    self.lock.lock()
    let continuation: CheckedContinuation<URL, Error>
    switch self.state {
    case .idle:
      self.lock.unlock()
      return
    case let .pending(pending):
      continuation = pending
    case let .running(running, _, _):
      continuation = running
    }
    self.state = .idle
    self.lock.unlock()

    continuation.resume(with: result)
  }
}

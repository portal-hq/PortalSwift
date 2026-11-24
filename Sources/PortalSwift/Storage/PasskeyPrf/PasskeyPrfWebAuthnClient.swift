//
//  PasskeyPrfWebAuthnClient.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import CryptoKit
import Foundation

/// A passkey creation that also evaluates the PRF salt, when the provider can.
struct PasskeyPrfCreateRequest {
  let rpId: String
  let userId: Data
  let userName: String
  let userDisplayName: String
  let challenge: Data
  /// The PRF salt, as the WebAuthn `prf.eval.first` input (32 raw bytes, not pre-hashed).
  let prfSalt: Data
}

struct PasskeyPrfCreateResult {
  let credentialId: Data
  let transports: [String]?
  /// Whether the passkey provider reported PRF support for the new passkey.
  let prfEnabled: Bool
  /// Present when the provider evaluated the salt while creating the passkey.
  var prfOutput: Data?
}

/// An assertion restricted to one passkey that evaluates the PRF salt.
struct PasskeyPrfGetRequest {
  let rpId: String
  let challenge: Data
  let allowCredentialId: Data
  /// The PRF salt, as the WebAuthn `prf.eval.first` input (32 raw bytes, not pre-hashed).
  let prfSalt: Data
}

struct PasskeyPrfGetResult {
  let credentialId: Data
  var prfOutput: Data?
}

/// How a ceremony ended when it did not produce a credential.
enum PasskeyPrfCeremonyError: Error {
  /// The person dismissed the prompt, or it timed out.
  case cancelled(Error?)
  /// The platform had no passkey to offer for the request.
  case noCredentials(Error?)
  /// No window to present the passkey prompt from.
  case noPresentationAnchor
  /// Any other failure, including a credential of an unexpected type.
  case failed(Error?)
}

/// Runs the WebAuthn ceremonies for `PasskeyPrfStorage`. Mirrors the `WebAuthnClient` used by the
/// React Native and web SDKs, so the storage logic can be tested without a passkey provider.
protocol PasskeyPrfWebAuthnClient: AnyObject {
  var anchor: ASPresentationAnchor? { get set }
  func createCredential(_ request: PasskeyPrfCreateRequest) async throws -> PasskeyPrfCreateResult
  func getCredential(_ request: PasskeyPrfGetRequest) async throws -> PasskeyPrfGetResult
}

/// Runs the ceremonies with the platform passkey provider through `ASAuthorizationController`.
///
/// The salt is handed to AuthenticationServices unhashed, as the WebAuthn `prf.eval.first`
/// value. AuthenticationServices applies the WebAuthn PRF transform
/// (`SHA-256("WebAuthn PRF" || 0x00 || salt)`) before the credential's PRF is evaluated, exactly
/// as WebKit and Chromium rely on when they pass a page's `eval.first` through the same API, so
/// the output matches what browsers and Android return for the same passkey and salt.
@available(iOS 18.0, *)
final class PasskeyPrfAuthorizationClient: PasskeyPrfWebAuthnClient {
  var anchor: ASPresentationAnchor?

  init(anchor: ASPresentationAnchor? = nil) {
    self.anchor = anchor
  }

  func createCredential(_ request: PasskeyPrfCreateRequest) async throws -> PasskeyPrfCreateResult {
    let credential = try await self.perform {
      let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId)
      let registration = provider.createCredentialRegistrationRequest(
        challenge: request.challenge,
        name: request.userName,
        userID: request.userId
      )
      registration.displayName = request.userDisplayName
      registration.userVerificationPreference = .required
      registration.attestationPreference = .none
      registration.prf = .inputValues(.init(saltInput1: request.prfSalt))
      return registration
    }

    guard let registration = credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
      throw PasskeyPrfCeremonyError.failed(nil)
    }

    let prf = registration.prf
    return PasskeyPrfCreateResult(
      credentialId: registration.credentialID,
      // Platform registrations do not report transports; Portal stores none, as the React
      // Native SDK does on iOS.
      transports: nil,
      prfEnabled: prf?.isSupported ?? false,
      prfOutput: prf?.first.map(Self.bytes(of:))
    )
  }

  func getCredential(_ request: PasskeyPrfGetRequest) async throws -> PasskeyPrfGetResult {
    let credential = try await self.perform {
      let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId)
      let assertion = provider.createCredentialAssertionRequest(challenge: request.challenge)
      assertion.allowedCredentials = [
        ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: request.allowCredentialId)
      ]
      assertion.userVerificationPreference = .required
      assertion.prf = .inputValues(.init(saltInput1: request.prfSalt))
      return assertion
    }

    guard let assertion = credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
      throw PasskeyPrfCeremonyError.failed(nil)
    }

    return PasskeyPrfGetResult(
      credentialId: assertion.credentialID,
      prfOutput: assertion.prf.map { Self.bytes(of: $0.first) }
    )
  }

  /// `canceled` covers a dismissed or timed-out prompt; `notInteractive` is what the platform
  /// reports when it had no passkey to offer (the React Native SDK's iOS bridge maps the same
  /// codes to `UserCancelled` and `NoCredentials`). Everything else is a ceremony failure.
  static func ceremonyError(from error: Error) -> PasskeyPrfCeremonyError {
    guard let authorizationError = error as? ASAuthorizationError else {
      return .failed(error)
    }
    switch authorizationError.code {
    case .canceled:
      return .cancelled(error)
    case .notInteractive:
      return .noCredentials(error)
    default:
      return .failed(error)
    }
  }

  /// Copies the key's bytes out. `SymmetricKey` clears its own storage when released; the copy
  /// is cleared by `PasskeyPrfStorage` once it has been encoded.
  private static func bytes(of key: SymmetricKey) -> Data {
    key.withUnsafeBytes { Data($0) }
  }

  /// Presents one passkey prompt. Cancelling the calling task dismisses the prompt and throws
  /// `CancellationError`; a task that is already cancelled never shows it.
  @MainActor
  private func perform(_ makeRequest: () -> ASAuthorizationRequest) async throws -> ASAuthorizationCredential {
    guard let anchor = self.anchor else {
      throw PasskeyPrfCeremonyError.noPresentationAnchor
    }
    try Task.checkCancellation()
    let request = makeRequest()
    let session = PasskeyPrfAuthorizationSession(anchor: anchor)

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        session.start(with: request, continuation: continuation)
      }
    } onCancel: {
      Task { @MainActor in
        session.cancel()
      }
    }
  }
}

/// One `ASAuthorizationController` run. The controller holds its delegate weakly, so the
/// session keeps itself alive until the system reports an outcome.
///
/// `@unchecked Sendable` because the task cancellation handler hands it to the main actor; all
/// of its state is read and written on the main thread, where the controller calls its delegate.
@available(iOS 18.0, *)
private final class PasskeyPrfAuthorizationSession: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, @unchecked Sendable {
  private let anchor: ASPresentationAnchor
  private var continuation: CheckedContinuation<ASAuthorizationCredential, Error>?
  private var controller: ASAuthorizationController?
  private var retainedSelf: PasskeyPrfAuthorizationSession?
  /// Set when the task running the ceremony is cancelled.
  private var isCancelled = false

  init(anchor: ASPresentationAnchor) {
    self.anchor = anchor
  }

  @MainActor
  func start(with request: ASAuthorizationRequest, continuation: CheckedContinuation<ASAuthorizationCredential, Error>) {
    self.continuation = continuation
    guard !self.isCancelled else {
      self.resume(.failure(CancellationError()))
      return
    }
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.controller = controller
    self.retainedSelf = self
    controller.performRequests()
  }

  /// Dismisses the prompt for a cancelled task and throws `CancellationError` right away, rather
  /// than waiting for the controller to report its own cancel. The session stays alive until that
  /// report, so the controller is not released while it dismisses the prompt.
  @MainActor
  func cancel() {
    self.isCancelled = true
    guard let controller = self.controller else {
      // Not started yet: `start` sees the flag and never presents.
      return
    }
    controller.cancel()
    self.resume(.failure(CancellationError()))
  }

  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    self.anchor
  }

  func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    self.finish(.success(authorization.credential))
  }

  func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
    self.finish(.failure(PasskeyPrfAuthorizationClient.ceremonyError(from: error)))
  }

  /// The controller's outcome: resumes the caller unless a cancel already did, then releases
  /// the controller and the session.
  private func finish(_ result: Swift.Result<ASAuthorizationCredential, Error>) {
    self.resume(result)
    self.controller = nil
    self.retainedSelf = nil
  }

  /// Resumes the caller exactly once.
  private func resume(_ result: Swift.Result<ASAuthorizationCredential, Error>) {
    let continuation = self.continuation
    self.continuation = nil
    continuation?.resume(with: result)
  }
}

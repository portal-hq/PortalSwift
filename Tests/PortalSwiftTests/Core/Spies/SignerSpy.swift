//
//  SignerSpy.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A `PortalSignerProtocol` double that records exactly what `PortalProvider` hands the signer,
/// so a test can prove the credential was resolved at the right moment and passed through
/// unchanged.
///
/// The provider is supposed to resolve the bearer token only after the user has approved a
/// signing request and then pass it to the `token:` overload for that one call. This spy keeps
/// every argument of every call (`signCalls`), the tokens in order (`signTokenParams`), and
/// counts calls to the token-less legacy overload separately (`legacySignCallsCount`) so a
/// regression that routes the SDK back through the old contract shows up as a non-zero count.
/// `onSign` runs synchronously inside the call, before the return value or error is produced,
/// which is how a test observes state at signing time (for example, how many times
/// `getToken()` had been called by then). All state is lock-guarded because the provider signs
/// from its own queue.
final class SignerSpy: PortalSignerProtocol {
  /// Everything one `sign` call received. `token` is `nil` for the legacy token-less overload.
  struct SignCall {
    let chainId: String
    let payload: PortalSignRequest
    let rpcUrl: String
    let blockchain: PortalBlockchain
    let signatureApprovalMemo: String?
    let sponsorGas: Bool?
    let reqId: String?
    let token: String?

    /// `true` when the call came through the `token:` overload the SDK is expected to use.
    var isTokenOverload: Bool {
      self.token != nil
    }
  }

  private let lock = NSLock()
  private var _signCalls: [SignCall] = []
  private var _returnValue: String = MockConstants.mockSignature
  private var _errorToThrow: Error?
  private var _onSign: ((SignCall) throws -> Void)?

  init() {}

  // MARK: - Configuration

  /// The signature returned by every successful call. Defaults to `MockConstants.mockSignature`.
  var returnValue: String {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._returnValue
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._returnValue = newValue
    }
  }

  /// When set, every call throws this after recording its arguments and running `onSign`.
  /// Use a `PortalMpcError` with id `AUTH_FAILED` to exercise the provider's reporting path.
  var errorToThrow: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._errorToThrow
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._errorToThrow = newValue
    }
  }

  /// Runs inside every call, after the arguments are recorded and before the result is produced.
  /// An error thrown here propagates to the caller in place of `returnValue`/`errorToThrow`.
  /// Invoked outside the lock so the hook may read this spy's own counters.
  var onSign: ((SignCall) throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onSign
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onSign = newValue
    }
  }

  // MARK: - Recording

  /// Every call to either overload, in call order.
  var signCalls: [SignCall] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._signCalls
  }

  /// The most recent call to either overload, if any.
  var lastSignCall: SignCall? {
    self.signCalls.last
  }

  /// Calls that came through the `token:` overload, in call order.
  var signTokenCalls: [SignCall] {
    self.signCalls.filter { $0.isTokenOverload }
  }

  /// How many calls came through the `token:` overload.
  var signTokenCallsCount: Int {
    self.signTokenCalls.count
  }

  /// The `token` argument of every `token:` overload call, in call order.
  var signTokenParams: [String] {
    self.signTokenCalls.compactMap { $0.token }
  }

  /// The `chainId` argument of every `token:` overload call, in call order.
  var signChainIdParams: [String] {
    self.signTokenCalls.map { $0.chainId }
  }

  /// The `withPayload` argument of every `token:` overload call, in call order.
  var signPayloadParams: [PortalSignRequest] {
    self.signTokenCalls.map { $0.payload }
  }

  /// The `reqId` argument of every `token:` overload call, in call order.
  var signReqIdParams: [String?] {
    self.signTokenCalls.map { $0.reqId }
  }

  /// How many calls came through the legacy token-less overload. The SDK never calls it, so
  /// anything other than zero after driving the provider is a regression.
  var legacySignCallsCount: Int {
    self.signCalls.filter { !$0.isTokenOverload }.count
  }

  /// Forgets every recorded call. Configuration (`returnValue`, `errorToThrow`, `onSign`) is kept.
  func reset() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._signCalls.removeAll()
  }

  // MARK: - PortalSignerProtocol

  /// The legacy overload. Recorded with a `nil` token and counted in `legacySignCallsCount`;
  /// otherwise behaves like the `token:` overload so a test that deliberately drives the old
  /// contract still gets a deterministic result.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?
  ) async throws -> String {
    try self.record(
      SignCall(
        chainId: chainId,
        payload: withPayload,
        rpcUrl: andRpcUrl,
        blockchain: usingBlockchain,
        signatureApprovalMemo: signatureApprovalMemo,
        sponsorGas: sponsorGas,
        reqId: reqId,
        token: nil
      )
    )
  }

  /// The overload the SDK uses: records every argument including `token`, runs `onSign`, then
  /// throws `errorToThrow` or returns `returnValue`. The token is kept only in the recorded call,
  /// never used, so the spy has no opinion about its validity.
  func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String?,
    sponsorGas: Bool?,
    reqId: String?,
    token: String
  ) async throws -> String {
    try self.record(
      SignCall(
        chainId: chainId,
        payload: withPayload,
        rpcUrl: andRpcUrl,
        blockchain: usingBlockchain,
        signatureApprovalMemo: signatureApprovalMemo,
        sponsorGas: sponsorGas,
        reqId: reqId,
        token: token
      )
    )
  }

  // MARK: - Private

  private func record(_ call: SignCall) throws -> String {
    self.lock.lock()
    self._signCalls.append(call)
    let hook = self._onSign
    let error = self._errorToThrow
    let value = self._returnValue
    self.lock.unlock()

    try hook?(call)
    if let error = error {
      throw error
    }
    return value
  }
}

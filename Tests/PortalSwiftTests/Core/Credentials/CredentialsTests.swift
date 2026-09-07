//
//  CredentialsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers the free functions in `Core/Credentials/Credentials.swift` that sit at the SDK's
/// credential boundary (`resolveCredentials`, `resolveCredentialToken`, `staticApiKeyOf`,
/// `installUnauthorizedHook`, `reportUnauthorizedAndLog`) and the `StaticCredentials` wrapper.
///
/// There is no shared subject: every case builds its own `MockCredentials`. The logger sink
/// is captured for the whole case so the "never logs the token" assertions are real, and the
/// invalidation registry is reset around each case so once-ever reported flags cannot leak
/// between tests.
final class CredentialsTests: XCTestCase {
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    MockURLProtocol.reset()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    MockURLProtocol.reset()
    try super.tearDownWithError()
  }

  // MARK: - resolveCredentials

  func test_resolveCredentials_willWrapApiKeyInStaticCredentials() throws {
    let resolved = try resolveCredentials(apiKey: "client-api-key", credentials: nil)

    let wrapped = resolved as? StaticCredentials
    XCTAssertNotNil(wrapped, "Expected a StaticCredentials, got \(type(of: resolved))")
    XCTAssertEqual(wrapped?.value, "client-api-key")
    XCTAssertEqual(try resolved.getToken(), "client-api-key")
  }

  func test_resolveCredentials_willReturnSuppliedCredentialsUnchanged() throws {
    let credentials = MockCredentials()

    let resolved = try resolveCredentials(apiKey: nil, credentials: credentials)

    XCTAssertTrue(resolved === credentials, "Expected the very same credential object back")
  }

  func test_resolveCredentials_willPreferCredentials_whenApiKeyIsEmpty() throws {
    let credentials = MockCredentials()

    let resolved = try resolveCredentials(apiKey: "", credentials: credentials)

    XCTAssertTrue(resolved === credentials)
    XCTAssertFalse(resolved is StaticCredentials, "An empty apiKey must not produce a StaticCredentials")
  }

  func test_resolveCredentials_willPreferCredentials_whenBothSupplied() throws {
    let credentials = MockCredentials()

    // PLAN 4.2: "credentials wins" — a deliberate divergence from Android's IllegalArgumentException.
    let resolved = try resolveCredentials(apiKey: "client-api-key", credentials: credentials)

    XCTAssertTrue(resolved === credentials)
    XCTAssertFalse(resolved is StaticCredentials)
  }

  func test_resolveCredentials_willThrowInvalidApiKey_whenNeitherSupplied() {
    XCTAssertThrowsError(try resolveCredentials(apiKey: nil, credentials: nil)) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .invalidApiKey)
      XCTAssertNil(credentialError?.reason)
    }
  }

  func test_resolveCredentials_willThrowInvalidApiKey_whenApiKeyIsEmpty() {
    XCTAssertThrowsError(try resolveCredentials(apiKey: "", credentials: nil)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
  }

  func test_resolveCredentials_willThrowInvalidApiKey_whenApiKeyIsWhitespaceOnly() {
    XCTAssertThrowsError(try resolveCredentials(apiKey: "   \t\n", credentials: nil)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .invalidApiKey)
    }
  }

  func test_resolveCredentials_willKeepSurroundingWhitespace_whenApiKeyIsNonBlank() throws {
    let resolved = try resolveCredentials(apiKey: " key ", credentials: nil)

    XCTAssertEqual((resolved as? StaticCredentials)?.value, " key ", "The SDK must not trim; the server decides")
    XCTAssertEqual(try resolved.getToken(), " key ")
  }

  // MARK: - resolveCredentialToken

  func test_resolveCredentialToken_willReturnTokenFromGetToken() throws {
    let credentials = MockCredentials(tokenValue: "test-api-key")

    let token = try resolveCredentialToken(credentials)

    XCTAssertEqual(token, "test-api-key")
    XCTAssertEqual(credentials.getTokenCalls, 1)
  }

  func test_resolveCredentialToken_willResolveAgainOnEveryCall() throws {
    let credentials = MockCredentials(tokenValue: "first")

    let first = try resolveCredentialToken(credentials)
    credentials.tokenValue = "second"
    let second = try resolveCredentialToken(credentials)

    XCTAssertEqual(first, "first")
    XCTAssertEqual(second, "second")
    XCTAssertEqual(credentials.getTokenCalls, 2, "The token must never be cached")
  }

  func test_resolveCredentialToken_willThrowProviderFailure_whenGetTokenThrowsArbitraryError() {
    let cause = NSError(domain: "keystore", code: 7)
    let credentials = MockCredentials(onGetToken: { throw cause })

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      guard let credentialError = error as? PortalCredentialError else {
        return XCTFail("Expected PortalCredentialError, got \(type(of: error))")
      }
      XCTAssertEqual(credentialError, .providerFailure(underlying: cause))
      XCTAssertEqual(credentialError.reason, .providerFailure)

      guard case let .providerFailure(underlying) = credentialError else {
        return XCTFail("Expected .providerFailure, got \(credentialError)")
      }
      let nsUnderlying = underlying as NSError
      XCTAssertEqual(nsUnderlying.domain, "keystore")
      XCTAssertEqual(nsUnderlying.code, 7)
    }
  }

  func test_resolveCredentialToken_willKeepUnderlyingFailureOffMessage() {
    let cause = NSError(domain: "keystore", code: 1, userInfo: [NSLocalizedDescriptionKey: "keystore path /secret unreadable"])
    let credentials = MockCredentials(onGetToken: { throw cause })

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError?.errorDescription, "[Portal] The credential provider failed to supply a credential.")
      XCTAssertFalse(credentialError?.errorDescription?.contains("secret") ?? true)
      XCTAssertFalse(error.localizedDescription.contains("secret"))
    }
  }

  func test_resolveCredentialToken_willPassThroughPortalCredentialError_withReasonIntact() {
    let credentials = MockCredentials(onGetToken: { throw PortalCredentialError.sessionInvalidated })

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .sessionInvalidated)
      XCTAssertEqual(credentialError?.reason, .sessionInvalidated)
      XCTAssertEqual(credentialError?.requiresReauthentication, true)
      XCTAssertNotEqual(credentialError, .providerFailure(underlying: NSError(domain: "x", code: 0)), "Must not be downgraded to providerFailure")
    }
  }

  func test_resolveCredentialToken_willPassThroughUnavailable_whenProviderThrowsUnavailable() {
    let credentials = MockCredentials(onGetToken: { throw PortalCredentialError.unavailable })

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    }
  }

  func test_resolveCredentialToken_willThrowUnavailable_whenTokenIsEmpty() {
    let credentials = MockCredentials(tokenValue: "")

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .unavailable)
      XCTAssertEqual(credentialError?.reason, .unavailable)
      let description = credentialError?.errorDescription ?? ""
      XCTAssertTrue(description.contains("apiKey"), "Expected apiKey guidance in: \(description)")
      XCTAssertTrue(description.contains("credentials"), "Expected credentials guidance in: \(description)")
    }
  }

  func test_resolveCredentialToken_willThrowUnavailable_whenTokenIsWhitespaceOnly() {
    let credentials = MockCredentials(tokenValue: " \n")

    XCTAssertThrowsError(try resolveCredentialToken(credentials)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    }
  }

  func test_resolveCredentialToken_willReturnTokenVerbatim_whenTokenHasInnerWhitespace() throws {
    let credentials = MockCredentials(tokenValue: "a b")

    XCTAssertEqual(try resolveCredentialToken(credentials), "a b")
  }

  func test_resolveCredentialToken_willNotInvalidateCredential_onFailure() {
    let credentials = MockCredentials(onGetToken: { throw NSError(domain: "keystore", code: 3) })

    XCTAssertThrowsError(try resolveCredentialToken(credentials))

    XCTAssertEqual(credentials.invalidateCalls, 0, "Resolution must never mutate the credential")
  }

  // MARK: - staticApiKeyOf

  func test_staticApiKeyOf_willReturnRawKey_forStaticCredentials() {
    XCTAssertEqual(staticApiKeyOf(StaticCredentials("client-api-key")), "client-api-key")
  }

  func test_staticApiKeyOf_willReturnEmptyString_forNonStaticCredential() {
    let credentials = MockCredentials(tokenValue: "session-token")

    XCTAssertEqual(staticApiKeyOf(credentials), "")
    XCTAssertEqual(credentials.getTokenCalls, 0, "A session token must never be resolved into the apiKey bridge")
  }

  // MARK: - StaticCredentials

  func test_StaticCredentials_getToken_willReturnWrappedKey() throws {
    let credentials = StaticCredentials("client-api-key")

    XCTAssertEqual(try credentials.getToken(), "client-api-key")
    XCTAssertEqual(credentials.value, "client-api-key")
  }

  func test_StaticCredentials_getToken_willReturnEmpty_whenConstructedWithEmpty() throws {
    let credentials = StaticCredentials("")

    XCTAssertEqual(try credentials.getToken(), "", "Blank enforcement lives in resolveCredentials/resolveCredentialToken, not here")
  }

  func test_StaticCredentials_invalidate_willBeNoOpLeavingKeyUsable() throws {
    let credentials = StaticCredentials("client-api-key")

    XCTAssertNoThrow(try credentials.invalidate())

    XCTAssertEqual(try credentials.getToken(), "client-api-key")
  }

  func test_StaticCredentials_willBeIdentityDistinct_forEqualValues() {
    let first = StaticCredentials("same")
    let second = StaticCredentials("same")

    XCTAssertFalse(first === second, "The registry keys on identity; equal keys are two credentials")
    XCTAssertNotEqual(ObjectIdentifier(first), ObjectIdentifier(second))
  }

  // MARK: - installUnauthorizedHook

  func test_installUnauthorizedHook_willInstallHook_whenTransportHasNone() {
    let requests = PortalRequests(urlSession: MockURLProtocol.makeSession())
    let credentials = MockCredentials()
    XCTAssertNil(requests.onUnauthorized)

    installUnauthorizedHook(on: requests, for: credentials, context: "PortalApi")

    XCTAssertNotNil(requests.onUnauthorized)
    requests.onUnauthorized?(nil)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_installUnauthorizedHook_willNotOverwriteExistingHook() {
    let requests = PortalRequests(urlSession: MockURLProtocol.makeSession())
    let credentials = MockCredentials()
    var portalRuns = 0
    requests.onUnauthorized = { _ in portalRuns += 1 }

    installUnauthorizedHook(on: requests, for: credentials, context: "PortalApi")
    requests.onUnauthorized?(nil)

    XCTAssertEqual(portalRuns, 1, "The pre-existing hook must still be the one that runs")
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_installUnauthorizedHook_willBeNoOp_whenTransportDoesNotReport() {
    let credentials = MockCredentials()
    let plainMock: PortalRequestsProtocol = PortalRequestsMock()
    let nonReporting: PortalRequestsProtocol = NonReportingPortalRequestsSpy()
    XCTAssertFalse(plainMock is PortalUnauthorizedReporting)
    XCTAssertFalse(nonReporting is PortalUnauthorizedReporting)

    installUnauthorizedHook(on: plainMock, for: credentials, context: "PortalApi")
    installUnauthorizedHook(on: nonReporting, for: credentials, context: "PortalApi")

    XCTAssertEqual(credentials.invalidateCalls, 0)
    XCTAssertEqual(credentials.getTokenCalls, 0)
  }

  func test_installUnauthorizedHook_willRouteThroughReportUnauthorized() async throws {
    let requests = PortalRequestsSpy()
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    installUnauthorizedHook(on: requests, for: credentials, context: "PortalApi")
    XCTAssertEqual(requests.onUnauthorizedSetCount, 1)
    requests.onUnauthorized?(nil)

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The hook must report the dead session to the host, not only invalidate it")
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_installUnauthorizedHook_willReportOnlyTheCredentialThatPresentedTheRejectedBearer() throws {
    // One transport, two SDK objects with different credentials: the 401 belongs to whichever
    // credential's token the rejected request carried, not to whichever installed first.
    let requests = PortalRequestsSpy()
    let first = MockCredentials(tokenValue: "token-first")
    let second = MockCredentials(tokenValue: "token-second")

    installUnauthorizedHook(on: requests, for: first, context: "PortalApi")
    installUnauthorizedHook(on: requests, for: second, context: "PortalProvider")
    XCTAssertEqual(requests.onUnauthorizedSetCount, 1, "One closure per transport, however many owners")

    requests.onUnauthorized?("token-second")

    XCTAssertEqual(second.invalidateCalls, 1, "The rejected credential is invalidated")
    XCTAssertEqual(first.invalidateCalls, 0, "The other owner's session is untouched")

    requests.onUnauthorized?("token-first")

    XCTAssertEqual(first.invalidateCalls, 1)
    XCTAssertEqual(second.invalidateCalls, 1, "Reporting is idempotent per credential and never spills over")
  }

  func test_installUnauthorizedHook_willReportNobody_whenBearerMatchesNoneOfSeveralOwners() {
    let requests = PortalRequestsSpy()
    let first = MockCredentials(tokenValue: "token-first")
    let second = MockCredentials(tokenValue: "token-second")
    installUnauthorizedHook(on: requests, for: first, context: "PortalApi")
    installUnauthorizedHook(on: requests, for: second, context: "PortalProvider")

    requests.onUnauthorized?("token-of-someone-else")
    requests.onUnauthorized?(nil)

    XCTAssertEqual(first.invalidateCalls, 0, "An unattributable 401 must not guess: invalidating the wrong session is worse than none")
    XCTAssertEqual(second.invalidateCalls, 0)
  }

  func test_installUnauthorizedHook_willReportLoneOwner_whenBearerIsUnknownOrRotated() {
    let requests = PortalRequestsSpy()
    let only = MockCredentials(tokenValue: "token-now")
    installUnauthorizedHook(on: requests, for: only, context: "PortalApi")

    // A non-Bearer scheme yields no token; a token that rotated between request and response
    // matches nothing. With a single owner both are unambiguous.
    requests.onUnauthorized?(nil)
    XCTAssertEqual(only.invalidateCalls, 1)

    let rotated = MockCredentials(tokenValue: "token-now")
    let other = PortalRequestsSpy()
    installUnauthorizedHook(on: other, for: rotated, context: "PortalApi")
    other.onUnauthorized?("token-before-rotation")
    XCTAssertEqual(rotated.invalidateCalls, 1)
  }

  func test_installUnauthorizedHook_willRegisterSameCredentialOnce() {
    let requests = PortalRequestsSpy()
    let credentials = MockCredentials(tokenValue: "token")

    installUnauthorizedHook(on: requests, for: credentials, context: "PortalApi")
    installUnauthorizedHook(on: requests, for: credentials, context: "PortalProvider")
    requests.onUnauthorized?("token")

    XCTAssertEqual(requests.onUnauthorizedSetCount, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1, "The same credential registered from two owners is still one owner")
  }

  func test_installUnauthorizedHook_willKeepAttributing_afterAnOwnerDeallocates() {
    // A long-lived transport outlives the credentials that used it: the closure stays, and a new
    // owner must still be recorded against it rather than mistaken for someone else's hook.
    let requests = PortalRequestsSpy()
    var early: MockCredentials? = MockCredentials(tokenValue: "token-early")
    installUnauthorizedHook(on: requests, for: early!, context: "PortalApi")
    early = nil

    let late = MockCredentials(tokenValue: "token-late")
    installUnauthorizedHook(on: requests, for: late, context: "PortalApi")
    requests.onUnauthorized?("token-late")

    XCTAssertEqual(requests.onUnauthorizedSetCount, 1, "The closure is installed once for the life of the transport")
    XCTAssertEqual(late.invalidateCalls, 1)
  }

  func test_installUnauthorizedHook_willNotRetainOwner() {
    final class HookOwner {
      init(requests: PortalRequestsProtocol, credentials: PortalCredentials) {
        installUnauthorizedHook(on: requests, for: credentials, context: "HookOwner")
      }
    }

    let requests = PortalRequestsSpy()
    let credentials = MockCredentials()
    weak var weakOwner: HookOwner?

    func installFromScopedOwner() {
      let owner = HookOwner(requests: requests, credentials: credentials)
      weakOwner = owner
      XCTAssertNotNil(weakOwner)
    }
    installFromScopedOwner()

    XCTAssertNil(weakOwner, "The installed closure must capture only the credential, never its installer")
    XCTAssertNotNil(requests.onUnauthorized, "The hook must outlive the installer")
    requests.onUnauthorized?(nil)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  // MARK: - reportUnauthorizedAndLog

  func test_reportUnauthorizedAndLog_willSwallowInvalidationFailure() {
    let credentials = MockCredentials(onInvalidate: { throw NSError(domain: "keystore", code: 9) })

    reportUnauthorizedAndLog(credentials, context: "PortalApi.execute()")

    XCTAssertEqual(credentials.invalidateCalls, 1)
    let errors = self.logger.messages(at: .error)
    XCTAssertEqual(errors.count, 1, "Expected exactly one error log, got \(errors)")
    XCTAssertTrue(errors.first?.contains("PortalApi.execute()") ?? false, "The log line must carry the caller's context")
  }

  func test_reportUnauthorizedAndLog_willNeverLogToken() {
    let secret = "SUPER-SECRET-CST"
    let credentials = MockCredentials(
      tokenValue: secret,
      onInvalidate: {
        throw NSError(domain: "keystore", code: 9, userInfo: [NSLocalizedDescriptionKey: "failed to delete \(secret) from storage"])
      }
    )

    reportUnauthorizedAndLog(credentials, context: "PortalApi.execute()")

    XCTAssertFalse(self.logger.messages.isEmpty, "The failure path must log something for the assertion to be meaningful")
    self.logger.assertNoSecret(secret)
  }

  func test_reportUnauthorizedAndLog_willNotifyListeners() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    reportUnauthorizedAndLog(credentials, context: "PortalProvider.request()")

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "Listener should have run once")
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(recorder.mainThreadDeliveries, 1, "Listeners are delivered on the main actor")
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }
}

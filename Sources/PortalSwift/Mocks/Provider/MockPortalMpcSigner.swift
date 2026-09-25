//
//  MockPortalMpcSigner.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

/// A `PortalMpcSigner` that never reaches the MPC binary: it answers every sign request with
/// `MockConstants.mockTransactionHash` (send methods) or `MockConstants.mockSignature`.
///
/// Only the `token:` overload is overridden. The deprecated token-less `sign(...)` still works
/// because the base class resolves `credentials` and forwards to the overridden overload, which
/// is why both initializers hand the credential to the base as `legacyCredentials`.
public class MockPortalMpcSigner: PortalMpcSigner {
  /// Builds the mock around `credentials`, which is consulted only if a caller still uses the
  /// deprecated token-less `sign(...)`; the `token:` overload ignores the credential entirely.
  public init(
    credentials: PortalCredentials,
    keychain: PortalKeychainProtocol,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil,
    presignatureSource: PresignatureSource? = nil
  ) {
    super.init(
      keychain: keychain,
      mpcUrl: mpcUrl,
      version: version,
      featureFlags: featureFlags,
      binary: binary,
      presignatureSource: presignatureSource,
      legacyCredentials: credentials
    )
  }

  /// Wraps `apiKey` in a `StaticCredentials`; kept so existing test code keeps compiling.
  @available(*, deprecated, message: "Use init(credentials:keychain:mpcUrl:version:featureFlags:binary:presignatureSource:).")
  public init(
    apiKey: String,
    keychain: PortalKeychainProtocol,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil,
    presignatureSource: PresignatureSource? = nil
  ) {
    super.init(
      keychain: keychain,
      mpcUrl: mpcUrl,
      version: version,
      featureFlags: featureFlags,
      binary: binary,
      presignatureSource: presignatureSource,
      legacyCredentials: StaticCredentials(apiKey)
    )
  }

  /// Returns the canned mock value for the payload's method without using `token`.
  override public func sign(
    _: String,
    withPayload: PortalSignRequest,
    andRpcUrl _: String,
    usingBlockchain _: PortalBlockchain,
    signatureApprovalMemo _: String?,
    sponsorGas _: Bool?,
    reqId _: String? = nil,
    token _: String
  ) async throws -> String {
    switch withPayload.method {
    case .eth_sendTransaction, .eth_sendRawTransaction:
      return MockConstants.mockTransactionHash
    default:
      return MockConstants.mockSignature
    }
  }
}

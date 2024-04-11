//
//  MockPortalProvider.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalProvider: PortalProvider {
  override public func emit(event _: Events.RawValue, data _: Any) -> PortalProvider {
    return self
  }

  override public func on(
    event _: Events.RawValue,
    callback _: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
    return self
  }

  override public func once(
    event _: Events.RawValue,
    callback _: @escaping (_ data: Any) throws -> Void
  ) -> PortalProvider {
    return self
  }

  override public func removeListener(event _: Events.RawValue) -> PortalProvider {
    return self
  }

  override public func request(
    _: String,
    withMethod: PortalRequestMethod,
    andParams _: [AnyEncodable]? = [],
    connect _: PortalConnect? = nil
  ) async throws -> PortalProviderResult {
    switch withMethod {
    case .eth_accounts, .eth_requestAccounts:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: [MockConstants.mockEip155Address]
      )
    case .eth_sendTransaction, .eth_sendRawTransaction:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: MockConstants.mockTransactionHash
      )
    case .eth_sign, .eth_signTransaction, .eth_signTypedData_v3, .eth_signTypedData_v4, .personal_sign:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: MockConstants.mockSignature
      )
    default:
      throw PortalProviderError.unsupportedRequestMethod(withMethod.rawValue)
    }
  }

  override public func setChainId(value _: Int, connect _: PortalConnect? = nil) -> PortalProvider {
    return self
  }
}

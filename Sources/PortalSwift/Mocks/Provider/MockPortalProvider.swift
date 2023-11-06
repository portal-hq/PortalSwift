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
    payload: ETHRequestPayload,
    completion: @escaping (Result<RequestCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    completion(
      Result(
        data: RequestCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result",
          id: "testId"
        )
      )
    )
  }

  override public func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    completion(
      Result(
        data: TransactionCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result",
          id: "testId"
        )
      )
    )
  }

  override public func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void,
    connect _: PortalConnect? = nil
  ) {
    completion(
      Result(
        data: AddressCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result",
          id: "testId"
        )
      )
    )
  }

  override public func setChainId(value _: Int, connect _: PortalConnect? = nil) -> PortalProvider {
    return self
  }
}

//
//  MockPortalProvider.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalProvider: PortalProvider {
  public override func emit(event: Events.RawValue, data: Any) -> PortalProvider {
    return self
  }

  public override func getApiKey() -> String {
    return "mockApiKey"
  }

  public override func on(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
    return self
  }

  public override func once(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) throws -> Void
  ) -> PortalProvider {
    return self
  }

  public override func removeListener(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalProvider {
    return self
  }

  public override func request(
    payload: ETHRequestPayload,
    completion: @escaping (Result<RequestCompletionResult>) -> Void
  ) -> Void {
    completion(
      Result(
        data: RequestCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result"
        )
      )
    )
  }

  public override func request(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) -> Void {
    completion(
      Result(
        data: TransactionCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result"
        )
      )
    )
  }

  public override func request(
    payload: ETHAddressPayload,
    completion: @escaping (Result<AddressCompletionResult>) -> Void
  ) -> Void {
    completion(
      Result(
        data: AddressCompletionResult(
          method: payload.method,
          params: payload.params,
          result: "result"
        )
      )
    )
  }

  public override func setAddress(value: String) -> Void {
    return
  }

  public override func setChainId(value: Int) -> PortalProvider {
    return self
  }
}

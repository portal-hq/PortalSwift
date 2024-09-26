//
//  PortalProviderSpy.swift
//
//
//  Created by Ahmed Ragab on 23/08/2024.
//

import AnyCodable
import Foundation
@testable import PortalSwift

class PortalProviderSpy: PortalProviderProtocol {
  var chainId: Int?
  var address: String?

  let mockPortalProvider: PortalProvider!

  init() {
    do {
      mockPortalProvider = try PortalProvider(apiKey: "", rpcConfig: [:], keychain: PortalKeychain(), autoApprove: true)
    } catch {
      mockPortalProvider = nil
    }
  }

  // Tracking variables for `emit` function
  private(set) var emitCallsCount = 0
  private(set) var emitEventParam: Events.RawValue?
  private(set) var emitDataParam: Any?

  func emit(event: Events.RawValue, data: Any) -> PortalProvider {
    emitCallsCount += 1
    emitEventParam = event
    emitDataParam = data
    return mockPortalProvider
  }

  // Tracking variables for `on` function
  private(set) var onCallsCount = 0
  private(set) var onEventParam: Events.RawValue?
  private(set) var onCallbackParam: ((_ data: Any) -> Void)?

  func on(event: Events.RawValue, callback: @escaping (_ data: Any) -> Void) -> PortalProvider {
    onCallsCount += 1
    onEventParam = event
    onCallbackParam = callback
    return mockPortalProvider
  }

  // Tracking variables for `once` function
  private(set) var onceCallsCount = 0
  private(set) var onceEventParam: Events.RawValue?
  private(set) var onceCallbackParam: ((_ data: Any) throws -> Void)?

  func once(event: Events.RawValue, callback: @escaping (_ data: Any) throws -> Void) -> PortalProvider {
    onceCallsCount += 1
    onceEventParam = event
    onceCallbackParam = callback
    return mockPortalProvider
  }

  // Tracking variables for `removeListener` function
  private(set) var removeListenerCallsCount = 0
  private(set) var removeListenerEventParam: Events.RawValue?

  func removeListener(event: Events.RawValue) -> PortalProvider {
    removeListenerCallsCount += 1
    removeListenerEventParam = event
    return mockPortalProvider
  }

  // Tracking variables for the async `request` function with PortalRequestMethod
  private(set) var requestAsyncMethodCallsCount = 0
  private(set) var requestAsyncMethodChainIdParam: String?
  private(set) var requestAsyncMethodMethodParam: PortalRequestMethod?
  private(set) var requestAsyncMethodParamsParam: [AnyCodable]?
  private(set) var requestAsyncMethodConnectParam: PortalConnect?

  func request(_ chainId: String, withMethod: PortalRequestMethod, andParams: [AnyCodable]?, connect: PortalConnect?) async throws -> PortalProviderResult {
    requestAsyncMethodCallsCount += 1
    requestAsyncMethodChainIdParam = chainId
    requestAsyncMethodMethodParam = withMethod
    requestAsyncMethodParamsParam = andParams
    requestAsyncMethodConnectParam = connect
    return PortalProviderResult(id: "", result: "")
  }

  // Tracking variables for the async `request` function with String method
  private(set) var requestAsyncStringCallsCount = 0
  private(set) var requestAsyncStringChainIdParam: String?
  private(set) var requestAsyncStringMethodParam: String?
  private(set) var requestAsyncStringParamsParam: [AnyCodable]?
  private(set) var requestAsyncStringConnectParam: PortalConnect?

  func request(_ chainId: String, withMethod: String, andParams: [AnyCodable]?, connect: PortalConnect?) async throws -> PortalProviderResult {
    requestAsyncStringCallsCount += 1
    requestAsyncStringChainIdParam = chainId
    requestAsyncStringMethodParam = withMethod
    requestAsyncStringParamsParam = andParams
    requestAsyncStringConnectParam = connect
    return PortalProviderResult(id: "", result: "")
  }

  // Tracking variables for `request` function with ETHRequestPayload
  private(set) var requestPayloadCompletionCallsCount = 0
  private(set) var requestPayloadCompletionPayloadParam: ETHRequestPayload?
  private(set) var requestPayloadCompletionCompletionParam: ((Result<RequestCompletionResult>) -> Void)?
  private(set) var requestPayloadCompletionConnectParam: PortalConnect?

  func request(payload: ETHRequestPayload, completion: @escaping (Result<RequestCompletionResult>) -> Void, connect: PortalConnect?) {
    requestPayloadCompletionCallsCount += 1
    requestPayloadCompletionPayloadParam = payload
    requestPayloadCompletionCompletionParam = completion
    requestPayloadCompletionConnectParam = connect
  }

  // Tracking variables for `request` function with ETHTransactionPayload
  private(set) var requestTransactionCompletionCallsCount = 0
  private(set) var requestTransactionCompletionPayloadParam: ETHTransactionPayload?
  private(set) var requestTransactionCompletionCompletionParam: ((Result<TransactionCompletionResult>) -> Void)?
  private(set) var requestTransactionCompletionConnectParam: PortalConnect?

  func request(payload: ETHTransactionPayload, completion: @escaping (Result<TransactionCompletionResult>) -> Void, connect: PortalConnect?) {
    requestTransactionCompletionCallsCount += 1
    requestTransactionCompletionPayloadParam = payload
    requestTransactionCompletionCompletionParam = completion
    requestTransactionCompletionConnectParam = connect
  }

  // Tracking variables for `request` function with ETHAddressPayload
  private(set) var requestAddressCompletionCallsCount = 0
  private(set) var requestAddressCompletionPayloadParam: ETHAddressPayload?
  private(set) var requestAddressCompletionCompletionParam: ((Result<AddressCompletionResult>) -> Void)?
  private(set) var requestAddressCompletionConnectParam: PortalConnect?

  func request(payload: ETHAddressPayload, completion: @escaping (Result<AddressCompletionResult>) -> Void, connect: PortalConnect?) {
    requestAddressCompletionCallsCount += 1
    requestAddressCompletionPayloadParam = payload
    requestAddressCompletionCompletionParam = completion
    requestAddressCompletionConnectParam = connect
  }

  // Tracking variables for `setChainId` function
  private(set) var setChainIdCallsCount = 0
  private(set) var setChainIdValueParam: Int?
  private(set) var setChainIdConnectParam: PortalConnect?

  func setChainId(value: Int, connect: PortalConnect?) throws -> PortalProvider {
    setChainIdCallsCount += 1
    setChainIdValueParam = value
    setChainIdConnectParam = connect
    return mockPortalProvider
  }
}

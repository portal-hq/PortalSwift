//
//  PortalProviderMock.swift
//
//
//  Created by Ahmed Ragab on 24/08/2024.
//

import AnyCodable
import Foundation
@testable import PortalSwift

class PortalProviderMock: PortalProviderProtocol {
  var chainId: Int?

  var address: String?

  private let mockPortalProvider: PortalProvider!

  init() {
    do {
      mockPortalProvider = try PortalProvider(apiKey: "", rpcConfig: [:], keychain: PortalKeychain(), autoApprove: true)
    } catch {
      mockPortalProvider = nil
    }
  }

  func emit(event _: PortalSwift.Events.RawValue, data _: Any) -> PortalSwift.PortalProvider {
    mockPortalProvider
  }

  func on(event _: PortalSwift.Events.RawValue, callback _: @escaping (Any) -> Void) -> PortalSwift.PortalProvider {
    mockPortalProvider
  }

  func once(event _: PortalSwift.Events.RawValue, callback _: @escaping (Any) throws -> Void) -> PortalSwift.PortalProvider {
    mockPortalProvider
  }

  func removeListener(event _: PortalSwift.Events.RawValue) -> PortalSwift.PortalProvider {
    mockPortalProvider
  }

  func request(_: String, withMethod: PortalSwift.PortalRequestMethod, andParams _: [AnyCodable]?, connect _: PortalSwift.PortalConnect?) async throws -> PortalSwift.PortalProviderResult {
    switch withMethod {
    case .eth_accounts, .eth_requestAccounts:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: [MockConstants.mockEip155Address]
      )
    case .eth_sendTransaction, .eth_sendRawTransaction, .sol_signAndSendTransaction:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: MockConstants.mockTransactionHash
      )
    case .eth_sign, .eth_signTransaction, .eth_signTypedData_v3, .eth_signTypedData_v4, .personal_sign:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: MockConstants.mockSignature
      )
    case .sol_getLatestBlockhash:
      return PortalProviderResult(
        id: MockConstants.mockProviderRequestId,
        result: SolGetLatestBlockhashResponse.stub()
      )
    default:
      throw PortalProviderError.unsupportedRequestMethod(withMethod.rawValue)
    }
  }

  func request(_ chainId: String, withMethod: String, andParams: [AnyCodable]?, connect: PortalSwift.PortalConnect?) async throws -> PortalSwift.PortalProviderResult {
    try await self.request(chainId, withMethod: PortalRequestMethod(rawValue: withMethod)!, andParams: andParams, connect: connect)
  }

  func request(payload _: PortalSwift.ETHRequestPayload, completion _: @escaping (PortalSwift.Result<PortalSwift.RequestCompletionResult>) -> Void, connect _: PortalSwift.PortalConnect?) {}

  func request(payload _: PortalSwift.ETHTransactionPayload, completion _: @escaping (PortalSwift.Result<PortalSwift.TransactionCompletionResult>) -> Void, connect _: PortalSwift.PortalConnect?) {}

  func request(payload _: PortalSwift.ETHAddressPayload, completion _: @escaping (PortalSwift.Result<PortalSwift.AddressCompletionResult>) -> Void, connect _: PortalSwift.PortalConnect?) {}

  func setChainId(value _: Int, connect _: PortalSwift.PortalConnect?) throws -> PortalSwift.PortalProvider {
    mockPortalProvider
  }

  var getRpcUrlReturnValue: String = ""
  func getRpcUrl(_: String) throws -> String {
    return getRpcUrlReturnValue
  }
}

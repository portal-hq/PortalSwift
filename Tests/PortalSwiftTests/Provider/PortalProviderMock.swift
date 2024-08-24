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

    func emit(event: PortalSwift.Events.RawValue, data: Any) -> PortalSwift.PortalProvider {
        mockPortalProvider
    }
    
    func on(event: PortalSwift.Events.RawValue, callback: @escaping (Any) -> Void) -> PortalSwift.PortalProvider {
        mockPortalProvider
    }
    
    func once(event: PortalSwift.Events.RawValue, callback: @escaping (Any) throws -> Void) -> PortalSwift.PortalProvider {
        mockPortalProvider
    }
    
    func removeListener(event: PortalSwift.Events.RawValue) -> PortalSwift.PortalProvider {
        mockPortalProvider
    }
    
    func request(_ chainId: String, withMethod: PortalSwift.PortalRequestMethod, andParams: [AnyCodable]?, connect: PortalSwift.PortalConnect?) async throws -> PortalSwift.PortalProviderResult {
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
    
    func request(payload: PortalSwift.ETHRequestPayload, completion: @escaping (PortalSwift.Result<PortalSwift.RequestCompletionResult>) -> Void, connect: PortalSwift.PortalConnect?) {
        
    }
    
    func request(payload: PortalSwift.ETHTransactionPayload, completion: @escaping (PortalSwift.Result<PortalSwift.TransactionCompletionResult>) -> Void, connect: PortalSwift.PortalConnect?) {
        
    }
    
    func request(payload: PortalSwift.ETHAddressPayload, completion: @escaping (PortalSwift.Result<PortalSwift.AddressCompletionResult>) -> Void, connect: PortalSwift.PortalConnect?) {
    
    }
    
    func setChainId(value: Int, connect: PortalSwift.PortalConnect?) throws -> PortalSwift.PortalProvider {
        mockPortalProvider
    }
}

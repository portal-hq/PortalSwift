//
//  EvmAccountType.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

// MARK: - Response Stubs

extension EvmAccountTypeResponse {
  static func stub(
    data: EvmAccountTypeData = .stub(),
    metadata: EvmAccountTypeMetadata = .stub()
  ) -> Self {
    .init(data: data, metadata: metadata)
  }
}

extension EvmAccountTypeData {
  static func stub(status: String = "EIP_155_EOA") -> Self {
    .init(status: status)
  }
}

extension EvmAccountTypeMetadata {
  static func stub(
    chainId: String = "eip155:11155111",
    eoaAddress: String = "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
    smartContractAddress: String? = "0x54d37A9b7c614ac2141f6a880dA2201b45586De3"
  ) -> Self {
    .init(chainId: chainId, eoaAddress: eoaAddress, smartContractAddress: smartContractAddress)
  }
}

extension BuildAuthorizationListResponse {
  static func stub(
    data: BuildAuthorizationListData = .stub(),
    metadata: BuildAuthorizationListMetadata = .stub()
  ) -> Self {
    .init(data: data, metadata: metadata)
  }
}

extension BuildAuthorizationListData {
  static func stub(hash: String = "0x91aee67c57b66d6759640eb3beb69be6b36690ca9f0d8446fff3f9cb269a4736") -> Self {
    .init(hash: hash)
  }
}

extension BuildAuthorizationListMetadata {
  static func stub(
    authorization: AuthorizationDetail = .stub(),
    chainId: String = "eip155:11155111"
  ) -> Self {
    .init(authorization: authorization, chainId: chainId)
  }
}

extension BuildAuthorizationTransactionResponse {
  static func stub(
    data: BuildAuthorizationTransactionData = .stub(),
    metadata: BuildAuthorizationTransactionMetadata? = .stub()
  ) -> Self {
    .init(data: data, metadata: metadata)
  }
}

extension BuildAuthorizationTransactionData {
  static func stub(transaction: Eip7702Transaction = .stub()) -> Self {
    .init(transaction: transaction)
  }
}

extension Eip7702Transaction {
  static func stub(
    type: String? = "eip7702",
    from: String = "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
    to: String = "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
    value: String? = "0x0",
    data: String? = "0x0",
    nonce: String? = "0x00",
    chainId: String? = "0xaa36a7",
    authorizationList: [AuthorizationListItem]? = [.stub()],
    gasLimit: String? = "0x1819b",
    maxFeePerGas: String? = "0x01fc1cd261",
    maxPriorityFeePerGas: String? = "0x15f5d5"
  ) -> Self {
    .init(
      type: type,
      from: from,
      to: to,
      value: value,
      data: data,
      nonce: nonce,
      chainId: chainId,
      authorizationList: authorizationList,
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas
    )
  }
}

extension AuthorizationListItem {
  static func stub(
    address: String = "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
    chainId: String = "0xaa36a7",
    nonce: String = "0x01",
    r: String = "0xe904a3405299bf569cdf8c3b54ff2db6f8eb896d2bc0eaaec544a045e37cab70",
    s: String = "0x648daa33f3189d7739f8c74a41d541718145614e91d6427d6adc3ae4566aedbd",
    yParity: String = "0x01"
  ) -> Self {
    .init(address: address, chainId: chainId, nonce: nonce, r: r, s: s, yParity: yParity)
  }
}

extension AuthorizationDetail {
  static func stub(
    contractAddress: String = "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
    chainId: String = "0xaa36a7",
    nonce: String = "0x01"
  ) -> Self {
    .init(contractAddress: contractAddress, chainId: chainId, nonce: nonce)
  }
}

extension AuthorizationSignature {
  static func stub(
    r: String = "0xe904a3405299bf569cdf8c3b54ff2db6f8eb896d2bc0eaaec544a045e37cab70",
    s: String = "0x648daa33f3189d7739f8c74a41d541718145614e91d6427d6adc3ae4566aedbd",
    yParity: String = "0x01"
  ) -> Self {
    .init(r: r, s: s, yParity: yParity)
  }
}

extension BuildAuthorizationTransactionMetadata {
  static func stub(
    authorization: AuthorizationDetail = .stub(),
    chainId: String = "eip155:11155111",
    hash: String? = "0x91aee67c57b66d6759640eb3beb69be6b36690ca9f0d8446fff3f9cb269a4736",
    signature: AuthorizationSignature? = .stub()
  ) -> Self {
    .init(authorization: authorization, chainId: chainId, hash: hash, signature: signature)
  }
}

extension BuildAuthorizationTransactionRequest {
  static func stub(signature: String = "e904a3405299bf569cdf8c3b54ff2db6f8eb896d2bc0eaaec544a045e37cab70648daa33f3189d7739f8c74a41d541718145614e91d6427d6adc3ae4566aedbd01") -> Self {
    .init(signature: signature)
  }
}

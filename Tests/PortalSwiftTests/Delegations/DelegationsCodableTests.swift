//
//  DelegationsCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

final class DelegationsCodableTests: XCTestCase {

  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // MARK: - ApproveDelegationRequest Tests

  func test_approveDelegationRequest_encodesAndDecodesCorrectly() throws {
    // Given
    let request = ApproveDelegationRequest.stub()

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(ApproveDelegationRequest.self, from: data)

    // Then
    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.token, request.token)
    XCTAssertEqual(decoded.delegateAddress, request.delegateAddress)
    XCTAssertEqual(decoded.amount, request.amount)
  }

  // MARK: - ApproveDelegationResponse Tests

  func test_approveDelegationResponse_decodesEVMTransactions() throws {
    // Given
    let json = """
    {
        "transactions": [{"from": "0x1", "to": "0x2", "data": "0xabc", "value": "0x0"}],
        "metadata": {
            "chainId": "11155111",
            "delegateAmount": "1.0",
            "delegateAddress": "0x123",
            "tokenSymbol": "USDC"
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ApproveDelegationResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.transactions?.count, 1)
    XCTAssertNil(decoded.encodedTransactions)
    XCTAssertEqual(decoded.metadata?.chainId, "11155111")
    XCTAssertEqual(decoded.metadata?.delegateAddress, "0x123")
  }

  func test_approveDelegationResponse_decodesSolanaTransactions() throws {
    // Given
    let json = """
    {
        "encodedTransactions": ["base64encoded1", "base64encoded2"],
        "metadata": {
            "chainId": "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
            "delegateAmount": "1.0",
            "delegateAddress": "49bNwvPHy3krxWLBU3qrK5Gm1RPFqWDXB8xaawcjyCjd",
            "tokenSymbol": "USDC",
            "tokenAccount": "ATA_ADDRESS",
            "tokenMint": "MINT_ADDRESS",
            "tokenDecimals": 6
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ApproveDelegationResponse.self, from: json)

    // Then
    XCTAssertNil(decoded.transactions)
    XCTAssertEqual(decoded.encodedTransactions?.count, 2)
    XCTAssertEqual(decoded.metadata?.tokenDecimals, 6)
    XCTAssertEqual(decoded.metadata?.tokenMint, "MINT_ADDRESS")
    XCTAssertEqual(decoded.metadata?.tokenAccount, "ATA_ADDRESS")
  }

  func test_approveDelegationResponse_decodesWithAllNilOptionals() throws {
    // Given
    let json = """
    {}
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ApproveDelegationResponse.self, from: json)

    // Then
    XCTAssertNil(decoded.transactions)
    XCTAssertNil(decoded.encodedTransactions)
    XCTAssertNil(decoded.metadata)
  }

  // MARK: - RevokeDelegationRequest Tests

  func test_revokeDelegationRequest_encodesAndDecodesCorrectly() throws {
    // Given
    let request = RevokeDelegationRequest.stub()

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(RevokeDelegationRequest.self, from: data)

    // Then
    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.token, request.token)
    XCTAssertEqual(decoded.delegateAddress, request.delegateAddress)
  }

  // MARK: - RevokeDelegationResponse Tests

  func test_revokeDelegationResponse_decodesEVMVariant() throws {
    // Given
    let json = """
    {
        "transactions": [{"from": "0x1", "to": "0x2"}],
        "metadata": {
            "chainId": "11155111",
            "revokedAddress": "0xrevoked",
            "tokenSymbol": "USDC"
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(RevokeDelegationResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.transactions?.count, 1)
    XCTAssertEqual(decoded.metadata?.revokedAddress, "0xrevoked")
  }

  func test_revokeDelegationResponse_decodesSolanaVariant() throws {
    // Given
    let json = """
    {
        "encodedTransactions": ["solTx1"],
        "metadata": {
            "chainId": "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
            "revokedAddress": "49bNwvPHy3krxWLBU3qrK5Gm1RPFqWDXB8xaawcjyCjd",
            "tokenSymbol": "USDC",
            "tokenAccount": "ATA_ADDRESS"
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(RevokeDelegationResponse.self, from: json)

    // Then
    XCTAssertNil(decoded.transactions)
    XCTAssertEqual(decoded.encodedTransactions?.count, 1)
    XCTAssertEqual(decoded.metadata?.tokenAccount, "ATA_ADDRESS")
  }

  // MARK: - GetDelegationStatusRequest Tests

  func test_getDelegationStatusRequest_encodesAndDecodesCorrectly() throws {
    // Given
    let request = GetDelegationStatusRequest.stub()

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(GetDelegationStatusRequest.self, from: data)

    // Then
    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.token, request.token)
    XCTAssertEqual(decoded.delegateAddress, request.delegateAddress)
  }

  // MARK: - DelegationStatusResponse Tests

  func test_delegationStatusResponse_decodesMultipleDelegations() throws {
    // Given
    let json = """
    {
        "chainId": "11155111",
        "token": "USDC",
        "tokenAddress": "0xtoken",
        "balance": "100.0",
        "balanceRaw": "100000000",
        "delegations": [
            {"address": "0xdel1", "delegateAmount": "10.0", "delegateAmountRaw": "10000000"},
            {"address": "0xdel2", "delegateAmount": "5.0", "delegateAmountRaw": "5000000"}
        ]
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(DelegationStatusResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.delegations.count, 2)
    XCTAssertEqual(decoded.delegations[0].address, "0xdel1")
    XCTAssertEqual(decoded.delegations[1].delegateAmount, "5.0")
    XCTAssertEqual(decoded.balance, "100.0")
  }

  func test_delegationStatusResponse_decodesEmptyDelegations() throws {
    // Given
    let json = """
    {
        "chainId": "11155111",
        "token": "USDC",
        "tokenAddress": "0xtoken",
        "delegations": []
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(DelegationStatusResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.delegations.count, 0)
    XCTAssertNil(decoded.balance)
    XCTAssertNil(decoded.balanceRaw)
    XCTAssertNil(decoded.tokenAccount)
  }

  // MARK: - TransferFromRequest Tests

  func test_transferFromRequest_encodesAndDecodesCorrectly() throws {
    // Given
    let request = TransferFromRequest.stub()

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(TransferFromRequest.self, from: data)

    // Then
    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.fromAddress, request.fromAddress)
    XCTAssertEqual(decoded.toAddress, request.toAddress)
    XCTAssertEqual(decoded.amount, request.amount)
  }

  // MARK: - TransferFromResponse Tests

  func test_transferFromResponse_decodesWithNonOptionalMetadata() throws {
    // Given
    let json = """
    {
        "transactions": [{"from": "0x1", "to": "0x2"}],
        "metadata": {
            "amount": "1.0",
            "amountRaw": "1000000",
            "chainId": "11155111"
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(TransferFromResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.metadata.amount, "1.0")
    XCTAssertEqual(decoded.metadata.amountRaw, "1000000")
    XCTAssertEqual(decoded.metadata.chainId, "11155111")
  }

  func test_transferFromResponse_decodesWithFullMetadata() throws {
    // Given
    let json = """
    {
        "encodedTransactions": ["solTx1"],
        "metadata": {
            "amount": "2.0",
            "amountRaw": "2000000",
            "chainId": "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
            "delegateAddress": "49bNwvPHy3krxWLBU3qrK5Gm1RPFqWDXB8xaawcjyCjd",
            "lastValidBlockHeight": "123456",
            "needsRecipientTokenAccount": true,
            "ownerAddress": "owner123",
            "recipientAddress": "recipient123",
            "tokenAddress": "tokenAddr",
            "tokenSymbol": "USDC",
            "tokenDecimals": 6
        }
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(TransferFromResponse.self, from: json)

    // Then
    XCTAssertEqual(decoded.metadata.delegateAddress, "49bNwvPHy3krxWLBU3qrK5Gm1RPFqWDXB8xaawcjyCjd")
    XCTAssertEqual(decoded.metadata.needsRecipientTokenAccount, true)
    XCTAssertEqual(decoded.metadata.tokenDecimals, 6)
    XCTAssertEqual(decoded.metadata.lastValidBlockHeight, "123456")
  }

  // MARK: - ConstructedEipTransaction Tests

  func test_constructedEipTransaction_encodesAndDecodesCorrectly() throws {
    // Given
    let tx = ConstructedEipTransaction(from: "0x1", to: "0x2", data: "0xabc", value: "0x1000")

    // When
    let data = try encoder.encode(tx)
    let decoded = try decoder.decode(ConstructedEipTransaction.self, from: data)

    // Then
    XCTAssertEqual(decoded.from, "0x1")
    XCTAssertEqual(decoded.to, "0x2")
    XCTAssertEqual(decoded.data, "0xabc")
    XCTAssertEqual(decoded.value, "0x1000")
  }

  func test_constructedEipTransaction_decodesWithNilOptionals() throws {
    // Given
    let json = """
    {"from": "0x1", "to": "0x2"}
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ConstructedEipTransaction.self, from: json)

    // Then
    XCTAssertEqual(decoded.from, "0x1")
    XCTAssertEqual(decoded.to, "0x2")
    XCTAssertNil(decoded.data)
    XCTAssertNil(decoded.value)
  }
}

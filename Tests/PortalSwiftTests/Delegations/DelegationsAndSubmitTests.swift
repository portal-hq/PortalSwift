//
//  DelegationsAndSubmitTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//
//  Tests for the high-level Delegations submit methods
//  (approveAndSubmit / revokeAndSubmit / transferAndSubmit).
//

@testable import PortalSwift
import XCTest

final class DelegationsAndSubmitTests: XCTestCase {
  private var mockApi: PortalDelegationsApiMock!
  private var sut: Delegations!

  /// Records the transactions passed to the signer, in order, and returns canned hashes.
  private final class RecordingSigner {
    private let hashes: [String]
    private(set) var signedTransactions: [DelegationTransaction] = []
    private(set) var chainIds: [String] = []

    init(hashes: [String] = ["0xhash0", "0xhash1", "0xhash2", "0xhash3"]) {
      self.hashes = hashes
    }

    func asFn() -> DelegationSignAndSend {
      { transaction, chainId in
        self.signedTransactions.append(transaction)
        self.chainIds.append(chainId)
        return self.hashes[self.signedTransactions.count - 1]
      }
    }
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    mockApi = PortalDelegationsApiMock()
    sut = Delegations(api: mockApi)
  }

  override func tearDownWithError() throws {
    mockApi = nil
    sut = nil
    try super.tearDownWithError()
  }

  // MARK: - Signer Resolution

  func testApproveAndSubmit_noSignerConfigured_throws() async {
    mockApi.approveReturnValue = .stub()

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .noSignerConfigured)
      // API should not be called when no signer is configured.
      XCTAssertEqual(mockApi.approveCallCount, 0)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testApproveAndSubmit_perCallSigner_overridesInstanceSigner() async throws {
    let instanceSigner = RecordingSigner(hashes: ["0xinstance"])
    let perCallSigner = RecordingSigner(hashes: ["0xpercall"])
    sut.setSignAndSendTransaction(instanceSigner.asFn())
    mockApi.approveReturnValue = .stub()

    let result = try await sut.approveAndSubmit(
      request: .stub(),
      options: DelegationSubmitOptions(signAndSendTransaction: perCallSigner.asFn())
    )

    XCTAssertEqual(result.hashes, ["0xpercall"])
    XCTAssertEqual(perCallSigner.signedTransactions.count, 1)
    XCTAssertEqual(instanceSigner.signedTransactions.count, 0)
  }

  func testApproveAndSubmit_instanceSigner_usedWhenNoOverride() async throws {
    let instanceSigner = RecordingSigner(hashes: ["0xinstance"])
    sut.setSignAndSendTransaction(instanceSigner.asFn())
    mockApi.approveReturnValue = .stub()

    let result = try await sut.approveAndSubmit(request: .stub())

    XCTAssertEqual(result.hashes, ["0xinstance"])
    XCTAssertEqual(instanceSigner.signedTransactions.count, 1)
  }

  // MARK: - EVM vs Solana Normalization

  func testApproveAndSubmit_evm_usesTransactions() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(transactions: [.stub()], encodedTransactions: nil)

    let result = try await sut.approveAndSubmit(request: .stub(chain: "eip155:11155111"))

    XCTAssertEqual(result.hashes, ["0xhash0"])
    XCTAssertEqual(signer.signedTransactions.count, 1)
    XCTAssertNotNil(signer.signedTransactions[0].evmTransaction)
    XCTAssertEqual(signer.chainIds[0], "eip155:11155111")
  }

  func testApproveAndSubmit_solana_usesEncodedTransactions() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(transactions: nil, encodedTransactions: ["base64tx0", "base64tx1"])

    let result = try await sut.approveAndSubmit(
      request: .stub(chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    )

    XCTAssertEqual(result.hashes, ["0xhash0", "0xhash1"])
    XCTAssertEqual(signer.signedTransactions.compactMap(\.solanaTransaction), ["base64tx0", "base64tx1"])
  }

  func testApproveAndSubmit_prefersTransactionsWhenBothPresent() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(transactions: [.stub()], encodedTransactions: ["base64tx0"])

    let result = try await sut.approveAndSubmit(request: .stub())

    XCTAssertEqual(result.hashes, ["0xhash0"])
    XCTAssertEqual(signer.signedTransactions.count, 1)
    XCTAssertNotNil(signer.signedTransactions[0].evmTransaction)
  }

  // MARK: - Multi-Transaction Ordering

  func testApproveAndSubmit_multipleTransactions_orderedHashes() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(
      transactions: [.stub(from: "0xfrom0"), .stub(from: "0xfrom1")],
      encodedTransactions: nil
    )

    let result = try await sut.approveAndSubmit(request: .stub())

    XCTAssertEqual(result.hashes, ["0xhash0", "0xhash1"])
    XCTAssertEqual(signer.signedTransactions.count, 2)
    XCTAssertEqual(signer.signedTransactions[0].evmTransaction?.from, "0xfrom0")
    XCTAssertEqual(signer.signedTransactions[1].evmTransaction?.from, "0xfrom1")
  }

  // MARK: - Errors

  func testApproveAndSubmit_emptyTransactions_throws() async {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(transactions: [], encodedTransactions: nil)

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .noTransactions)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testApproveAndSubmit_blankHash_throws() async {
    sut.setSignAndSendTransaction { _, _ in "   " }
    mockApi.approveReturnValue = .stub()

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .invalidTransactionHash(index: 0, chainId: "eip155:11155111"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testApproveAndSubmit_emptyHash_throws() async {
    // The default Portal signer returns an empty string when the provider result is not a hash;
    // `executeAndTrack` must catch that (not only whitespace-only strings).
    sut.setSignAndSendTransaction { _, _ in "" }
    mockApi.approveReturnValue = .stub()

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .invalidTransactionHash(index: 0, chainId: "eip155:11155111"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testApproveAndSubmit_invalidHashOnSecondTransaction_reportsCorrectIndex() async {
    // Regression test for the default-signer path: a blank hash on a non-first transaction must
    // report that transaction's index, not a hardcoded 0.
    let signer = RecordingSigner(hashes: ["0xhash0", ""])
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.approveReturnValue = .stub(
      transactions: [.stub(from: "0xfrom0"), .stub(from: "0xfrom1")],
      encodedTransactions: nil
    )

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .invalidTransactionHash(index: 1, chainId: "eip155:11155111"))
      // The first transaction was signed before the failure surfaced.
      XCTAssertEqual(signer.signedTransactions.count, 2)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testApproveAndSubmit_apiError_propagates() async {
    sut.setSignAndSendTransaction(RecordingSigner().asFn())
    mockApi.approveError = URLError(.badServerResponse)

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(error is URLError)
    }
  }

  func testApproveAndSubmit_signerError_propagates() async {
    struct SignerError: Error {}
    sut.setSignAndSendTransaction { _, _ in throw SignerError() }
    mockApi.approveReturnValue = .stub()

    do {
      _ = try await sut.approveAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(error is SignerError)
    }
  }

  // MARK: - Progress Callbacks

  func testApproveAndSubmit_progressSequence() async throws {
    sut.setSignAndSendTransaction(RecordingSigner().asFn())
    mockApi.approveReturnValue = .stub(
      transactions: [.stub(from: "0xfrom0"), .stub(from: "0xfrom1")],
      encodedTransactions: nil
    )
    var events: [DelegationSubmitProgress] = []

    _ = try await sut.approveAndSubmit(
      request: .stub(),
      options: DelegationSubmitOptions(onProgress: { events.append($0) })
    )

    XCTAssertEqual(events.count, 4)
    XCTAssertEqual(events[0], DelegationSubmitProgress(step: .signing, index: 0, total: 2))
    XCTAssertEqual(events[1], DelegationSubmitProgress(step: .submitted, index: 0, total: 2, hash: "0xhash0"))
    XCTAssertEqual(events[2], DelegationSubmitProgress(step: .signing, index: 1, total: 2))
    XCTAssertEqual(events[3], DelegationSubmitProgress(step: .submitted, index: 1, total: 2, hash: "0xhash1"))
  }

  // MARK: - Revoke & Transfer Happy Paths

  func testRevokeAndSubmit_evm_success() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.revokeReturnValue = .stub()

    let result = try await sut.revokeAndSubmit(request: .stub())

    XCTAssertEqual(result.hashes, ["0xhash0"])
    XCTAssertEqual(mockApi.revokeCallCount, 1)
  }

  func testRevokeAndSubmit_noSignerConfigured_throws() async {
    mockApi.revokeReturnValue = .stub()

    do {
      _ = try await sut.revokeAndSubmit(request: .stub())
      XCTFail("Expected error")
    } catch let error as DelegationsError {
      XCTAssertEqual(error, .noSignerConfigured)
      XCTAssertEqual(mockApi.revokeCallCount, 0)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testTransferAndSubmit_evm_success() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.transferFromReturnValue = .stub()

    let result = try await sut.transferAndSubmit(request: .stub())

    XCTAssertEqual(result.hashes, ["0xhash0"])
    XCTAssertEqual(mockApi.transferFromCallCount, 1)
  }

  func testTransferAndSubmit_solana_usesEncodedTransactions() async throws {
    let signer = RecordingSigner()
    sut.setSignAndSendTransaction(signer.asFn())
    mockApi.transferFromReturnValue = .stub(transactions: nil, encodedTransactions: ["base64tx0"])

    let result = try await sut.transferAndSubmit(
      request: .stub(chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    )

    XCTAssertEqual(result.hashes, ["0xhash0"])
    XCTAssertEqual(signer.signedTransactions.compactMap(\.solanaTransaction), ["base64tx0"])
  }
}

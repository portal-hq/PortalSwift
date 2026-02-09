//
//  ViewController+Delegations.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Delegations testing functionality
//

import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {

  // MARK: - Delegation Approve (ETH)

  @IBAction func delegationApproveETH(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Approve ETH] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Approve ETH] Starting approval...")

        let request = ApproveDelegationRequest(
          chain: "eip155:11155111",
          token: "USDC",
          delegateAddress: "0xa944e86eb36f039becd1843132347eb5b8501562",
          amount: "0.01"
        )

        let response = try await portal.delegations.approve(request: request)

        logApproveResult(response, label: "ETH")

        // Sign and send EVM transactions sequentially
        if let transactions = response.transactions {
          for (index, tx) in transactions.enumerated() {
            logger.info("📝 [Delegation Approve ETH] Sending tx \(index + 1)/\(transactions.count)...")
            let hash = try await sendEVMDelegationTransaction(portal: portal, transaction: tx, chain: request.chain)
            logger.info("✅ [Delegation Approve ETH] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) Approve (ETH) completed")

      } catch {
        logger.error("❌ [Delegation Approve ETH] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Approve (ETH) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation Approve (SOL)

  @IBAction func delegationApproveSOL(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Approve SOL] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Approve SOL] Starting approval...")

        let request = ApproveDelegationRequest(
          chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
          token: "USDC",
          delegateAddress: "7smgSuU5mjP7QY5yWGdaTfgKn8hUWwvQgfvgcZB3HmJi",
          amount: "0.01"
        )

        let response = try await portal.delegations.approve(request: request)

        logApproveResult(response, label: "SOL")

        // Sign and send Solana transactions sequentially
        if let encodedTransactions = response.encodedTransactions {
          for (index, encodedTx) in encodedTransactions.enumerated() {
            logger.info("📝 [Delegation Approve SOL] Sending tx \(index + 1)/\(encodedTransactions.count)...")
            let hash = try await sendSolanaDelegationTransaction(portal: portal, encodedTransaction: encodedTx, chain: request.chain)
            logger.info("✅ [Delegation Approve SOL] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) Approve (SOL) completed")

      } catch {
        logger.error("❌ [Delegation Approve SOL] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Approve (SOL) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation Revoke (ETH)

  @IBAction func delegationRevokeETH(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Revoke ETH] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Revoke ETH] Starting revocation...")

        let request = RevokeDelegationRequest(
          chain: "eip155:11155111",
          token: "USDC",
          delegateAddress: "0xa944e86eb36f039becd1843132347eb5b8501562"
        )

        let response = try await portal.delegations.revoke(request: request)

        logRevokeResult(response, label: "ETH")

        // Sign and send EVM transactions sequentially
        if let transactions = response.transactions {
          for (index, tx) in transactions.enumerated() {
            logger.info("📝 [Delegation Revoke ETH] Sending tx \(index + 1)/\(transactions.count)...")
            let hash = try await sendEVMDelegationTransaction(portal: portal, transaction: tx, chain: request.chain)
            logger.info("✅ [Delegation Revoke ETH] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) Revoke (ETH) completed")

      } catch {
        logger.error("❌ [Delegation Revoke ETH] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Revoke (ETH) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation Revoke (SOL)

  @IBAction func delegationRevokeSOL(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Revoke SOL] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Revoke SOL] Starting revocation...")

        let request = RevokeDelegationRequest(
          chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
          token: "USDC",
          delegateAddress: "7smgSuU5mjP7QY5yWGdaTfgKn8hUWwvQgfvgcZB3HmJi"
        )

        let response = try await portal.delegations.revoke(request: request)

        logRevokeResult(response, label: "SOL")

        // Sign and send Solana transactions sequentially
        if let encodedTransactions = response.encodedTransactions {
          for (index, encodedTx) in encodedTransactions.enumerated() {
            logger.info("📝 [Delegation Revoke SOL] Sending tx \(index + 1)/\(encodedTransactions.count)...")
            let hash = try await sendSolanaDelegationTransaction(portal: portal, encodedTransaction: encodedTx, chain: request.chain)
            logger.info("✅ [Delegation Revoke SOL] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) Revoke (SOL) completed")

      } catch {
        logger.error("❌ [Delegation Revoke SOL] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Revoke (SOL) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation TransferFrom (ETH)

  @IBAction func delegationTransferFromETH(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation TransferFrom ETH] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation TransferFrom ETH] Starting transfer...")
        logger.info("ℹ️ NOTE: This must be called from the delegate's client account")

        let request = TransferFromRequest(
          chain: "eip155:11155111",
          token: "USDC",
          fromAddress: "0x099699ed181517d4ce0ba4487bea671d31bb1db5",
          toAddress: "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
          amount: "0.01"
        )

        let response = try await portal.delegations.transferFrom(request: request)

        logTransferFromResult(response, label: "ETH")

        // Sign and send EVM transactions sequentially
        if let transactions = response.transactions {
          for (index, tx) in transactions.enumerated() {
            logger.info("📝 [Delegation TransferFrom ETH] Sending tx \(index + 1)/\(transactions.count)...")
            let hash = try await sendEVMDelegationTransaction(portal: portal, transaction: tx, chain: request.chain)
            logger.info("✅ [Delegation TransferFrom ETH] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) TransferFrom (ETH) completed")

      } catch {
        logger.error("❌ [Delegation TransferFrom ETH] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) TransferFrom (ETH) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation TransferFrom (SOL)

  @IBAction func delegationTransferFromSOL(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation TransferFrom SOL] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation TransferFrom SOL] Starting transfer...")
        logger.info("ℹ️ NOTE: This must be called from the delegate's client account")

        let request = TransferFromRequest(
          chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
          token: "USDC",
          fromAddress: "ARttPLesu9RiX6H111Pfdc9Y2DhGy1B8P8jyyrD8Cj5b",
          toAddress: "GPsPXxoQA51aTJJkNHtFDFYui5hN5UxcFPnheJEHa5Du",
          amount: "0.01"
        )

        let response = try await portal.delegations.transferFrom(request: request)

        logTransferFromResult(response, label: "SOL")

        // Sign and send Solana transactions sequentially
        if let encodedTransactions = response.encodedTransactions {
          for (index, encodedTx) in encodedTransactions.enumerated() {
            logger.info("📝 [Delegation TransferFrom SOL] Sending tx \(index + 1)/\(encodedTransactions.count)...")
            let hash = try await sendSolanaDelegationTransaction(portal: portal, encodedTransaction: encodedTx, chain: request.chain)
            logger.info("✅ [Delegation TransferFrom SOL] Tx \(index + 1) hash: \(hash)")
          }
        }

        showStatusView(message: "\(successStatus) TransferFrom (SOL) completed")

      } catch {
        logger.error("❌ [Delegation TransferFrom SOL] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) TransferFrom (SOL) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation Get Status (ETH)

  @IBAction func delegationGetStatusETH(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Get Status ETH] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Get Status ETH] Querying status...")

        let request = GetDelegationStatusRequest(
          chain: "eip155:11155111",
          token: "USDC",
          delegateAddress: "0xa944e86eb36f039becd1843132347eb5b8501562"
        )

        let response = try await portal.delegations.getStatus(request: request)

        logStatusResult(response, label: "ETH")

        showStatusView(message: "\(successStatus) Get Status (ETH) - \(response.delegations.count) delegation(s)")

      } catch {
        logger.error("❌ [Delegation Get Status ETH] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Get Status (ETH) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Delegation Get Status (SOL)

  @IBAction func delegationGetStatusSOL(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Delegation Get Status SOL] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Delegation Get Status SOL] Querying status...")

        let request = GetDelegationStatusRequest(
          chain: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
          token: "USDC",
          delegateAddress: "7smgSuU5mjP7QY5yWGdaTfgKn8hUWwvQgfvgcZB3HmJi"
        )

        let response = try await portal.delegations.getStatus(request: request)

        logStatusResult(response, label: "SOL")

        showStatusView(message: "\(successStatus) Get Status (SOL) - \(response.delegations.count) delegation(s)")

      } catch {
        logger.error("❌ [Delegation Get Status SOL] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Get Status (SOL) failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Transaction Sending Helpers

  /// Sends a single EVM delegation transaction via `eth_sendTransaction`.
  /// Converts the `ConstructedEipTransaction` to a dictionary and calls `portal.request`.
  /// - Parameters:
  ///   - portal: The Portal instance
  ///   - transaction: The EVM transaction to sign and send
  ///   - chain: The CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: The transaction hash
  private func sendEVMDelegationTransaction(
    portal: PortalProtocol,
    transaction: ConstructedEipTransaction,
    chain: String
  ) async throws -> String {
    // Build the transaction dictionary for eth_sendTransaction
    var txDict: [String: String] = [
      "from": transaction.from,
      "to": transaction.to
    ]
    if let data = transaction.data {
      txDict["data"] = data
    }
    if let value = transaction.value {
      txDict["value"] = value
    }

    logger.info("📤 [EVM] Sending transaction: from=\(transaction.from), to=\(transaction.to)")

    let response = try await portal.request(
      chainId: chain,
      method: .eth_sendTransaction,
      params: [txDict],
      options: nil
    )

    guard let txHash = response.result as? String else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    logger.info("✅ [EVM] Transaction sent! Hash: \(txHash)")
    return txHash
  }

  /// Sends a single Solana delegation transaction via `sol_signAndSendTransaction`.
  /// - Parameters:
  ///   - portal: The Portal instance
  ///   - encodedTransaction: The encoded Solana transaction string
  ///   - chain: The CAIP-2 chain ID (e.g., "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  /// - Returns: The transaction hash
  private func sendSolanaDelegationTransaction(
    portal: PortalProtocol,
    encodedTransaction: String,
    chain: String
  ) async throws -> String {
    logger.info("📤 [Solana] Sending encoded transaction...")

    let response = try await portal.request(
      chainId: chain,
      method: .sol_signAndSendTransaction,
      params: [encodedTransaction],
      options: nil
    )

    guard let txHash = response.result as? String else {
      throw PortalExampleAppError.invalidResponseTypeForRequest()
    }

    logger.info("✅ [Solana] Transaction sent! Hash: \(txHash)")
    return txHash
  }

  // MARK: - Private Logging Helpers

  private func logApproveResult(_ response: ApproveDelegationResponse, label: String) {
    logger.info("📊 [Delegation Approve Result - \(label)]")

    if let metadata = response.metadata {
      logger.info("  Chain ID: \(metadata.chainId)")
      logger.info("  Delegate Amount: \(metadata.delegateAmount)")
      logger.info("  Delegate Address: \(metadata.delegateAddress)")
      logger.info("  Token Symbol: \(metadata.tokenSymbol)")
      if let tokenAddress = metadata.tokenAddress {
        logger.info("  Token Address: \(tokenAddress)")
      }
      if let ownerAddress = metadata.ownerAddress {
        logger.info("  Owner Address: \(ownerAddress)")
      }
      if let tokenDecimals = metadata.tokenDecimals {
        logger.info("  Token Decimals: \(tokenDecimals)")
      }
    }

    if let txs = response.transactions {
      logger.info("  EVM Transactions: \(txs.count)")
      for (i, tx) in txs.enumerated() {
        logger.info("    tx[\(i)]: from=\(tx.from), to=\(tx.to), data=\(tx.data ?? "nil"), value=\(tx.value ?? "nil")")
      }
    }

    if let encodedTxs = response.encodedTransactions {
      logger.info("  Solana Encoded Transactions: \(encodedTxs.count)")
    }
  }

  private func logRevokeResult(_ response: RevokeDelegationResponse, label: String) {
    logger.info("📊 [Delegation Revoke Result - \(label)]")

    if let metadata = response.metadata {
      logger.info("  Chain ID: \(metadata.chainId)")
      logger.info("  Revoked Address: \(metadata.revokedAddress)")
      logger.info("  Token Symbol: \(metadata.tokenSymbol)")
      if let tokenAddress = metadata.tokenAddress {
        logger.info("  Token Address: \(tokenAddress)")
      }
    }

    if let txs = response.transactions {
      logger.info("  EVM Transactions: \(txs.count)")
    }

    if let encodedTxs = response.encodedTransactions {
      logger.info("  Solana Encoded Transactions: \(encodedTxs.count)")
    }
  }

  private func logTransferFromResult(_ response: TransferFromResponse, label: String) {
    logger.info("📊 [Delegation TransferFrom Result - \(label)]")
    logger.info("  Amount: \(response.metadata.amount)")
    logger.info("  Amount Raw: \(response.metadata.amountRaw)")
    logger.info("  Chain ID: \(response.metadata.chainId)")

    if let delegateAddress = response.metadata.delegateAddress {
      logger.info("  Delegate Address: \(delegateAddress)")
    }
    if let tokenSymbol = response.metadata.tokenSymbol {
      logger.info("  Token Symbol: \(tokenSymbol)")
    }

    if let txs = response.transactions {
      logger.info("  EVM Transactions: \(txs.count)")
      for (i, tx) in txs.enumerated() {
        logger.info("    tx[\(i)]: from=\(tx.from), to=\(tx.to), data=\(tx.data ?? "nil"), value=\(tx.value ?? "nil")")
      }
    }

    if let encodedTxs = response.encodedTransactions {
      logger.info("  Solana Encoded Transactions: \(encodedTxs.count)")
    }
  }

  private func logStatusResult(_ response: DelegationStatusResponse, label: String) {
    logger.info("📊 [Delegation Status Result - \(label)]")
    logger.info("  Chain ID: \(response.chainId)")
    logger.info("  Token: \(response.token)")
    logger.info("  Token Address: \(response.tokenAddress)")

    if let tokenAccount = response.tokenAccount {
      logger.info("  Token Account: \(tokenAccount)")
    }
    if let balance = response.balance {
      logger.info("  Balance: \(balance)")
    }
    if let balanceRaw = response.balanceRaw {
      logger.info("  Balance Raw: \(balanceRaw)")
    }

    logger.info("  Delegations: \(response.delegations.count)")
    for delegation in response.delegations {
      logger.info("    - Address: \(delegation.address), Amount: \(delegation.delegateAmount) (Raw: \(delegation.delegateAmountRaw))")
    }
  }
}

//
//  ViewController+YieldXyzBorrow.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Yield.xyz Borrow testing functionality, on the market the React Native and Web SDKs were
//  validated on: Morpho Blue WMON/USDC on Monad mainnet. The read actions are free; the one write
//  action (supply) moves real funds and asks for confirmation first.
//

import Foundation
import PortalSwift
import UIKit

/// What the example keeps between runs to resume an execution. Touched on the main actor only.
private enum BorrowExampleState {
  /// The action to continue, with its transactions in signing order: the one built, then the latest
  /// step or failure an execution reported.
  static var lastAction: YieldXyzBorrowAction?
  static var lastFailure: YieldXyzBorrowExecutionError?
  /// Every transaction already broadcast, by id. A resume submits these instead of signing them
  /// again, whichever failure came last.
  static var broadcastHashes: [String: String] = [:]

  static func start(_ action: YieldXyzBorrowAction) {
    lastAction = action
    lastFailure = nil
    broadcastHashes = [:]
  }
}

/// Collects what an execution reports while it runs: the hash of each transaction it broadcasts,
/// and the latest step it moved to. The runner reports from any thread.
private final class BorrowProgressRecorder {
  private let lock = NSLock()
  private var hashes: [String: String] = [:]
  private var stepAction: YieldXyzBorrowAction?

  func record(_ progress: YieldXyzBorrowExecutionProgress) {
    lock.lock()
    defer { lock.unlock() }
    if progress.step == .confirming, let transactionId = progress.transactionId, let broadcastHash = progress.broadcastHash {
      hashes[transactionId] = broadcastHash
    }
    if progress.step == .nextStep, let action = progress.action {
      stepAction = action
    }
  }

  var recorded: (hashes: [String: String], stepAction: YieldXyzBorrowAction?) {
    lock.lock()
    defer { lock.unlock() }
    return (hashes, stepAction)
  }
}

@available(iOS 16.0, *)
extension ViewController {
  private var borrowIntegrationId: String {
    "morpho-blue-borrow"
  }

  /// Monad mainnet. Signing on it needs an `rpcConfig` entry; the default configuration has one.
  private var borrowNetwork: String {
    "eip155:143"
  }

  /// Runs `operation` with the loading indicator and reports its outcome.
  private func runBorrow(_ name: String, _ operation: @escaping (PortalProtocol) async throws -> String) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Borrow \(name)] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Borrow \(name)] Starting...")
        let summary = try await operation(portal)
        logger.info("✅ [Borrow \(name)] \(summary)")
        showStatusView(message: "\(successStatus) \(summary)")
      } catch {
        let detail = Self.describeBorrowError(error)
        logger.error("❌ [Borrow \(name)] \(detail)")
        showStatusView(message: "\(failureStatus) \(name) failed: \(detail)")
      }
    }
  }

  /// A readable description of a borrow failure, including the Portal error id when there is one.
  private static func describeBorrowError(_ error: Error) -> String {
    if let execution = error as? YieldXyzBorrowExecutionError {
      let hash = execution.broadcastHash.map { " (broadcast \($0))" } ?? ""
      return "\(execution.reason.rawValue): \(execution.message)\(hash)"
    }
    if let apiError = YieldXyzBorrowApiError.from(error) {
      let status = apiError.status.map(String.init) ?? "?"
      return "HTTP \(status) \(apiError.id ?? "") \(apiError.message ?? "")"
    }
    return error.localizedDescription
  }

  /// The wallet's EVM address; Borrow requests take it explicitly.
  private static func borrowWalletAddress(_ portal: PortalProtocol) async throws -> String {
    guard let address = await portal.getAddress("eip155:143") else {
      throw PortalExampleBorrowError.noEvmAddress
    }
    return address
  }

  /// The Morpho Blue WMON/USDC market on Monad, found across every page of markets. Nothing else
  /// stands in for it: a supply posts the market's collateral, and the confirmation promises WMON.
  private func borrowMarket(_ portal: PortalProtocol) async throws -> YieldXyzBorrowMarket {
    var offset = 0
    while true {
      let page = try await portal.borrow.yieldxyz.getMarkets(params: YieldXyzBorrowGetMarketsParams(
        offset: offset,
        limit: 100,
        integrationId: borrowIntegrationId,
        network: borrowNetwork,
        // No Borrow market is enabled for the Yield.xyz project yet, so `enabled` lists none.
        scope: .all
      )).data
      let wmonUsdc = page.items.first { market in
        market.loanToken.symbol == "USDC" && market.collateralTokens.contains { $0.token.symbol == "WMON" }
      }
      if let wmonUsdc {
        return wmonUsdc
      }
      offset += page.items.count
      if page.items.isEmpty || offset >= page.total {
        throw PortalExampleBorrowError.noMarket
      }
    }
  }

  // MARK: - Reads

  @IBAction func borrowGetHealth(_: Any) {
    runBorrow("Get Health") { portal in
      let health = try await portal.borrow.yieldxyz.getHealth().data
      return "API \(health.status) at \(health.timestamp)"
    }
  }

  @IBAction func borrowGetIntegrations(_: Any) {
    runBorrow("Get Integrations") { portal in
      let integrations = try await portal.borrow.yieldxyz.getIntegrations().data
      return "Integrations: " + integrations.map { "\($0.id) (\($0.actions.map(\.id.rawValue).joined(separator: "/")))" }.joined(separator: ", ")
    }
  }

  @IBAction func borrowGetMarkets(_: Any) {
    runBorrow("Get Markets") { [borrowIntegrationId, borrowNetwork] portal in
      let page = try await portal.borrow.yieldxyz.getMarkets(params: YieldXyzBorrowGetMarketsParams(
        limit: 5,
        integrationId: borrowIntegrationId,
        network: borrowNetwork,
        scope: .all
      )).data
      let markets = page.items.map { "\($0.loanToken.symbol) @ \($0.borrowRate)" }.joined(separator: ", ")
      return "\(page.total) markets. First 5: \(markets)"
    }
  }

  @IBAction func borrowGetMarket(_: Any) {
    runBorrow("Get Market") { [weak self] portal in
      guard let self else {
        return "Cancelled"
      }
      let listed = try await self.borrowMarket(portal)
      let market = try await portal.borrow.yieldxyz.getMarket(marketId: listed.id).data
      let collateral = market.collateralTokens.map { "\($0.token.symbol) max LTV \($0.maxLtv)" }.joined(separator: ", ")
      return "\(market.id) [\(market.type)] loan \(market.loanToken.symbol), collateral \(collateral), min loan \(market.minLoan ?? "none")"
    }
  }

  @IBAction func borrowGetPositions(_: Any) {
    runBorrow("Get Positions") { [borrowIntegrationId, borrowNetwork] portal in
      let address = try await Self.borrowWalletAddress(portal)
      let position = try await portal.borrow.yieldxyz.getPositions(params: YieldXyzBorrowGetPositionsParams(
        integrationId: borrowIntegrationId,
        network: borrowNetwork,
        address: address
      )).data
      // A nil health factor means unknown, never safe.
      return "Supplied $\(position.totalSuppliedUsd), borrowed $\(position.totalBorrowedUsd), health \(position.healthFactor ?? "unknown"), "
        + "\(position.supplyBalances.count) supply / \(position.debtBalances.count) debt balances"
    }
  }

  @IBAction func borrowGetLiquidations(_: Any) {
    runBorrow("Get Liquidations") { [borrowIntegrationId, borrowNetwork] portal in
      let address = try await Self.borrowWalletAddress(portal)
      let page = try await portal.borrow.yieldxyz.getLiquidations(params: YieldXyzBorrowGetLiquidationsParams(
        limit: 10,
        integrationId: borrowIntegrationId,
        network: borrowNetwork,
        address: address
      )).data
      return "\(page.total) liquidations"
    }
  }

  @IBAction func borrowGetActions(_: Any) {
    runBorrow("Get Actions") { portal in
      let address = try await Self.borrowWalletAddress(portal)
      let page = try await portal.borrow.yieldxyz.getActions(params: YieldXyzBorrowGetActionsParams(limit: 10, address: address)).data
      return "\(page.total) actions: " + page.items.map { "\($0.action) \($0.status)" }.joined(separator: ", ")
    }
  }

  // MARK: - Actions

  /// Builds a supply of 0.1 WMON collateral without signing it, to show the transactions and the
  /// predicted position the user would confirm.
  @IBAction func borrowBuildSupply(_: Any) {
    runBorrow("Build Supply") { [weak self] portal in
      guard let self else {
        return "Cancelled"
      }
      let action = try await self.buildBorrowSupply(portal)
      BorrowExampleState.start(action)
      let transactions = action.transactions.map { "\($0.type) (\($0.status))" }.joined(separator: ", ")
      let metadata = action.metadata.map { "LTV \($0.currentLtv) → \($0.predictedLtv), health \($0.predictedHealthFactor ?? "unknown")" } ?? "no metadata"
      return "Built \(action.action) \(action.id) step \(action.currentStep)/\(action.totalSteps): \(transactions); \(metadata)"
    }
  }

  private func buildBorrowSupply(_ portal: PortalProtocol) async throws -> YieldXyzBorrowAction {
    let address = try await Self.borrowWalletAddress(portal)
    let market = try await borrowMarket(portal)
    // Morpho Blue infers the token from the market; `supply` only posts collateral there.
    return try await portal.borrow.yieldxyz.createAction(params: YieldXyzBorrowCreateActionParams(
      integrationId: borrowIntegrationId,
      action: .supply,
      address: address,
      args: YieldXyzBorrowActionArguments(marketId: market.id, amount: "0.1")
    )).data
  }

  /// Supplies 0.1 WMON as collateral: signs and submits each transaction in order, then tracks the
  /// action. It continues the action built or left by the last execution, if any, with the hashes it
  /// already broadcast. It moves real funds on Monad mainnet, so it asks first.
  @IBAction func borrowExecuteSupply(_: Any) {
    let alert = UIAlertController(
      title: "Supply 0.1 WMON on Morpho Blue?",
      message: "This signs real Monad mainnet transactions with your Portal wallet and posts 0.1 WMON (or wraps MON) as collateral.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Supply", style: .destructive) { [weak self] _ in
      guard let self else {
        return
      }
      self.runBorrow("Execute Supply") { [weak self] portal in
        guard let self else {
          return "Cancelled"
        }
        if BorrowExampleState.lastAction == nil {
          try await BorrowExampleState.start(self.buildBorrowSupply(portal))
        }
        return try await self.continueBorrowExecution(portal)
      }
    })
    present(alert, animated: true)
  }

  /// Resumes the last failed execution from the latest action it reported, submitting the
  /// transactions it had already broadcast instead of signing them again.
  @IBAction func borrowResumeLastFailure(_: Any) {
    runBorrow("Resume") { [weak self] portal in
      guard let self else {
        return "Cancelled"
      }
      guard BorrowExampleState.lastFailure != nil, BorrowExampleState.lastAction != nil else {
        return "No failed execution to resume."
      }
      return try await self.continueBorrowExecution(portal)
    }
  }

  /// Executes `BorrowExampleState.lastAction` with every hash broadcast so far, and keeps what the
  /// execution reported for the next attempt. After `userOperationFailed`, that transaction is signed
  /// again without its idempotency key: Portal remembers the key and would refuse to send it again.
  private func continueBorrowExecution(_ portal: PortalProtocol) async throws -> String {
    guard let action = BorrowExampleState.lastAction else {
      return "No action to execute."
    }
    let userOperationFailed = BorrowExampleState.lastFailure?.reason == .userOperationFailed
    let recorder = BorrowProgressRecorder()
    let logger = self.logger
    do {
      let result = try await portal.borrow.yieldxyz.signAndSubmitAction(action, options: YieldXyzBorrowExecuteOptions(
        onProgress: { progress in
          recorder.record(progress)
          logger.info("⏳ [Borrow] \(progress.step.rawValue) \(progress.transactionId ?? "") \(progress.broadcastHash ?? "") \(progress.actionStatus?.rawValue ?? "")")
        },
        useIdempotencyKeys: !userOperationFailed,
        broadcastHashes: BorrowExampleState.broadcastHashes
      ))
      BorrowExampleState.lastAction = nil
      BorrowExampleState.lastFailure = nil
      BorrowExampleState.broadcastHashes = [:]
      let hashes = result.transactions.map(\.transactionHash).joined(separator: ", ")
      return "Action \(result.actionId) ended \(result.status) after \(result.transactions.count) transaction(s): \(hashes)"
    } catch {
      let recorded = recorder.recorded
      BorrowExampleState.broadcastHashes.merge(recorded.hashes) { _, latest in latest }
      let failure = error as? YieldXyzBorrowExecutionError
      if let failure, let transactionId = failure.transactionId {
        if failure.reason == .userOperationFailed {
          // Its user operation was processed and did not succeed: sign it again rather than resume it.
          BorrowExampleState.broadcastHashes[transactionId] = nil
        } else if let broadcastHash = failure.broadcastHash {
          BorrowExampleState.broadcastHashes[transactionId] = broadcastHash
        }
      }
      BorrowExampleState.lastAction = failure?.action ?? recorded.stepAction ?? action
      BorrowExampleState.lastFailure = failure
      throw error
    }
  }
}

private enum PortalExampleBorrowError: LocalizedError {
  case noEvmAddress
  case noMarket

  var errorDescription: String? {
    switch self {
    case .noEvmAddress:
      return "The wallet has no EVM address."
    case .noMarket:
      return "The Morpho Blue WMON/USDC market is not listed on Monad."
    }
  }
}

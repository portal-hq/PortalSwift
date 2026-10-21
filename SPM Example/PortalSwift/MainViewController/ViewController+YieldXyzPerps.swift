//
//  ViewController+YieldXyzPerps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Yield.xyz Perps testing functionality. Perps is mainnet-only: the read actions are free, and
//  the one write action (approve agent) moves no funds. It registers a random agent address that no
//  one holds a key for, so the agent can never trade. It follows the flow the SDK recommends: build
//  the action, show its `summary`, and sign only once the user confirms.
//

import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  /// The launch venue; the venues a client can use come from `getProviders()`.
  private var perpsProviderId: String {
    "hyperliquid"
  }

  /// Runs `operation` with the loading indicator and reports its outcome.
  private func runPerps(_ name: String, _ operation: @escaping (PortalProtocol) async throws -> String) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Perps \(name)] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Perps \(name)] Starting...")
        let summary = try await operation(portal)
        logger.info("✅ [Perps \(name)] \(summary)")
        showStatusView(message: "\(successStatus) \(summary)")
      } catch {
        let detail = Self.describePerpsError(error)
        logger.error("❌ [Perps \(name)] \(detail)")
        showStatusView(message: "\(failureStatus) \(name) failed: \(detail)")
      }
    }
  }

  /// A readable description of a perps failure. An execution failure carries what a resume needs:
  /// its `reason`, the action and transaction ids, and the `broadcastHash` of an on-chain leg that
  /// was already sent. The Portal error id, when there is one, comes from `YieldXyzPerpsApiError`.
  private static func describePerpsError(_ error: Error) -> String {
    var parts: [String] = []
    if let execution = error as? YieldXyzPerpsExecutionError {
      parts.append("\(execution.reason.rawValue): \(execution.message)")
      if let actionId = execution.actionId {
        parts.append("action \(actionId)")
      }
      if let transactionId = execution.transactionId {
        parts.append("transaction \(transactionId)")
      }
      // The leg is on-chain: resume with `broadcastHashes: [transactionId: hash]`, never by re-signing.
      if let broadcastHash = execution.broadcastHash {
        parts.append("broadcastHash \(broadcastHash) (resume with broadcastHashes)")
      }
      // The venue's reason for a failed leg, when it gave one.
      for transaction in execution.action?.transactions ?? [] where transaction.status == .failed {
        let reason = [transaction.error?.code, transaction.error?.message].compactMap { $0 }.joined(separator: " ")
        parts.append("transaction \(transaction.id) FAILED: \(reason.isEmpty ? "no reason given" : reason)")
      }
    }
    if let apiError = YieldXyzPerpsApiError.from(error) {
      let status = "HTTP \(apiError.status.map(String.init) ?? "?")"
      parts.append([status, apiError.id, apiError.code, apiError.reason, apiError.message].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
    }
    return parts.isEmpty ? error.localizedDescription : parts.joined(separator: "; ")
  }

  /// The fields of an action summary worth showing before the user signs; Yield.xyz fills only the
  /// ones that apply to the action.
  private static func describe(_ summary: YieldXyzPerpsActionSummary?) -> String {
    guard let summary else {
      return "Yield.xyz returned no summary for this action."
    }
    let fields: [(String, String?)] = [
      ("Asset", summary.asset),
      ("Direction", summary.direction?.rawValue),
      ("Size", summary.size),
      ("Leverage", summary.leverage.map { String(format: "%gx", $0) }),
      ("Price", summary.price.map { "\($0)" }),
      ("Collateral", summary.collateral),
      ("Fee", summary.fee),
      ("Est. liquidation", summary.estimatedLiquidationPrice.map { "\($0)" }),
      ("Amount", summary.amount),
      ("Agent", summary.agentName),
      ("Agent address", summary.agentAddress)
    ]
    let lines = fields.compactMap { label, value in value.map { "\(label): \($0)" } }
    return ([summary.type] + lines).joined(separator: "\n")
  }

  // MARK: - Market data

  @IBAction func perpsGetProviders(_: Any) {
    runPerps("Get Providers") { portal in
      let providers = try await portal.perps.yieldxyz.getProviders().data
      return "Venues: " + providers.map { "\($0.id) (\($0.supportedActions.count) actions)" }.joined(separator: ", ")
    }
  }

  @IBAction func perpsGetMarkets(_: Any) {
    runPerps("Get Markets") { [perpsProviderId] portal in
      let page = try await portal.perps.yieldxyz.getMarkets(params: YieldXyzPerpsGetMarketsParams(
        limit: 5,
        providerId: perpsProviderId,
        sortBy: .volume24h,
        order: .desc
      )).data
      let markets = page.items.map { "\($0.id) @ \($0.markPrice)" }.joined(separator: ", ")
      return "\(page.total) markets. Top 5: \(markets)"
    }
  }

  @IBAction func perpsGetCandles(_: Any) {
    runPerps("Get Candles") { [perpsProviderId] portal in
      let markets = try await portal.perps.yieldxyz.getMarkets(params: YieldXyzPerpsGetMarketsParams(limit: 1, providerId: perpsProviderId)).data
      guard let market = markets.items.first else {
        return "No markets listed."
      }
      let oneDayAgo = Int64(Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000)
      let candles = try await portal.perps.yieldxyz.getMarketCandles(
        marketId: market.id,
        params: YieldXyzPerpsGetMarketCandlesParams(interval: .oneHour, from: oneDayAgo)
      ).data
      return "\(candles.candles.count) hourly candles for \(market.id); last close \(candles.candles.last?.close ?? "-")"
    }
  }

  // MARK: - Account data

  @IBAction func perpsGetPositions(_: Any) {
    runPerps("Get Positions") { [perpsProviderId] portal in
      let positions = try await portal.perps.yieldxyz.getPositions(params: YieldXyzPerpsPortfolioParams(providerId: perpsProviderId)).data
      if positions.isEmpty {
        return "No open positions."
      }
      return positions.map { "\($0.side) \($0.size) \($0.marketId) PnL \($0.unrealizedPnl)" }.joined(separator: "; ")
    }
  }

  @IBAction func perpsGetOrders(_: Any) {
    runPerps("Get Orders") { [perpsProviderId] portal in
      let orders = try await portal.perps.yieldxyz.getOrders(params: YieldXyzPerpsPortfolioParams(providerId: perpsProviderId)).data
      return orders.isEmpty ? "No resting orders." : "\(orders.count) resting orders."
    }
  }

  @IBAction func perpsGetBalances(_: Any) {
    runPerps("Get Balances") { [perpsProviderId] portal in
      let balance = try await portal.perps.yieldxyz.getBalances(params: YieldXyzPerpsBalancesParams(providerId: perpsProviderId)).data
      return "Account value \(balance.accountValue) \(balance.collateral.symbol), available \(balance.availableBalance)"
    }
  }

  // MARK: - History

  @IBAction func perpsGetActivity(_: Any) {
    runPerps("Get Activity") { [perpsProviderId] portal in
      let page = try await portal.perps.yieldxyz.getActivity(params: YieldXyzPerpsGetActivityParams(limit: 10, providerId: perpsProviderId)).data
      return "\(page.total) activity items: " + page.items.map(\.type).joined(separator: ", ")
    }
  }

  @IBAction func perpsGetEvents(_: Any) {
    runPerps("Get Events") { [perpsProviderId] portal in
      let page = try await portal.perps.yieldxyz.getEvents(params: YieldXyzPerpsGetEventsParams(limit: 10, providerId: perpsProviderId)).data
      return "\(page.total) events: " + page.items.map(\.eventType.rawValue).joined(separator: ", ")
    }
  }

  // MARK: - Health

  @IBAction func perpsGetHealth(_: Any) {
    runPerps("Get Health") { portal in
      let health = try await portal.perps.yieldxyz.getHealth().data
      let venues = try await portal.perps.yieldxyz.getProvidersHealth().data
      return "API \(health.status); venues: " + venues.providers.map { "\($0.providerId) \($0.state)" }.joined(separator: ", ")
    }
  }

  // MARK: - Actions

  /// The `agentAddress` `approveAgent` requires. A real integration registers the address of a trading
  /// key it generated and holds, so orders need no wallet prompt; this example has no such key, so it
  /// registers a random address no one holds, which can never trade.
  private static func throwawayAgentAddress() -> String {
    "0x" + (0 ..< 20).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
  }

  /// Builds an `approveAgent` action without signing it, to show what the API returns.
  @IBAction func perpsBuildApproveAgent(_: Any) {
    runPerps("Build Approve Agent") { [perpsProviderId] portal in
      let action = try await portal.perps.yieldxyz.createAction(params: YieldXyzPerpsCreateActionParams(
        providerId: perpsProviderId,
        action: .approveAgent,
        args: YieldXyzPerpsActionArgs(agentAddress: Self.throwawayAgentAddress(), agentName: "portal-example")
      )).data
      let formats = action.transactions.map { "\($0.type) (\($0.signingFormat?.rawValue ?? "none"))" }.joined(separator: ", ")
      return "Built \(action.action) \(action.id) [\(action.status)]: \(formats)"
    }
  }

  /// Approves an agent in the two steps the SDK recommends: build the action, show its `summary` for
  /// the user to confirm, then sign and submit it. It is a real mainnet signature, but it moves no
  /// funds and the agent (a random address no one holds) can never trade.
  @IBAction func perpsExecuteApproveAgent(_: Any) {
    runPerps("Execute Approve Agent (build, nothing signed)") { [weak self, perpsProviderId] portal in
      let action = try await portal.perps.yieldxyz.createAction(params: YieldXyzPerpsCreateActionParams(
        providerId: perpsProviderId,
        action: .approveAgent,
        args: YieldXyzPerpsActionArgs(agentAddress: Self.throwawayAgentAddress(), agentName: "portal-example")
      )).data
      await self?.confirmAndExecute(action)
      return "Built \(action.action) \(action.id); nothing signed yet, awaiting approval."
    }
  }

  /// Shows the action's summary and signs nothing unless the user confirms.
  @MainActor
  private func confirmAndExecute(_ action: YieldXyzPerpsAction) {
    let alert = UIAlertController(
      title: "Approve Hyperliquid agent?",
      message: "\(Self.describe(action.summary))\n\nThis signs a real mainnet approval with your Portal wallet. It registers a random agent address that no one holds a key for, so it can never trade, and it moves no funds. The client must not use account abstraction.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
      self?.logger.info("⏹ [Perps Execute Approve Agent] Cancelled; nothing was signed.")
      self?.showStatusView(message: "Execute Approve Agent cancelled; nothing was signed.")
    })
    alert.addAction(UIAlertAction(title: "Approve", style: .destructive) { [weak self] _ in
      guard let self else {
        return
      }
      let logger = self.logger
      self.runPerps("Sign and Submit Approve Agent") { portal in
        let result = try await portal.perps.yieldxyz.signAndSubmitAction(
          action,
          options: YieldXyzPerpsExecuteOptions(onProgress: { progress in
            logger.info("⏳ [Perps Approve Agent] \(progress.step.rawValue) \(progress.transactionId ?? "") \(progress.actionStatus?.rawValue ?? "")")
          })
        )
        return "Action \(result.actionId) ended \(result.status) after \(result.transactions.count) transaction(s)."
      }
    })
    present(alert, animated: true)
  }
}

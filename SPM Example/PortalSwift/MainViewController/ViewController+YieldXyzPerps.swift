//
//  ViewController+YieldXyzPerps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Yield.xyz Perps testing functionality. Perps is mainnet-only: the read actions are free, and
//  the one write action (approve agent) moves no funds and asks for confirmation first.
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

  /// A readable description of a perps failure, including the Portal error id when there is one.
  private static func describePerpsError(_ error: Error) -> String {
    if let apiError = YieldXyzPerpsApiError.from(error) {
      let status = apiError.status.map(String.init) ?? "?"
      return "HTTP \(status) \(apiError.id ?? "") \(apiError.message ?? "")"
    }
    return error.localizedDescription
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
    runPerps("Get Activity") { portal in
      let page = try await portal.perps.yieldxyz.getActivity(params: YieldXyzPerpsGetActivityParams(limit: 10)).data
      return "\(page.total) activity items: " + page.items.map(\.type).joined(separator: ", ")
    }
  }

  @IBAction func perpsGetEvents(_: Any) {
    runPerps("Get Events") { portal in
      let page = try await portal.perps.yieldxyz.getEvents(params: YieldXyzPerpsGetEventsParams(limit: 10)).data
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

  /// Builds an `approveAgent` action without signing it, to show what the API returns.
  @IBAction func perpsBuildApproveAgent(_: Any) {
    runPerps("Build Approve Agent") { [perpsProviderId] portal in
      let action = try await portal.perps.yieldxyz.createAction(params: YieldXyzPerpsCreateActionParams(
        providerId: perpsProviderId,
        action: .approveAgent,
        args: YieldXyzPerpsActionArgs(agentName: "portal-example")
      )).data
      let formats = action.transactions.map { "\($0.type) (\($0.signingFormat?.rawValue ?? "none"))" }.joined(separator: ", ")
      return "Built \(action.action) \(action.id) [\(action.status)]: \(formats)"
    }
  }

  /// Approves the venue's agent wallet: signs and submits each transaction, then tracks the action.
  /// It moves no funds, but it is a real mainnet signature, so it asks first.
  @IBAction func perpsExecuteApproveAgent(_: Any) {
    let alert = UIAlertController(
      title: "Approve Hyperliquid agent?",
      message: "This signs a real mainnet approval with your Portal wallet. It moves no funds. The client must not use account abstraction.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Approve", style: .destructive) { [weak self] _ in
      guard let self else {
        return
      }
      let logger = self.logger
      self.runPerps("Execute Approve Agent") { [perpsProviderId] portal in
        let result = try await portal.perps.yieldxyz.executeAction(
          params: YieldXyzPerpsCreateActionParams(
            providerId: perpsProviderId,
            action: .approveAgent,
            args: YieldXyzPerpsActionArgs(agentName: "portal-example")
          ),
          options: YieldXyzPerpsExecuteOptions(onProgress: { progress in
            logger.info("⏳ [Perps Execute Approve Agent] \(progress.step.rawValue) \(progress.transactionId ?? "") \(progress.actionStatus?.rawValue ?? "")")
          })
        )
        return "Action \(result.actionId) ended \(result.status) after \(result.transactions.count) transaction(s)."
      }
    })
    present(alert, animated: true)
  }
}

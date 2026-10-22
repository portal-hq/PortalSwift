//
//  ViewController+YieldXyzPerps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Yield.xyz Perps testing functionality. Perps is mainnet-only: the read actions are free, and
//  approve agent moves no funds. It registers a random agent address that no one holds a key for, so
//  the agent can never trade. "Any action" builds any action from a preset or your own JSON, so the
//  whole lifecycle (fund, leverage, open, TP/SL, close, withdraw) can be tested; it can move real
//  funds. Every write follows the flow the SDK recommends: build the action, show its `summary`, and
//  sign only once the user confirms.
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

  // MARK: - Any action

  /// An action to build, which the user can edit before anything is built.
  private struct PerpsPreset {
    let title: String
    let action: YieldXyzPerpsActionType
    let args: YieldXyzPerpsActionArgs
  }

  private struct PerpsExampleError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
      errorDescription = message
    }
  }

  /// Arbitrum's native USDC, the token Hyperliquid's Bridge2 accepts.
  private static let arbitrumUsdc = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"

  /// Hyperliquid's Bridge2 minimum: it never credits a smaller deposit, and the funds are lost.
  private static let bridge2MinimumUsdc = 5.0

  /// On-chain legs that were broadcast before a failure, by transaction id. They are passed to the
  /// next sign, so resuming the action reuses the hash instead of broadcasting the leg again.
  @MainActor private static var perpsBroadcastHashes: [String: String] = [:]

  /// Builds any action from a preset or your own JSON. Nothing is signed until you review the built
  /// action and confirm.
  @IBAction func perpsPrepareAction(_: Any) {
    runPerps("Any Action (load presets)") { [weak self, perpsProviderId] portal in
      let presets = try await Self.perpsPresets(portal: portal, providerId: perpsProviderId)
      await self?.choosePerpsPreset(presets)
      return "Loaded \(presets.count) presets; choose one."
    }
  }

  /// Loads an action by id to review and sign it, for example to resume one that failed part-way.
  @IBAction func perpsLoadAction(_: Any) {
    let alert = UIAlertController(
      title: "Load a Perps action",
      message: "Enter an action id to review and sign it, or to resume it after a failure.",
      preferredStyle: .alert
    )
    alert.addTextField { field in
      field.placeholder = "actionId"
      Self.configureForCode(field)
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Load", style: .default) { [weak self, weak alert] _ in
      let actionId = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      self?.runPerps("Load Action") { [weak self] portal in
        let action = try await portal.perps.yieldxyz.getAction(actionId: actionId).data
        await self?.reviewAndSign(action)
        return "Loaded \(action.action) \(action.id) [\(action.status)]; nothing signed yet."
      }
    })
    present(alert, animated: true)
  }

  /// Presets for the safe minimum of each step, filled from the account: the most traded BTC market
  /// and its price, the available balance, and the actions Yield.xyz offers on open positions and
  /// resting orders (`pendingActions`, with their args pre-filled).
  private static func perpsPresets(portal: PortalProtocol, providerId: String) async throws -> [PerpsPreset] {
    let perps = portal.perps.yieldxyz
    let markets = try await perps.getMarkets(params: YieldXyzPerpsGetMarketsParams(
      limit: 100,
      providerId: providerId,
      sortBy: .volume24h,
      order: .desc
    )).data.items
    let available = try? await perps.getBalances(params: YieldXyzPerpsBalancesParams(providerId: providerId)).data.availableBalance
    let positions = (try? await perps.getPositions(params: YieldXyzPerpsPortfolioParams(providerId: providerId)).data) ?? []
    let orders = (try? await perps.getOrders(params: YieldXyzPerpsPortfolioParams(providerId: providerId)).data) ?? []

    var presets = [
      PerpsPreset(
        title: "Fund 5 USDC from Arbitrum (Bridge2 minimum)",
        action: .fund,
        args: YieldXyzPerpsActionArgs(
          amount: "5",
          fromToken: YieldXyzPerpsTokenIdentifier(network: "eip155:42161", address: arbitrumUsdc),
          fundingMethod: .bridge2
        )
      )
    ]
    if let market = markets.first(where: { $0.baseAsset.symbol == "BTC" }) ?? markets.first {
      let symbol = market.baseAsset.symbol
      // Far below the market, so the limit order never fills.
      let farBelow = roundedPrice(market.markPrice * 0.5)
      presets += [
        PerpsPreset(
          title: "Update \(symbol) leverage to 3x isolated (free)",
          action: .updateLeverage,
          args: YieldXyzPerpsActionArgs(marketId: market.id, leverage: 3, marginMode: .isolated)
        ),
        PerpsPreset(
          title: "Place \(symbol) limit long at \(plainPrice(farBelow)) (never fills; free)",
          action: .open,
          args: YieldXyzPerpsActionArgs(marketId: market.id, side: .long, amount: "4", leverage: 3, marginMode: .isolated, limitPrice: farBelow)
        ),
        PerpsPreset(
          title: "Open \(symbol) long, 4 USDC at 3x (~$12, market)",
          action: .open,
          args: YieldXyzPerpsActionArgs(marketId: market.id, side: .long, amount: "4", leverage: 3, marginMode: .isolated)
        ),
        PerpsPreset(
          title: "Close the \(symbol) position",
          action: .close,
          args: YieldXyzPerpsActionArgs(marketId: market.id)
        )
      ]
      if let position = positions.first(where: { $0.marketId == market.id }) {
        presets.append(tpAndSlPreset(for: position, symbol: symbol))
      }
    }
    let withdrawable = available.map { floor($0 * 100) / 100 }.flatMap { $0 > 1 ? String(format: "%.2f", $0) : nil } ?? "2"
    presets.append(PerpsPreset(
      title: "Withdraw \(withdrawable) USDC to Arbitrum (Hyperliquid keeps $1)",
      action: .withdraw,
      args: YieldXyzPerpsActionArgs(amount: withdrawable)
    ))
    presets += (positions.flatMap(\.pendingActions) + orders.flatMap(\.pendingActions)).map { pending in
      PerpsPreset(title: "\(pending.label) (\(pending.args.marketId ?? "account"))", action: pending.type, args: pending.args)
    }
    presets.append(PerpsPreset(title: "Custom: type an action and its args", action: YieldXyzPerpsActionType(rawValue: ""), args: YieldXyzPerpsActionArgs()))
    return presets
  }

  /// TP/SL protects an open position, so it is offered only for one. The stop sits halfway between the
  /// price and the liquidation price, since a stop past liquidation can never trigger; the
  /// take-profit sits far from the price. Neither should trigger during a test.
  private static func tpAndSlPreset(for position: YieldXyzPerpsPosition, symbol: String) -> PerpsPreset {
    let isLong = position.side == .long
    let liquidation = position.liquidationPrice > 0 ? position.liquidationPrice : position.markPrice * (isLong ? 0.6 : 1.4)
    let stopLoss = roundedPrice((position.markPrice + liquidation) / 2)
    let takeProfit = roundedPrice(position.markPrice * (isLong ? 1.5 : 0.6))
    return PerpsPreset(
      title: "Set \(symbol) TP \(plainPrice(takeProfit)) / SL \(plainPrice(stopLoss)) on your \(position.side.rawValue)",
      action: .setTpAndSl,
      args: YieldXyzPerpsActionArgs(marketId: position.marketId, stopLossPrice: stopLoss, takeProfitPrice: takeProfit)
    )
  }

  private static func plainPrice(_ price: Double) -> String {
    price == price.rounded() ? String(Int64(price)) : String(price)
  }

  /// Rounds a price to 5 significant figures, the precision Hyperliquid accepts.
  private static func roundedPrice(_ price: Double) -> Double {
    guard price > 0 else {
      return price
    }
    let unit = pow(10, floor(log10(price)) - 4)
    return (price / unit).rounded() * unit
  }

  @MainActor
  private func choosePerpsPreset(_ presets: [PerpsPreset]) {
    let sheet = UIAlertController(title: "Build a Perps action", message: "You can edit the action and its args next.", preferredStyle: .actionSheet)
    for preset in presets {
      sheet.addAction(UIAlertAction(title: preset.title, style: .default) { [weak self] _ in
        self?.editPerpsPreset(preset)
      })
    }
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    sheet.popoverPresentationController?.sourceView = view
    present(sheet, animated: true)
  }

  @MainActor
  private func editPerpsPreset(_ preset: PerpsPreset) {
    let alert = UIAlertController(
      title: preset.title,
      message: "Edit the action and its args (JSON). Building signs nothing: you review the action before signing.",
      preferredStyle: .alert
    )
    alert.addTextField { field in
      field.text = preset.action.rawValue
      field.placeholder = "action, for example updateLeverage"
      Self.configureForCode(field)
    }
    alert.addTextField { field in
      field.text = Self.json(preset.args)
      field.placeholder = "args as JSON, for example {\"marketId\":\"...\"}"
      Self.configureForCode(field)
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Build", style: .default) { [weak self, weak alert] _ in
      let action = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let argsJSON = alert?.textFields?[1].text ?? ""
      self?.buildPerpsAction(action, argsJSON: argsJSON)
    })
    present(alert, animated: true)
  }

  /// JSON is typed, not prose: no smart quotes, autocorrection or capitalization.
  private static func configureForCode(_ field: UITextField) {
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.smartQuotesType = .no
    field.smartDashesType = .no
    field.spellCheckingType = .no
  }

  private static func json(_ args: YieldXyzPerpsActionArgs) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(args)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  private func buildPerpsAction(_ action: String, argsJSON: String) {
    runPerps("Build \(action.isEmpty ? "action" : action)") { [weak self, perpsProviderId] portal in
      guard !action.isEmpty else {
        throw PerpsExampleError("Enter an action, for example updateLeverage.")
      }
      let args: YieldXyzPerpsActionArgs
      do {
        args = try JSONDecoder().decode(YieldXyzPerpsActionArgs.self, from: Data(argsJSON.utf8))
      } catch {
        throw PerpsExampleError("The args must be a JSON object: \(error.localizedDescription)")
      }
      try Self.checkBridge2Minimum(action: action, args: args)
      let built = try await portal.perps.yieldxyz.createAction(params: YieldXyzPerpsCreateActionParams(
        providerId: perpsProviderId,
        action: YieldXyzPerpsActionType(rawValue: action),
        args: args
      )).data
      await self?.reviewAndSign(built)
      return "Built \(built.action) \(built.id) with \(built.transactions.count) transaction(s); nothing signed yet."
    }
  }

  /// Refuses a Bridge2 deposit under Hyperliquid's minimum before anything is built: Hyperliquid
  /// never credits it, and the funds are lost. The SDK leaves venue minimums to the app.
  private static func checkBridge2Minimum(action: String, args: YieldXyzPerpsActionArgs) throws {
    guard action == YieldXyzPerpsActionType.fund.rawValue else {
      return
    }
    let isArbitrumUsdc = args.fromToken?.network == "eip155:42161"
      && args.fromToken?.address?.lowercased() == arbitrumUsdc.lowercased()
    let usesBridge2 = args.fundingMethod == .bridge2 || (args.fundingMethod == nil && isArbitrumUsdc)
    guard usesBridge2 else {
      return
    }
    guard let amount = args.amount.flatMap(Double.init), amount >= bridge2MinimumUsdc else {
      throw PerpsExampleError("Hyperliquid never credits a Bridge2 deposit under 5 USDC, and the funds are lost. Fund at least 5.")
    }
  }

  /// Shows what the action will do and signs nothing unless the user confirms.
  @MainActor
  private func reviewAndSign(_ action: YieldXyzPerpsAction) {
    let legs = action.transactions.enumerated().map { index, transaction in
      "\(index + 1). \(transaction.type.rawValue) (\(transaction.signingFormat?.rawValue ?? "no signing format")) \(transaction.status.rawValue)"
    }.joined(separator: "\n")
    let alert = UIAlertController(
      title: "Sign and submit \(action.action.rawValue)?",
      message: "\(Self.describe(action.summary))\n\nTransactions:\n\(legs)\n\nAction \(action.id) [\(action.status.rawValue)]. This signs with your Portal wallet on mainnet and may move real funds; Yield.xyz Perps has no testnet.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
      self?.logger.info("⏹ [Perps \(action.action.rawValue)] Cancelled; nothing was signed. Action \(action.id) can be loaded later.")
      self?.showStatusView(message: "Cancelled; nothing was signed. Action \(action.id) can be loaded later.")
    })
    alert.addAction(UIAlertAction(title: "Sign & submit", style: .destructive) { [weak self] _ in
      self?.signPerpsAction(action)
    })
    present(alert, animated: true)
  }

  private func signPerpsAction(_ action: YieldXyzPerpsAction) {
    let logger = logger
    let name = action.action.rawValue
    runPerps("Sign and Submit \(name)") { portal in
      let broadcastHashes = await MainActor.run { Self.perpsBroadcastHashes }
      do {
        let result = try await portal.perps.yieldxyz.signAndSubmitAction(
          action,
          options: YieldXyzPerpsExecuteOptions(
            onProgress: { progress in
              logger.info("⏳ [Perps \(name)] \(progress.step.rawValue) \(progress.transactionId ?? "") \(progress.transactionHash ?? "") \(progress.actionStatus?.rawValue ?? "")")
            },
            broadcastHashes: broadcastHashes
          )
        )
        return "Action \(result.actionId) ended \(result.status) after \(result.transactions.count) transaction(s)."
      } catch let error as YieldXyzPerpsExecutionError {
        // Keep the hash of a leg that is already on-chain, so loading the action again resumes it.
        if let transactionId = error.transactionId, let broadcastHash = error.broadcastHash {
          await MainActor.run { Self.perpsBroadcastHashes[transactionId] = broadcastHash }
        }
        throw error
      }
    }
  }
}

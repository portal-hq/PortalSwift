//
//  ViewController+YieldXyzBorrow.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Yield.xyz Borrow testing functionality, on the market the React Native and Web SDKs were
//  validated on: Morpho Blue WMON/USDC on Monad mainnet. The read actions are free. "Any action"
//  builds any action from a preset or your own JSON, so the whole lifecycle (supply collateral,
//  borrow, repay, withdraw) can be tested; it moves real funds. Every write follows the flow the SDK
//  recommends: build the action, show its predicted health factor and LTV, and sign only once the
//  user confirms.
//

import Foundation
import PortalSwift
import UIKit

/// The action the last failed execution reported, in signing order, so Resume continues it.
/// Touched on the main actor only.
private enum BorrowExampleState {
  static var lastFailedAction: YieldXyzBorrowAction?
}

/// Collects the latest step an execution moved to. The runner reports from any thread.
private final class BorrowProgressRecorder {
  private let lock = NSLock()
  private var stepAction: YieldXyzBorrowAction?

  func record(_ progress: YieldXyzBorrowExecutionProgress) {
    lock.lock()
    defer { lock.unlock() }
    if progress.step == .nextStep, let action = progress.action {
      stepAction = action
    }
  }

  var recordedStepAction: YieldXyzBorrowAction? {
    lock.lock()
    defer { lock.unlock() }
    return stepAction
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

  /// A readable description of a borrow failure. An execution failure carries what a resume needs:
  /// its `reason`, the action and transaction ids, and the `broadcastHash` of a transaction that was
  /// already sent, plus the error underneath it. The Portal error id, when there is one, comes from
  /// `YieldXyzBorrowApiError`.
  private static func describeBorrowError(_ error: Error) -> String {
    var parts: [String] = []
    if let execution = error as? YieldXyzBorrowExecutionError {
      parts.append("\(execution.reason.rawValue): \(execution.message)")
      // Why it failed, for example the revert Portal hit estimating gas. An HTTP failure is described below.
      if let underlying = execution.underlyingError, YieldXyzBorrowApiError.from(underlying) == nil {
        parts.append("cause: \(describeBorrowCause(underlying))")
      }
      if let actionId = execution.actionId {
        parts.append("action \(actionId)")
      }
      if let transactionId = execution.transactionId {
        parts.append("transaction \(transactionId)")
      }
      // The transaction is on-chain: resume with `broadcastHashes: [transactionId: hash]`, never by re-signing.
      if let broadcastHash = execution.broadcastHash {
        parts.append("broadcastHash \(broadcastHash) (resume with broadcastHashes)")
      }
    }
    if let apiError = YieldXyzBorrowApiError.from(error) {
      let status = "HTTP \(apiError.status.map(String.init) ?? "?")"
      parts.append([status, apiError.id, apiError.message].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
    }
    return parts.isEmpty ? error.localizedDescription : parts.joined(separator: "; ")
  }

  /// An MPC failure's error id and message; otherwise the error as Swift prints it, which keeps an
  /// enum's case and associated values.
  private static func describeBorrowCause(_ error: Error) -> String {
    if let mpcError = error as? PortalMpcError {
      return "\(mpcError.id ?? "unknown"): \(mpcError.message ?? "unknown")"
    }
    return String(describing: error)
  }

  /// The wallet's EVM address; Borrow requests take it explicitly.
  private static func borrowWalletAddress(_ portal: PortalProtocol) async throws -> String {
    guard let address = await portal.getAddress("eip155:143") else {
      throw PortalExampleBorrowError.noEvmAddress
    }
    return address
  }

  /// The Morpho Blue WMON/USDC market on Monad, found across every page of markets. Nothing else
  /// stands in for it: the presets supply WMON and borrow USDC.
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

  // MARK: - Any action

  /// An action to build, which the user can edit before anything is built.
  private struct BorrowPreset {
    let title: String
    let integrationId: String
    let action: YieldXyzBorrowActionType
    let args: YieldXyzBorrowActionArguments
  }

  /// The collateral the presets supply and the loan they borrow: the amounts the React Native and Web
  /// SDKs were validated with.
  private static let borrowPresetCollateral = "30"
  private static let borrowPresetLoan = "0.2"

  /// Hashes of transactions already broadcast, by transaction id, kept across launches as the SDK
  /// recommends: saved from the `confirming` progress event and from a failure that carries one, and
  /// passed to the next sign, so resuming the action (even after the app was closed mid-confirmation)
  /// submits the hash instead of broadcasting the transaction again. An action's hashes are dropped
  /// once it succeeds.
  nonisolated private static let borrowBroadcastHashesKey = "borrow.broadcastHashes"

  /// Transactions whose user operation was processed and did not succeed. Portal remembers their
  /// idempotency key and would refuse to send them again, so an action that still lists one is signed
  /// without idempotency keys.
  nonisolated private static let borrowUnkeyedTransactionsKey = "borrow.unkeyedTransactions"

  nonisolated private static var savedBorrowBroadcastHashes: [String: String] {
    UserDefaults.standard.dictionary(forKey: borrowBroadcastHashesKey) as? [String: String] ?? [:]
  }

  nonisolated private static func saveBorrowBroadcastHash(_ hash: String?, forTransaction transactionId: String) {
    var hashes = savedBorrowBroadcastHashes
    hashes[transactionId] = hash
    UserDefaults.standard.set(hashes, forKey: borrowBroadcastHashesKey)
  }

  nonisolated private static var unkeyedBorrowTransactions: Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: borrowUnkeyedTransactionsKey) ?? [])
  }

  nonisolated private static func markBorrowTransactionUnkeyed(_ transactionId: String) {
    UserDefaults.standard.set(Array(unkeyedBorrowTransactions.union([transactionId])), forKey: borrowUnkeyedTransactionsKey)
  }

  nonisolated private static func forgetBorrowTransactions(of action: YieldXyzBorrowAction) {
    let ids = Set(action.transactions.map(\.id))
    UserDefaults.standard.set(savedBorrowBroadcastHashes.filter { !ids.contains($0.key) }, forKey: borrowBroadcastHashesKey)
    UserDefaults.standard.set(Array(unkeyedBorrowTransactions.subtracting(ids)), forKey: borrowUnkeyedTransactionsKey)
  }

  /// Builds any action from a preset or your own JSON. Nothing is signed until you review the built
  /// action and confirm.
  @IBAction func borrowAnyAction(_: Any) {
    runBorrow("Any Action (load presets)") { [weak self] portal in
      guard let self else {
        return "Cancelled"
      }
      let presets = try await self.borrowPresets(portal)
      await self.chooseBorrowPreset(presets)
      return "Loaded \(presets.count) presets; choose one."
    }
  }

  /// Loads an action by id to review and sign it, for example to resume one that failed part-way.
  @IBAction func borrowLoadAction(_: Any) {
    let alert = UIAlertController(
      title: "Load a Borrow action",
      message: "Enter an action id to review and sign it, or to resume it after a failure.",
      preferredStyle: .alert
    )
    alert.addTextField { field in
      field.placeholder = "actionId"
      Self.configureBorrowCodeField(field)
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Load", style: .default) { [weak self, weak alert] _ in
      let actionId = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      self?.runBorrow("Load Action") { [weak self] portal in
        let action = try await portal.borrow.yieldxyz.getAction(actionId: actionId).data
        await self?.reviewAndSignBorrow(action)
        return "Loaded \(action.action) \(action.id) [\(action.status)]; nothing signed yet."
      }
    })
    present(alert, animated: true)
  }

  /// Continues the last failed execution from the action it reported, which keeps the signing order,
  /// with the hashes already broadcast. After an app restart, load the action by id instead.
  @IBAction func borrowResumeLastFailure(_: Any) {
    guard let action = BorrowExampleState.lastFailedAction else {
      showStatusView(message: "No failed execution to resume. To resume one from an earlier launch, load its action by id.")
      return
    }
    reviewAndSignBorrow(action)
  }

  /// Presets for each step of the lifecycle on the WMON/USDC market, filtered to the actions the
  /// integration offers, plus the actions Yield.xyz offers on the wallet's balances (`pendingActions`,
  /// with their args pre-filled). The withdraw preset takes the collateral the wallet supplied.
  private func borrowPresets(_ portal: PortalProtocol) async throws -> [BorrowPreset] {
    let borrow = portal.borrow.yieldxyz
    let address = try await Self.borrowWalletAddress(portal)
    let market = try await borrowMarket(portal)
    let offered = try? await borrow.getIntegration(integrationId: borrowIntegrationId).data.actions.map(\.id)
    let position = try? await borrow.getPositions(params: YieldXyzBorrowGetPositionsParams(
      integrationId: borrowIntegrationId,
      network: borrowNetwork,
      address: address
    )).data

    let collateral = market.collateralTokens.first?.token.symbol ?? "collateral"
    let loan = market.loanToken.symbol
    let supplied = position?.supplyBalances.first { $0.marketId == market.id && Double($0.balance) ?? 0 > 0 }?.balance
    let minLoan = market.minLoan.map { " (min loan \($0))" } ?? ""
    var presets = [
      BorrowPreset(
        title: "Supply \(Self.borrowPresetCollateral) \(collateral) as collateral (wraps MON if needed)",
        integrationId: borrowIntegrationId,
        action: .supply,
        args: YieldXyzBorrowActionArguments(marketId: market.id, amount: Self.borrowPresetCollateral)
      ),
      BorrowPreset(
        title: "Borrow \(Self.borrowPresetLoan) \(loan)\(minLoan)",
        integrationId: borrowIntegrationId,
        action: .borrow,
        args: YieldXyzBorrowActionArguments(marketId: market.id, amount: Self.borrowPresetLoan)
      ),
      BorrowPreset(
        title: "Supply \(Self.borrowPresetCollateral) \(collateral) and borrow \(Self.borrowPresetLoan) \(loan) in one action",
        integrationId: borrowIntegrationId,
        action: .supplyAndBorrow,
        args: YieldXyzBorrowActionArguments(marketId: market.id, collateralAmount: Self.borrowPresetCollateral, borrowAmount: Self.borrowPresetLoan)
      ),
      BorrowPreset(
        title: "Repay all \(loan) debt (avoids interest dust)",
        integrationId: borrowIntegrationId,
        action: .repay,
        args: YieldXyzBorrowActionArguments(marketId: market.id, repayAll: true)
      ),
      BorrowPreset(
        title: "Withdraw \(supplied ?? Self.borrowPresetCollateral) \(collateral) collateral (repay first)",
        integrationId: borrowIntegrationId,
        action: .withdraw,
        args: YieldXyzBorrowActionArguments(marketId: market.id, amount: supplied ?? Self.borrowPresetCollateral)
      )
    ]
    if let offered {
      presets = presets.filter { offered.contains($0.action) }
    }
    let balances = (position?.supplyBalances.map { ($0.tokenSymbol, $0.pendingActions) } ?? [])
      + (position?.debtBalances.map { ($0.tokenSymbol, $0.pendingActions) } ?? [])
    presets += balances.flatMap { symbol, pendingActions in
      pendingActions.map { pending in
        BorrowPreset(title: "\(pending.label) (\(symbol))", integrationId: borrowIntegrationId, action: pending.type, args: pending.args)
      }
    }
    presets.append(BorrowPreset(
      title: "Custom: type an integration, an action and its args",
      integrationId: borrowIntegrationId,
      action: YieldXyzBorrowActionType(rawValue: ""),
      args: YieldXyzBorrowActionArguments(marketId: market.id)
    ))
    return presets
  }

  @MainActor
  private func chooseBorrowPreset(_ presets: [BorrowPreset]) {
    let sheet = UIAlertController(title: "Build a Borrow action", message: "You can edit the action and its args next.", preferredStyle: .actionSheet)
    for preset in presets {
      sheet.addAction(UIAlertAction(title: preset.title, style: .default) { [weak self] _ in
        self?.editBorrowPreset(preset)
      })
    }
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    sheet.popoverPresentationController?.sourceView = view
    present(sheet, animated: true)
  }

  @MainActor
  private func editBorrowPreset(_ preset: BorrowPreset) {
    let alert = UIAlertController(
      title: preset.title,
      message: "Edit the integration, the action and its args (JSON). Building signs nothing: you review the action before signing.",
      preferredStyle: .alert
    )
    alert.addTextField { field in
      field.text = preset.integrationId
      field.placeholder = "integrationId, for example morpho-blue-borrow"
      Self.configureBorrowCodeField(field)
    }
    alert.addTextField { field in
      field.text = preset.action.rawValue
      field.placeholder = "action, for example supply"
      Self.configureBorrowCodeField(field)
    }
    alert.addTextField { field in
      field.text = Self.borrowJSON(preset.args)
      field.placeholder = "args as JSON, for example {\"marketId\":\"...\"}"
      Self.configureBorrowCodeField(field)
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Build", style: .default) { [weak self, weak alert] _ in
      let fields = alert?.textFields ?? []
      let value = { (index: Int) -> String in fields.indices.contains(index) ? fields[index].text ?? "" : "" }
      self?.buildBorrowAction(
        integrationId: value(0).trimmingCharacters(in: .whitespacesAndNewlines),
        action: value(1).trimmingCharacters(in: .whitespacesAndNewlines),
        argsJSON: value(2)
      )
    })
    present(alert, animated: true)
  }

  /// JSON is typed, not prose: no smart quotes, autocorrection or capitalization.
  private static func configureBorrowCodeField(_ field: UITextField) {
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.smartQuotesType = .no
    field.smartDashesType = .no
    field.spellCheckingType = .no
  }

  private static func borrowJSON(_ args: YieldXyzBorrowActionArguments) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(args)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  /// The keys `YieldXyzBorrowActionArguments` encodes. Keep in step with its properties.
  private static let borrowArgKeys: Set<String> = [
    "marketId", "amount", "amountRaw", "repayAll", "tokenAddress", "collateralTokenAddress",
    "collateralAmount", "collateralAmountRaw", "borrowAmount", "targetLtv"
  ]

  /// Decodes the typed args, refusing a key the SDK does not know. The decoder would drop it, so a
  /// typo like `colateralAmount` would build the action without that field instead of getting
  /// connect-api's 400.
  private static func decodeBorrowArgs(_ json: String) throws -> YieldXyzBorrowActionArguments {
    let data = Data(json.utf8)
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw PortalExampleBorrowError.invalidInput("The args must be a JSON object with a marketId.")
    }
    let unknown = Set(object.keys).subtracting(borrowArgKeys).sorted()
    guard unknown.isEmpty else {
      throw PortalExampleBorrowError.invalidInput("Unknown args key(s): \(unknown.joined(separator: ", ")).")
    }
    do {
      return try JSONDecoder().decode(YieldXyzBorrowActionArguments.self, from: data)
    } catch {
      throw PortalExampleBorrowError.invalidInput("The args must be a JSON object with a marketId: \(error.localizedDescription)")
    }
  }

  private func buildBorrowAction(integrationId: String, action: String, argsJSON: String) {
    runBorrow("Build \(action.isEmpty ? "action" : action)") { [weak self] portal in
      guard !integrationId.isEmpty else {
        throw PortalExampleBorrowError.invalidInput("Enter an integration, for example morpho-blue-borrow.")
      }
      guard !action.isEmpty else {
        throw PortalExampleBorrowError.invalidInput("Enter an action, for example supply.")
      }
      let args = try Self.decodeBorrowArgs(argsJSON)
      let address = try await Self.borrowWalletAddress(portal)
      let built = try await portal.borrow.yieldxyz.createAction(params: YieldXyzBorrowCreateActionParams(
        integrationId: integrationId,
        action: YieldXyzBorrowActionType(rawValue: action),
        address: address,
        args: args
      )).data
      await self?.reviewAndSignBorrow(built)
      return "Built \(built.action) \(built.id) with \(built.transactions.count) transaction(s); nothing signed yet."
    }
  }

  /// The predicted position worth showing before the user signs. A health factor at or below 1 can be
  /// liquidated; a nil one is unknown, never safe.
  private static func describeBorrowImpact(_ metadata: YieldXyzBorrowActionMetadata?) -> String {
    guard let metadata else {
      return "Yield.xyz returned no predicted position for this action."
    }
    let fields: [(String, String?)] = [
      ("Health factor", "\(metadata.currentHealthFactor ?? "unknown") → \(metadata.predictedHealthFactor ?? "unknown")"),
      ("LTV", "\(metadata.currentLtv) → \(metadata.predictedLtv) (liquidation at \(metadata.liquidationThreshold))"),
      ("Total supplied", "$\(metadata.predictedTotalSupplyUsd)"),
      ("Total debt", "$\(metadata.predictedTotalDebtUsd)"),
      ("Origination fee", metadata.originationFeeAmount),
      ("Fee", metadata.feeAmount),
      ("Principal received", metadata.effectivePrincipalAmount),
      ("Collateral posted", metadata.effectiveCollateralAmount)
    ]
    return fields.compactMap { label, value in value.map { "\(label): \($0)" } }.joined(separator: "\n")
  }

  /// Shows what the action will do and signs nothing unless the user confirms.
  @MainActor
  private func reviewAndSignBorrow(_ action: YieldXyzBorrowAction) {
    let hashes = Self.savedBorrowBroadcastHashes
    let transactions = action.transactions.enumerated().map { index, transaction in
      let resumed = hashes[transaction.id] == nil ? "" : " (broadcast; resumed, not signed again)"
      return "\(index + 1). \(transaction.type.rawValue) on \(transaction.network) \(transaction.status.rawValue)\(resumed)"
    }.joined(separator: "\n")
    // What is signed, so a tester can check the built amounts and market against what they meant.
    let args = action.rawArguments.map(Self.borrowJSON) ?? "not returned"
    let alert = UIAlertController(
      title: "Sign and submit \(action.action.rawValue)?",
      message: "Args: \(args)\n\n\(Self.describeBorrowImpact(action.metadata))\n\nStep \(action.currentStep)/\(action.totalSteps), transactions:\n\(transactions)\n\n"
        + "Action \(action.id) on \(action.integrationId) [\(action.status.rawValue)]. This signs with your Portal wallet on mainnet and moves real funds.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
      self?.logger.info("⏹ [Borrow \(action.action.rawValue)] Cancelled; nothing was signed. Action \(action.id) can be loaded later.")
      self?.showStatusView(message: "Cancelled; nothing was signed. Action \(action.id) can be loaded later.")
    })
    alert.addAction(UIAlertAction(title: "Sign & submit", style: .destructive) { [weak self] _ in
      self?.signBorrowAction(action)
    })
    present(alert, animated: true)
  }

  /// Signs and submits each transaction in order, then tracks the action through its steps, passing
  /// the hashes already broadcast. A transaction whose user operation failed is signed again without
  /// idempotency keys: Portal remembers its key and would refuse to send it again.
  private func signBorrowAction(_ action: YieldXyzBorrowAction) {
    let logger = logger
    let name = action.action.rawValue
    runBorrow("Sign and Submit \(name)") { portal in
      let recorder = BorrowProgressRecorder()
      let unkeyed = Self.unkeyedBorrowTransactions
      do {
        let result = try await portal.borrow.yieldxyz.signAndSubmitAction(action, options: YieldXyzBorrowExecuteOptions(
          onProgress: { progress in
            recorder.record(progress)
            logger.info("⏳ [Borrow \(name)] \(progress.step.rawValue) \(progress.transactionId ?? "") \(progress.broadcastHash ?? "") \(progress.actionStatus?.rawValue ?? "")")
            // The transaction is on-chain from here: save its hash before waiting for it.
            if progress.step == .confirming, let transactionId = progress.transactionId, let hash = progress.broadcastHash {
              Self.saveBorrowBroadcastHash(hash, forTransaction: transactionId)
            }
          },
          useIdempotencyKeys: !action.transactions.contains { unkeyed.contains($0.id) },
          broadcastHashes: Self.savedBorrowBroadcastHashes
        ))
        BorrowExampleState.lastFailedAction = nil
        if result.status == .success {
          Self.forgetBorrowTransactions(of: result.action)
        }
        let hashes = result.transactions.map(\.transactionHash).joined(separator: ", ")
        return "Action \(result.actionId) ended \(result.status) after \(result.transactions.count) transaction(s): \(hashes)"
      } catch {
        let failure = error as? YieldXyzBorrowExecutionError
        if let failure, let transactionId = failure.transactionId {
          if failure.reason == .userOperationFailed {
            // Its user operation was processed and did not succeed: sign it again rather than resume it.
            Self.saveBorrowBroadcastHash(nil, forTransaction: transactionId)
            Self.markBorrowTransactionUnkeyed(transactionId)
          } else if let broadcastHash = failure.broadcastHash {
            Self.saveBorrowBroadcastHash(broadcastHash, forTransaction: transactionId)
          }
        }
        BorrowExampleState.lastFailedAction = failure?.action ?? recorder.recordedStepAction ?? action
        throw error
      }
    }
  }
}

private enum PortalExampleBorrowError: LocalizedError {
  case noEvmAddress
  case noMarket
  case invalidInput(String)

  var errorDescription: String? {
    switch self {
    case .noEvmAddress:
      return "The wallet has no EVM address."
    case .noMarket:
      return "The Morpho Blue WMON/USDC market is not listed on Monad."
    case let .invalidInput(message):
      return message
    }
  }
}

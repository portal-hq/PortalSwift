//
//  AggViewController.swift
//  SPM Example
//
//  Created by Ahmed Ragab
//
//  Agg prediction-markets testing, mirroring Android's `AggActivity`. Paper sections simulate
//  trades. Live sections use the real Agg account: Deposit and Withdraw move real funds (mainnet,
//  also on staging). Run Connect, then List Events to pick the outcome the other tests use.
//

import os.log
import PortalSwift
import UIKit

@available(iOS 16.0, *)
final class AggViewController: UIViewController {
  private let portal: PortalProtocol
  private let logger = Logger()

  private let stackView = UIStackView()
  private let resultView = UITextView()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private var buttons: [UIButton] = []

  /// The outcome List Events picked, and its venue, for the tests that need one.
  private var outcomeId: String?
  private var outcomeVenue: AggVenue?
  /// The last tradable paper quote, for Paper Fill + Poll.
  private var quoteId: String?
  /// The outcome and shares the last Buy got, for Sell.
  private var bought: (outcomeId: String, shares: String)?

  private var agg: AggProtocol {
    portal.predictionMarkets.agg
  }

  init(portal: PortalProtocol) {
    self.portal = portal
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Agg Prediction Markets"
    view.backgroundColor = .systemBackground
    navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
      self?.dismiss(animated: true)
    })
    layout()
    buildSections()
  }

  // MARK: - Layout

  private func layout() {
    let scrollView = UIScrollView()
    stackView.axis = .vertical
    stackView.spacing = 8
    resultView.isEditable = false
    resultView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    resultView.backgroundColor = .secondarySystemBackground
    resultView.text = "Results show here."
    activityIndicator.hidesWhenStopped = true

    [scrollView, resultView, activityIndicator].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview($0)
    }
    stackView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stackView)

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: resultView.topAnchor, constant: -8),

      stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
      stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

      resultView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      resultView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      resultView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
      resultView.heightAnchor.constraint(equalToConstant: 180),

      activityIndicator.centerXAnchor.constraint(equalTo: resultView.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: resultView.centerYAnchor)
    ])
  }

  private func addLabel(_ text: String, font: UIFont) {
    let label = UILabel()
    label.text = text
    label.font = font
    label.numberOfLines = 0
    stackView.addArrangedSubview(label)
  }

  private func addButton(_ title: String, live: Bool = false, _ action: @escaping () async throws -> String) {
    var configuration = UIButton.Configuration.filled()
    configuration.title = title
    configuration.baseBackgroundColor = live ? UIColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1) : .black
    let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
      self?.run(title, action)
    })
    buttons.append(button)
    stackView.addArrangedSubview(button)
  }

  private func buildSections() {
    addLabel(
      "Paper sections simulate trades. Live sections use the real Agg account: Deposit and Withdraw move real funds (mainnet, also on staging). Run Connect, then List Events to pick the outcome the other tests use.",
      font: .preferredFont(forTextStyle: .footnote)
    )

    addLabel("API methods", font: .preferredFont(forTextStyle: .title3))
    addLabel("Link", font: .preferredFont(forTextStyle: .headline))
    addButton("Connect", connect)
    addButton("Get Link", getLink)
    addButton("Unlink", deleteLink)
    addLabel("Discovery and market data", font: .preferredFont(forTextStyle: .headline))
    addButton("List Events (picks an open outcome)", listEvents)
    addButton("Search", search)
    addButton("Get Outcome Orderbook", getOutcomeOrderbook)
    addButton("Get Chart Bars", getChartBars)
    addLabel("Account", font: .preferredFont(forTextStyle: .headline))
    addButton("Get User", getUser)
    addButton("Get Deposit Addresses", getDepositAddresses)
    addButton("Get Balances", getBalances)
    addLabel("Paper", font: .preferredFont(forTextStyle: .headline))
    addButton("Quote $10 Buy", paperQuote)
    addButton("Fill + Poll", paperFill)
    addButton("List Positions", listPositions)
    addButton("List Orders", listOrders)
    addLabel("Live", font: .preferredFont(forTextStyle: .headline))
    addButton("Preview Withdrawal", previewWithdrawal)

    addLabel("Helpers", font: .preferredFont(forTextStyle: .title3))
    addLabel("Link", font: .preferredFont(forTextStyle: .headline))
    addButton("Is Connected", isConnected)
    addLabel("Paper", font: .preferredFont(forTextStyle: .headline))
    addButton("Buy $10", buy)
    addButton("Sell Bought Shares", sell)
    addLabel("Live (mainnet, real funds)", font: .preferredFont(forTextStyle: .headline))
    addButton("Deposit 2 USDC on Base", live: true, deposit)
    addButton("Withdraw 1.5 USDC to Base", live: true, withdraw)
    addButton("Redeem All", live: true, redeemAll)
    addButton("Place + Cancel Limit Order", live: true, limitOrderRoundTrip)
    addLabel("If its cancel fails, use Cancel Open Limit Orders.", font: .preferredFont(forTextStyle: .footnote))
    addButton("Cancel Open Limit Orders", live: true, cancelOpenLimitOrders)
  }

  // MARK: - Running

  /// Runs `operation` with the buttons disabled and shows its outcome. One test at a time: two
  /// running at once would race on the picked outcome and quote.
  private func run(_ name: String, _ operation: @escaping () async throws -> String) {
    buttons.forEach { $0.isEnabled = false }
    activityIndicator.startAnimating()
    resultView.text = "\(name)…"

    Task { @MainActor in
      defer {
        buttons.forEach { $0.isEnabled = true }
        activityIndicator.stopAnimating()
      }
      do {
        logger.info("📝 [Agg \(name)] Starting...")
        let summary = try await operation()
        logger.info("✅ [Agg \(name)] \(summary)")
        resultView.text = "✅ \(name)\n\(summary)"
      } catch {
        let detail = Self.describe(error)
        logger.error("❌ [Agg \(name)] \(detail)")
        resultView.text = "❌ \(name)\n\(detail)"
      }
    }
  }

  /// A readable description of an Agg failure: the HTTP status, Portal's `id`, Agg's `code` and
  /// fields, and the trace id to send with a report.
  private static func describe(_ error: Error) -> String {
    if let aggError = error as? AggError {
      if case let .orderOutcomeUnknown(_, _, _, underlyingError) = aggError {
        return "\(aggError.localizedDescription)\n\(describe(underlyingError))"
      }
      if case let .withdrawalOutcomeUnknown(_, _, _, underlyingError) = aggError {
        return "\(aggError.localizedDescription)\n\(describe(underlyingError))"
      }
      if case let .depositOutcomeUnknown(_, _, _, _, _, underlyingError) = aggError {
        return "\(aggError.localizedDescription)\n\(describe(underlyingError))"
      }
      if case let .reconnectFailed(underlyingError) = aggError {
        return "\(aggError.localizedDescription)\n\(describe(underlyingError))"
      }
      return aggError.localizedDescription
    }
    guard let apiError = AggApiError.from(error) else {
      let traceId = (error as? AggRequestError).map { " (trace id \($0.traceId))" } ?? ""
      return "\(error.localizedDescription)\(traceId)"
    }
    let parts: [String?] = [
      apiError.status.map { "HTTP \($0)" } ?? "no HTTP status",
      apiError.id,
      apiError.details?.code,
      apiError.message,
      apiError.details.flatMap { $0.fields.isEmpty ? nil : "fields: \($0.fields.joined(separator: ", "))" },
      apiError.isLinkRequired ? "run Connect again" : nil,
      apiError.traceId.map { "trace id \($0)" }
    ]
    return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
  }

  /// A raw integer amount in `decimals`-decimal units, as a plain decimal.
  private static func formatRaw(_ raw: String?, decimals: Int) -> String {
    guard let raw, let value = Decimal(string: raw) else {
      return "-"
    }
    var scaled = value
    for _ in 0 ..< decimals {
      scaled /= 10
    }
    return NSDecimalNumber(decimal: scaled).stringValue
  }

  private struct ExampleError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
      self.errorDescription = message
    }
  }

  private func requireOutcome() throws -> String {
    guard let outcomeId else {
      throw ExampleError("Run List Events first to pick an outcome.")
    }
    return outcomeId
  }

  private func logProgress(_ name: String) -> AggProgressHandler {
    let logger = logger
    return { progress in
      logger.info("  ⏳ [Agg \(name)] \(progress.step.rawValue) \(Self.detail(of: progress))")
    }
  }

  /// The most useful field of a progress event: the fill's steps, the withdrawal status, the
  /// transaction hash, or the deposit's idempotency key.
  private static func detail(of progress: AggProgress) -> String {
    if let order = progress.order {
      return "\(order.overallState): " + order.steps.map(\.label).joined(separator: " → ")
    }
    if let withdrawal = progress.withdrawal {
      return "\(withdrawal.status)"
    }
    if let txHash = progress.txHash {
      return txHash
    }
    return progress.idempotencyKey.map { "idempotency key \($0)" } ?? ""
  }

  // MARK: - API methods

  private func connect() async throws -> String {
    let link = try await agg.connect()
    return "Linked \(link.linkedAddress) on \(link.linkedChainId) (Agg user \(link.aggUserId))"
  }

  private func getLink() async throws -> String {
    switch try await agg.getLink().data {
    case let .linked(link):
      return "Linked \(link.linkedAddress) since \(link.linkedAt)"
    case .notLinked:
      return "Not linked"
    }
  }

  private func deleteLink() async throws -> String {
    let unlink = try await agg.deleteLink().data
    return "Unlinked (linked: \(unlink.linked))"
  }

  /// Picks the first outcome of an open market in the busiest open events: an open event can hold
  /// closed markets, and thin markets quote as untradable (stale order books, minimum order sizes
  /// above $1).
  private func listEvents() async throws -> String {
    let events = try await agg.listEvents(params: AggListEventsParams(status: .open, sortBy: .volume24hr, sortDir: .desc, limit: 10)).data.data
    for event in events {
      if let market = event.venueMarkets?.first(where: { $0.status == .open && !$0.venueMarketOutcomes.isEmpty }),
         let outcome = market.venueMarketOutcomes.first
      {
        outcomeId = outcome.id
        outcomeVenue = market.venue
        return "\(events.count) open events. Picked \"\(outcome.label)\" of \"\(market.question)\" (\(market.venue)) in \"\(event.title)\": \(outcome.id)"
      }
    }
    outcomeId = nil
    outcomeVenue = nil
    return "\(events.count) open events, none with an open market."
  }

  private func search() async throws -> String {
    switch try await agg.search(params: AggSearchParams(q: "election", type: .events, limit: 5)).data {
    case let .events(results):
      return "\(results.data.count) events: " + results.data.map(\.title).joined(separator: ", ")
    case let .markets(results):
      return "\(results.data.count) markets: " + results.data.map(\.question).joined(separator: ", ")
    }
  }

  private func getOutcomeOrderbook() async throws -> String {
    let book = try await agg.getOutcomeOrderbook(outcomeId: requireOutcome(), depth: 5).data
    let bid = book.orderbook.bids.first.map { "\($0.price)" } ?? "-"
    let ask = book.orderbook.asks.first.map { "\($0.price)" } ?? "-"
    return "\(book.venue): best bid \(bid), best ask \(ask), midpoint \(book.midpoint.map { "\($0)" } ?? "-")"
  }

  private func getChartBars() async throws -> String {
    let now = Int(Date().timeIntervalSince1970 * 1000)
    let bars = try await agg.getChartBars(params: AggChartParams(
      venueMarketOutcomeId: requireOutcome(),
      to: now,
      from: now - 7 * 86_400_000,
      resolution: .oneHour
    )).data
    let close = bars.data.last.map { "\($0.c)" } ?? "-"
    return "\(bars.data.count) hourly bars (state \(bars.meta.state?.rawValue ?? "-")); last close \(close)"
  }

  private func getUser() async throws -> String {
    let user = try await agg.getUser().data
    let wallets = user.wallets.map { "\($0.chain) \($0.address)" }.joined(separator: ", ")
    return "Agg user \(user.id); wallets: \(wallets); location blocked: \(user.isLocationBlocked)"
  }

  /// Polls every 2 seconds for up to a minute: Agg creates a new user's deposit wallets after the
  /// first request.
  private func getDepositAddresses() async throws -> String {
    for attempt in 1 ... 30 {
      if case let .ready(addresses) = try await agg.getDepositAddresses().data {
        let chains = addresses.supportedChains.map { chain in
          "\(chain.name): " + chain.tokens.map(\.symbol).joined(separator: ", ")
        }
        return "EVM \(addresses.evmAddress)\nSolana \(addresses.svmAddress)\n" + chains.joined(separator: "\n")
      }
      logger.info("  ⏳ [Agg Get Deposit Addresses] Not ready yet (read \(attempt)), Agg is creating the wallets...")
      try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    throw ExampleError("Deposit addresses were not ready after 60 seconds.")
  }

  private func getBalances() async throws -> String {
    func describe(_ balances: AggBalances) -> String {
      let cash = balances.cash.map { "\(Self.formatRaw($0.availableRaw ?? $0.totalRaw, decimals: $0.decimals)) \($0.tokenSymbol)" }
      return cash.isEmpty ? "none" : cash.joined(separator: ", ")
    }
    let live = try await agg.getBalances().data
    let paper = try await agg.getBalances(sync: nil, mode: .paper).data
    return "Live: \(describe(live))\nPaper: \(describe(paper))"
  }

  /// A $10 paper buy of the picked outcome: only `status: ok` with no warnings can be filled. Venue
  /// minimums are usually in shares, so $1 falls under them unless the price is very low.
  private func paperQuote() async throws -> String {
    let quote = try await agg.createQuote(request: AggQuoteRequest(
      outcomeId: requireOutcome(),
      side: .buy,
      amount: "10",
      slippageBps: 100,
      mode: .paper
    )).data
    let warnings = quote.warnings ?? []
    guard quote.status == .ok, warnings.isEmpty else {
      quoteId = nil
      let reasons = warnings.map { "\($0.venue): \($0.reason)" }.joined(separator: ", ")
      let venues = (quote.venueSoloQuotes ?? []).map { solo in
        "\n\(solo.venue): \(solo.status)"
          + (solo.unavailableReason.map { ", unavailable: \($0)" } ?? "")
          + (solo.quoteFailure.map { ", failure: \($0.code)" } ?? "")
          + (solo.avgPrice.map { ", avg price \($0)" } ?? "")
      }
      return "Quote \(quote.quoteId) is not tradable: status \(quote.status); \(reasons)" + venues.joined()
    }
    quoteId = quote.quoteId
    return "Quote \(quote.quoteId): \(quote.totalFilled) shares for \(quote.totalCostIncFees.map { "\($0)" } ?? "-") USD, expires \(quote.expiresAt). Fill it with Fill + Poll."
  }

  /// Fills the last paper quote, then polls it until terminal, waiting `pollAfterMs` between reads.
  private func paperFill() async throws -> String {
    guard let quoteId else {
      throw ExampleError("Run Quote $10 Buy first (quotes expire in about 45 seconds).")
    }
    _ = try await agg.createOrder(request: AggOrderRequest(quoteId: quoteId, mode: .paper))
    self.quoteId = nil
    for _ in 0 ..< 60 {
      let status = try await agg.getOrder(quoteId: quoteId, mode: .paper).data
      if status.terminal {
        return "\(status.overallState): " + status.steps.map(\.label).joined(separator: " → ")
      }
      let waitMs = min(max(status.pollAfterMs ?? 1000, 250), 10000)
      try await Task.sleep(nanoseconds: UInt64(waitMs) * 1_000_000)
    }
    throw ExampleError("Quote \(quoteId) was not terminal after 60 reads.")
  }

  private func listPositions() async throws -> String {
    let positions = try await agg.listPositions(params: AggListPositionsParams(mode: .paper)).data.data
    let lines = positions.flatMap { position in
      position.venueMarket.venueMarketOutcomes.map { outcome in
        "\n\(position.venueMarket.question) (\(outcome.label)): \(outcome.totalSize) shares, \(position.redeemStatus)"
      }
    }
    return "\(positions.count) paper positions" + lines.joined()
  }

  private func listOrders() async throws -> String {
    let orders = try await agg.listOrders(params: AggListOrdersParams(mode: .paper, limit: 5)).data.data
    return "\(orders.count) recent paper orders: " + orders.map { "\($0.venue) \($0.side) \($0.status)" }.joined(separator: ", ")
  }

  /// Previews withdrawing 1.5 USDC to Base; a preview dispatches nothing.
  private func previewWithdrawal() async throws -> String {
    let preview = try await agg.previewWithdrawal(request: AggWithdrawalRequest(
      tokenSymbol: .usdc,
      destinationChainId: "eip155:8453",
      amountRaw: "1500000"
    )).data
    guard preview.pricingStatus == .quoted else {
      return "Not withdrawable (\(preview.pricingStatus)): \(preview.unviableReason ?? "no reason given")"
    }
    return "Would receive \(Self.formatRaw(preview.receiveAmountRaw, decimals: 6)) USDC on Base (fee \(Self.formatRaw(preview.feeRaw, decimals: 6)))"
  }

  // MARK: - Helpers

  private func isConnected() async throws -> String {
    try await agg.isConnected() ? "Connected" : "Not connected: run Connect"
  }

  /// A $10 paper buy of the picked outcome with the buy helper: quote, fill and poll in one call.
  private func buy() async throws -> String {
    let outcomeId = try requireOutcome()
    let trade = try await agg.buy(params: AggBuyParams(
      outcomeId: outcomeId,
      amount: "10",
      slippageBps: 100,
      mode: .paper,
      onProgress: logProgress("Buy")
    ))
    let sharesRaw = trade.status.orders.compactMap { $0.actualSharesRaw.flatMap { Decimal(string: $0) } }.reduce(0, +)
    let shares = Self.formatRaw(NSDecimalNumber(decimal: sharesRaw).stringValue, decimals: 6)
    bought = (outcomeId, shares)
    return "\(trade.status.overallState): \(shares) shares for \(trade.quote.totalCostIncFees.map { "\($0)" } ?? "-") USD. Sell them with Sell Bought Shares."
  }

  /// Sells, in paper mode, the shares the last Buy got.
  private func sell() async throws -> String {
    guard let bought else {
      throw ExampleError("Run Buy first.")
    }
    let trade = try await agg.sell(params: AggSellParams(
      outcomeId: bought.outcomeId,
      shares: bought.shares,
      slippageBps: 100,
      mode: .paper,
      onProgress: logProgress("Sell")
    ))
    self.bought = nil
    return "\(trade.status.overallState): sold \(bought.shares) shares, about \(trade.quote.estimatedNetProceeds.map { "\($0)" } ?? "-") USD back"
  }

  /// Redeems every eligible live position; with nothing resolved in the user's favour it redeems
  /// nothing.
  private func redeemAll() async throws -> String {
    let results = try await agg.redeemAll().flatMap(\.results)
    guard !results.isEmpty else {
      return "No eligible positions to redeem"
    }
    return results.map { "\($0.venueMarketOutcomeId): \($0.status)" }.joined(separator: "\n")
  }

  /// Sends 2 USDC on Base from the Portal wallet to the Agg deposit address: real funds.
  private func deposit() async throws -> String {
    let deposit = try await agg.deposit(params: AggDepositParams(
      chainId: "eip155:8453",
      token: "USDC",
      amount: "2",
      onProgress: logProgress("Deposit")
    ))
    return "Sent 2 \(deposit.token.symbol) to \(deposit.depositAddress): \(deposit.txHash). Get Balances shows it once it confirms."
  }

  /// Withdraws 1.5 USDC to the Portal wallet on Base: real funds.
  private func withdraw() async throws -> String {
    let withdrawal = try await agg.withdraw(params: AggWithdrawParams(
      amount: "1.5",
      tokenSymbol: .usdc,
      destinationChainId: "eip155:8453",
      onProgress: logProgress("Withdraw")
    ))
    let txHashes = withdrawal.legs.compactMap(\.txHash).joined(separator: ", ")
    return "Withdrawal \(withdrawal.status): \(Self.formatRaw(withdrawal.completedAmountRaw, decimals: 6)) USDC, tx \(txHashes.isEmpty ? "-" : txHashes)"
  }

  /// Places a live post-only buy of 5 shares at $0.01 on the picked outcome, far below the market
  /// so it rests instead of trading, then cancels it. It reserves about $0.05 plus fees from the
  /// live Agg balance until the cancel; if the cancel fails, the message names the order still open.
  private func limitOrderRoundTrip() async throws -> String {
    let outcomeId = try requireOutcome()
    guard let venue = outcomeVenue else {
      throw ExampleError("Run List Events first to pick an outcome.")
    }
    let order = try await agg.placeLimitOrder(params: AggPlaceLimitOrderParams(
      venue: venue,
      venueMarketOutcomeId: outcomeId,
      side: .buy,
      price: "0.01",
      shares: "5",
      postOnly: true
    ))
    logger.info("  ⏳ [Agg Place + Cancel Limit Order] Placed \(order.orderId) on \(venue) (\(order.status)), cancelling...")
    // Venues can reject an order a couple of seconds after accepting it; give it time to rest first.
    try await Task.sleep(nanoseconds: 2_000_000_000)
    do {
      let cancel = try await agg.cancelOrder(request: AggCancelOrderRequest(orderId: order.orderId)).data
      return "Placed \(order.orderId) on \(venue) (\(order.status), reserved \(Self.formatRaw(order.reservedCostRaw, decimals: 6)) USD), then \(cancel.status)"
    } catch {
      throw ExampleError("Order \(order.orderId) on \(venue) may still be open, cancel failed: \(Self.describe(error))")
    }
  }

  /// Cancels every live limit order still open on this Agg account, for when Place + Cancel Limit
  /// Order could not cancel its order. Reads the latest 50 limit orders.
  private func cancelOpenLimitOrders() async throws -> String {
    let openStatuses: Set<AggOrderStatus> = [.pending, .signing, .pendingBridge, .submitting, .submitted, .open, .partiallyFilledOpen]
    let open = try await agg.listOrders(params: AggListOrdersParams(orderType: .limit, limit: 50)).data.data
      .filter { openStatuses.contains($0.status) }
    guard !open.isEmpty else {
      return "No open limit orders"
    }
    var lines: [String] = []
    for order in open {
      do {
        let cancel = try await agg.cancelOrder(request: AggCancelOrderRequest(orderId: order.id)).data
        lines.append("\(order.id) on \(order.venue): \(cancel.status)")
      } catch {
        lines.append("\(order.id) on \(order.venue): cancel failed, \(Self.describe(error))")
      }
    }
    return lines.joined(separator: "\n")
  }
}

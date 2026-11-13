//
//  MeldViewController.swift
//  SPM Example
//
//  Created by Ahmed Ragab
//
//  Meld ramps testing, mirroring Android's `MeldActivity`. Every button calls one SDK method with the
//  sandbox defaults (US, USD, 100, card, crypto on-ramp); Buy Flow chains them into a purchase. The
//  example covers EVM currencies only: the widget sends the crypto to the wallet's EVM address.
//

import os.log
import PortalSwift
import SafariServices
import UIKit

@available(iOS 16.0, *)
final class MeldViewController: UIViewController {
  private enum Defaults {
    static let countryCode = "US"
    static let fiatCurrency = "USD"
    static let cryptoCurrency = "ETH"
    static let amount = 100.0
    static let paymentMethodType = "CREDIT_DEBIT_CARD"
    static let category = MeldCategory.cryptoOnramp
  }

  private let portal: PortalProtocol
  private let logger = Logger()

  private let stackView = UIStackView()
  private let cryptoField = UITextField()
  private let resultView = UITextView()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private var buttons: [UIButton] = []

  /// The crypto currencies, fetched once, to find the chain of the one to buy.
  private var cryptoCurrencies: [MeldNetworkPartnerCurrency]?
  /// The provider of the last quote, for Create Widget Session.
  private var quotedProvider: String?
  /// The last widget session, for Open Widget and the transaction reads.
  private var session: MeldWidgetSession?
  /// The session whose widget was opened. Its URL is single-use, so it is not opened again.
  private var openedSessionId: String?
  /// The last transaction id a search returned, for Get Transaction.
  private var transactionId: String?

  private var meld: MeldProtocol {
    portal.ramps.meld
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
    title = "Meld Ramps"
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

    for item in [scrollView, resultView, activityIndicator] {
      item.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(item)
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

  /// `action` is unbound (`MeldViewController.buyFlow`, not `buyFlow`): a bound method would hold
  /// the screen strongly from its own button and it would never be released.
  private func addButton(_ title: String, _ action: @escaping (MeldViewController) -> () async throws -> String) {
    var configuration = UIButton.Configuration.filled()
    configuration.title = title
    configuration.baseBackgroundColor = .black
    let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
      guard let self else {
        return
      }
      run(title, action(self))
    })
    buttons.append(button)
    stackView.addArrangedSubview(button)
  }

  private func buildSections() {
    addLabel(
      "Sandbox defaults: \(Defaults.countryCode), \(Defaults.amount.formatted()) \(Defaults.fiatCurrency), card. The crypto must be an EVM currency: it is sent to this wallet's EVM address.",
      font: .preferredFont(forTextStyle: .footnote)
    )
    cryptoField.text = Defaults.cryptoCurrency
    cryptoField.placeholder = "Crypto currency code, e.g. ETH or USDC_BASE"
    cryptoField.borderStyle = .roundedRect
    cryptoField.autocapitalizationType = .allCharacters
    cryptoField.autocorrectionType = .no
    stackView.addArrangedSubview(cryptoField)

    addLabel("Guided", font: .preferredFont(forTextStyle: .title3))
    addButton("Buy Flow (defaults → quote → widget → open)", MeldViewController.buyFlow)

    addLabel("Customers", font: .preferredFont(forTextStyle: .title3))
    addButton("Create Customer", MeldViewController.createCustomer)
    addButton("Search Customer", MeldViewController.searchCustomer)

    addLabel("Retail", font: .preferredFont(forTextStyle: .title3))
    addButton("Get Quote", MeldViewController.getQuote)
    addButton("Create Widget Session", MeldViewController.createWidgetSession)
    addButton("Open Widget", MeldViewController.openWidget)
    addButton("Get Transaction by Session", MeldViewController.getTransactionBySession)
    addButton("Search Transactions", MeldViewController.searchTransactions)
    addButton("Get Transaction (from the search)", MeldViewController.getTransaction)

    addLabel("Network Partners", font: .preferredFont(forTextStyle: .title3))
    addButton("Countries", MeldViewController.getCountries)
    addButton("Crypto Currencies", MeldViewController.getCurrencies)
    addButton("Fiat Limits", MeldViewController.getFiatLimits)
    addButton("KYC Limits", MeldViewController.getKycLimits)
    addButton("Partners", MeldViewController.getPartners)
    addButton("Payment Methods", MeldViewController.getPaymentMethods)
    addButton("Routes", MeldViewController.getRoutes)
    addButton("Country Defaults", MeldViewController.getCountryDefaults)
  }

  // MARK: - Running

  private func run(_ name: String, _ operation: @escaping () async throws -> String) {
    view.endEditing(true)
    buttons.forEach { $0.isEnabled = false }
    activityIndicator.startAnimating()
    resultView.text = "\(name)…"

    Task { @MainActor in
      defer {
        buttons.forEach { $0.isEnabled = true }
        activityIndicator.stopAnimating()
      }
      do {
        logger.info("📝 [Meld \(name)] Starting...")
        let summary = try await operation()
        logger.info("✅ [Meld \(name)] \(summary)")
        resultView.text = "✅ \(name)\n\(summary)"
      } catch {
        let detail = Self.describe(error)
        logger.error("❌ [Meld \(name)] \(detail)")
        resultView.text = "❌ \(name)\n\(detail)"
      }
    }
  }

  /// A readable description of a Meld failure: the HTTP status and message, the existing customer
  /// on a `409`, or where a response did not decode.
  private static func describe(_ error: Error) -> String {
    if let decodingError = error as? DecodingError {
      return "Could not decode the response: \(describe(decodingError))"
    }
    guard let apiError = MeldApiError.from(error) else {
      return error.localizedDescription
    }
    let parts: [String?] = [
      apiError.status.map { "HTTP \($0)" } ?? "no HTTP status",
      apiError.id,
      apiError.message,
      apiError.meldCustomerId.map { "existing customer: \($0)" }
    ]
    return parts.compactMap { $0 }.joined(separator: "\n")
  }

  private static func describe(_ error: DecodingError) -> String {
    let context: DecodingError.Context
    switch error {
    case let .typeMismatch(_, errorContext), let .valueNotFound(_, errorContext), let .keyNotFound(_, errorContext),
         let .dataCorrupted(errorContext):
      context = errorContext
    @unknown default:
      return error.localizedDescription
    }
    let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
    return "\(path.isEmpty ? "<root>" : path): \(context.debugDescription)"
  }

  private struct ExampleError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
      self.errorDescription = message
    }
  }

  // MARK: - Wallet

  private var cryptoCurrency: String {
    let text = cryptoField.text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
    return text.isEmpty ? Defaults.cryptoCurrency : text
  }

  /// The wallet address to receive `cryptoCurrency`. Only EVM currencies are supported: Meld's
  /// `chainId` is a plain number (Solana's is numeric too), so a currency counts as EVM when its
  /// `chainId` is all digits and its `contract` is a `0x` address.
  private func walletAddress() async throws -> String {
    if cryptoCurrencies == nil {
      cryptoCurrencies = try await meld.getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams(
        category: Defaults.category,
        country: Defaults.countryCode,
        type: .crypto
      )).data.currencies
    }
    let code = cryptoCurrency
    guard let currency = cryptoCurrencies?.first(where: { $0.currencyCode == code }) else {
      throw ExampleError("\(code) is not a crypto currency Meld offers in \(Defaults.countryCode).")
    }
    guard let chainId = currency.chainId, !chainId.isEmpty, chainId.allSatisfy(\.isNumber),
          let contract = currency.contract, contract.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) != nil
    else {
      throw ExampleError("\(code) is on \(currency.chainCode ?? "an unknown chain"). This example covers EVM currencies only.")
    }
    guard let address = await portal.getAddress("eip155:\(chainId)"), !address.isEmpty else {
      throw ExampleError("This wallet has no EVM address yet. Create a wallet first.")
    }
    return address
  }

  // MARK: - Guided

  private func buyFlow() async throws -> String {
    let defaults = try await meld.getNetworkPartnerCountryDefaults(countryCode: Defaults.countryCode, category: Defaults.category).data
    let fiatCurrency = defaults?.currencyCode ?? Defaults.fiatCurrency
    let paymentMethod = defaults?.paymentMethods.first ?? Defaults.paymentMethodType
    let address = try await walletAddress()

    let quotes = try await meld.getRetailQuote(request: MeldGetRetailQuoteRequest(
      countryCode: Defaults.countryCode,
      sourceCurrencyCode: fiatCurrency,
      destinationCurrencyCode: cryptoCurrency,
      sourceAmount: Defaults.amount,
      walletAddress: address,
      paymentMethodType: paymentMethod
    )).data
    guard let quote = quotes.quotes.first else {
      throw ExampleError("No quote. \(quotes.error ?? quotes.message ?? "")")
    }
    quotedProvider = quote.serviceProvider

    let created = try await meld.createRetailWidget(request: MeldCreateRetailWidgetRequest(
      sessionType: .buy,
      sessionData: MeldSessionData(
        countryCode: Defaults.countryCode,
        serviceProvider: quote.serviceProvider,
        sourceCurrencyCode: fiatCurrency,
        sourceAmount: Self.amountString(Defaults.amount),
        destinationCurrencyCode: cryptoCurrency,
        walletAddress: address,
        paymentMethodType: paymentMethod,
        lockFields: [.sourceAmount]
      )
    )).data
    session = created
    try presentWidget(created)
    return "Quote: \(quote.destinationAmount) \(quote.destinationCurrencyCode) from \(quote.serviceProvider) (fee \(quote.totalFee) \(quote.sourceCurrencyCode))\n"
      + "Session \(created.id) opened. Close the browser when done to read the transaction."
  }

  // MARK: - Customers

  private func createCustomer() async throws -> String {
    let customer = try await meld.createCustomer(request: MeldCreateCustomerRequest(type: .individual)).data
    return "Customer \(customer.id) (\(customer.status?.rawValue ?? "no status"))"
  }

  private func searchCustomer() async throws -> String {
    let result = try await meld.searchCustomer().data
    guard let customer = result.customers.first else {
      return "No customer yet."
    }
    return "Customer \(customer.id), \(customer.type?.rawValue ?? "no type"), \(customer.status?.rawValue ?? "no status")"
  }

  // MARK: - Retail

  private func getQuote() async throws -> String {
    let address = try await walletAddress()
    let result = try await meld.getRetailQuote(request: MeldGetRetailQuoteRequest(
      countryCode: Defaults.countryCode,
      sourceCurrencyCode: Defaults.fiatCurrency,
      destinationCurrencyCode: cryptoCurrency,
      sourceAmount: Defaults.amount,
      walletAddress: address,
      paymentMethodType: Defaults.paymentMethodType
    )).data
    quotedProvider = result.quotes.first?.serviceProvider
    guard !result.quotes.isEmpty else {
      return "No quote. \(result.error ?? result.message ?? "")"
    }
    return result.quotes
      .map { "\($0.serviceProvider): \($0.destinationAmount) \($0.destinationCurrencyCode), fee \($0.totalFee) \($0.sourceCurrencyCode)" }
      .joined(separator: "\n")
  }

  private func createWidgetSession() async throws -> String {
    guard let provider = quotedProvider else {
      throw ExampleError("Run Get Quote first to pick a provider.")
    }
    let address = try await walletAddress()
    let created = try await meld.createRetailWidget(request: MeldCreateRetailWidgetRequest(
      sessionType: .buy,
      sessionData: MeldSessionData(
        countryCode: Defaults.countryCode,
        serviceProvider: provider,
        sourceCurrencyCode: Defaults.fiatCurrency,
        sourceAmount: Self.amountString(Defaults.amount),
        destinationCurrencyCode: cryptoCurrency,
        walletAddress: address,
        paymentMethodType: Defaults.paymentMethodType,
        lockFields: [.sourceAmount]
      )
    )).data
    session = created
    return "Session \(created.id) at \(provider). Tap Open Widget."
  }

  private func openWidget() async throws -> String {
    guard let session else {
      throw ExampleError("Run Create Widget Session first.")
    }
    try presentWidget(session)
    return "Session \(session.id) opened. Close the browser when done to read the transaction."
  }

  private func getTransactionBySession() async throws -> String {
    guard let session else {
      throw ExampleError("Run Create Widget Session first.")
    }
    return try await readTransaction(sessionId: session.id)
  }

  private func searchTransactions() async throws -> String {
    let result = try await meld.searchRetailTransactions(params: MeldSearchRetailTransactionsParams(limit: 10)).data
    transactionId = result.transactions.first?.id
    guard !result.transactions.isEmpty else {
      return "No transactions yet."
    }
    return "\(result.count) of \(result.totalCount):\n" + result.transactions.map(Self.summary).joined(separator: "\n")
  }

  private func getTransaction() async throws -> String {
    guard let transactionId else {
      throw ExampleError("Run Search Transactions first.")
    }
    return try Self.summary(await meld.getRetailTransaction(transactionId: transactionId).data.transaction)
  }

  // MARK: - Network Partners

  private func getCountries() async throws -> String {
    let countries = try await meld.getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams(category: Defaults.category)).data.countries
    return "\(countries.count) countries: " + countries.prefix(20).map(\.countryCode).joined(separator: ", ")
  }

  private func getCurrencies() async throws -> String {
    let currencies = try await meld.getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams(
      category: Defaults.category,
      country: Defaults.countryCode,
      type: .crypto
    )).data.currencies
    cryptoCurrencies = currencies
    return "\(currencies.count) crypto currencies, e.g.\n" + currencies.prefix(10)
      .map { "\($0.currencyCode) (\($0.chainCode ?? "?"), chain \($0.chainId ?? "none"))" }
      .joined(separator: "\n")
  }

  private func getFiatLimits() async throws -> String {
    let limits = try await meld.getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams(
      category: Defaults.category,
      country: Defaults.countryCode,
      currencyCode: Defaults.fiatCurrency
    )).data.fiatLimits
    return limits.isEmpty ? "No fiat limits." : limits.map { "\($0.provider) \($0.paymentMethod): \($0.min)–\($0.max) \($0.currencyCode)" }.joined(separator: "\n")
  }

  private func getKycLimits() async throws -> String {
    let limits = try await meld.getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams(
      category: Defaults.category,
      country: Defaults.countryCode
    )).data.kycLimits
    return limits.isEmpty ? "No KYC limits." : limits.map { limit in
      let levels = [limit.level1, limit.level2, limit.level3].map { $0.map { "\($0)" } ?? "–" }.joined(separator: " / ")
      return "\(limit.provider) \(limit.limitType): \(levels) \(limit.currencyCode)"
    }.joined(separator: "\n")
  }

  private func getPartners() async throws -> String {
    let partners = try await meld.getNetworkPartners(params: MeldGetNetworkPartnersParams(category: Defaults.category, country: Defaults.countryCode)).data
    return partners.isEmpty ? "No partners." : partners.map { "\($0.name) (\($0.serviceProvider)): \($0.status)" }.joined(separator: "\n")
  }

  private func getPaymentMethods() async throws -> String {
    let methods = try await meld.getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams(
      category: Defaults.category,
      country: Defaults.countryCode,
      currencyCode: Defaults.fiatCurrency
    )).data
    return methods.isEmpty ? "No payment methods." : methods.map { "\($0.method) (\($0.type))" }.joined(separator: "\n")
  }

  private func getRoutes() async throws -> String {
    let routes = try await meld.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
      category: Defaults.category,
      countryCode: Defaults.countryCode,
      sourceCurrencyCode: Defaults.fiatCurrency,
      destinationCurrencyCode: cryptoCurrency
    )).data
    return routes.isEmpty ? "No routes." : routes.map { route in
      "\(route.partner) \(route.source)→\(route.destination): "
        + route.paymentMethods.map { "\($0.name) \($0.limits.map { "\($0.min)–\($0.max)" } ?? "")" }.joined(separator: ", ")
    }.joined(separator: "\n")
  }

  private func getCountryDefaults() async throws -> String {
    guard let defaults = try await meld.getNetworkPartnerCountryDefaults(countryCode: Defaults.countryCode, category: Defaults.category).data else {
      return "No defaults for \(Defaults.countryCode)."
    }
    return "\(defaults.countryCode) \(defaults.category): \(defaults.currencyCode), " + defaults.paymentMethods.joined(separator: ", ")
  }

  // MARK: - Widget

  private func presentWidget(_ session: MeldWidgetSession) throws {
    guard openedSessionId != session.id else {
      throw ExampleError("This session's widget was already opened, and its URL works once. Create a new widget session.")
    }
    guard let url = URL(string: session.widgetUrl), url.scheme == "https" else {
      throw ExampleError("The widget URL is not an https URL.")
    }
    openedSessionId = session.id
    let safari = SFSafariViewController(url: url)
    safari.delegate = self
    present(safari, animated: true)
  }

  /// The session's transaction. Meld creates it once the user starts paying, so a `404` before
  /// that is expected.
  private func readTransaction(sessionId: String) async throws -> String {
    do {
      return try Self.summary(await meld.getRetailTransactionBySession(sessionId: sessionId).data.transaction)
    } catch where MeldApiError.from(error)?.status == 404 {
      return "No transaction for this session yet. Try again after paying in the widget."
    }
  }

  // MARK: - Formatting

  /// A plain decimal such as `100` or `99.5`, never with an exponent (`String(1e16)` is `1e+16`).
  private static func amountString(_ amount: Double) -> String {
    Decimal(string: "\(amount)", locale: Locale(identifier: "en_US_POSIX")).map { "\($0)" } ?? "\(amount)"
  }

  private static func summary(_ transaction: MeldTransaction) -> String {
    let amounts = [
      transaction.sourceAmount.map { "\($0) \(transaction.sourceCurrencyCode ?? "")" },
      transaction.destinationAmount.map { "\($0) \(transaction.destinationCurrencyCode ?? "")" }
    ].compactMap { $0 }.joined(separator: " → ")
    let hash = transaction.cryptoDetails?.blockchainTransactionId.map { "\ntx \($0)" } ?? ""
    return "\(transaction.id) \(transaction.status) \(transaction.transactionType) at \(transaction.serviceProvider)\n\(amounts)\(hash)"
  }
}

// MARK: - SFSafariViewControllerDelegate

@available(iOS 16.0, *)
extension MeldViewController: SFSafariViewControllerDelegate {
  /// The user closed the widget: read the session's transaction once.
  func safariViewControllerDidFinish(_: SFSafariViewController) {
    guard let session else {
      return
    }
    run("Transaction after the widget") { [weak self] in
      guard let self else {
        return "Screen closed."
      }
      return try await readTransaction(sessionId: session.id)
    }
  }
}

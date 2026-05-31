//
//  ViewController+Noah.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Noah on/off-ramp testing functionality
//

import AnyCodable
import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  // MARK: - Noah Initiate KYC

  @IBAction func noahInitiateKyc(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Initiate KYC] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Noah Initiate KYC] Starting KYC flow...")

        let request = NoahInitiateKycRequest(
          returnUrl: "https://example.com/kyc-return",
          fiatOptions: [NoahFiatOption(fiatCurrencyCode: "USD")],
          customerType: .individual
        )

        let response = try await portal.ramps.noah.initiateKyc(request: request)

        let hostedUrl = response.data.hostedUrl
        logger.info("✅ [Noah Initiate KYC] Hosted URL: \(hostedUrl)")
        showStatusView(message: "\(successStatus) KYC URL ready: \(hostedUrl)")
        presentNoahKycAlert(hostedUrl: hostedUrl)
      } catch {
        logger.error("❌ [Noah Initiate KYC] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) KYC failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah KYC Alert

  private func presentNoahKycAlert(hostedUrl: String) {
    let alert = UIAlertController(
      title: "KYC Initiated",
      message: "Noah KYC was initiated successfully. Open the verification page to continue.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Open in Safari", style: .default) { _ in
      guard let url = URL(string: hostedUrl), UIApplication.shared.canOpenURL(url) else {
        self.logger.error("❌ [Noah Initiate KYC] Invalid hosted URL: \(hostedUrl)")
        return
      }
      UIApplication.shared.open(url)
    })

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    present(alert, animated: true)
  }

  // MARK: - Noah Initiate Payin

  @IBAction func noahInitiatePayin(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Initiate Payin] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let request = NoahInitiatePayinRequest(
          fiatCurrency: "USD",
          cryptoCurrency: "USDC_TEST",
          network: NoahNetwork.ethereum,
          destinationAddress: "0x0000000000000000000000000000000000000000"
        )

        let response = try await portal.ramps.noah.initiatePayin(request: request)

        let data = response.data
        logger.info("✅ [Noah Initiate Payin] Payin ID: \(data.payinId), bank: \(data.bankDetails.bankName ?? "n/a")")
        showStatusView(message: "\(successStatus) Payin started: \(data.payinId)")
      } catch {
        logger.error("❌ [Noah Initiate Payin] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Payin failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Simulate Payin

  @IBAction func noahSimulatePayin(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Simulate Payin] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        // Simulate requires a real Noah-issued payment method ID. Noah only
        // mints one when a payin (bank-deposit workflow) is initiated, so kick
        // one off first and reuse its bank details. A placeholder ID makes Noah
        // respond with a 404 (ResourceNotFound, "read single fiat payment method").
        let payinRequest = NoahInitiatePayinRequest(
          fiatCurrency: "USD",
          cryptoCurrency: "USDC_TEST",
          network: NoahNetwork.ethereum,
          destinationAddress: "0x0000000000000000000000000000000000000000"
        )
        let payinResponse = try await portal.ramps.noah.initiatePayin(request: payinRequest)
        let paymentMethodId = payinResponse.data.bankDetails.paymentMethodId
        logger.info("ℹ️ [Noah Simulate Payin] Using payment method ID: \(paymentMethodId)")

        let request = NoahSimulatePayinRequest(
          paymentMethodId: paymentMethodId,
          fiatAmount: "100.00",
          fiatCurrency: "USD"
        )

        let response = try await portal.ramps.noah.simulatePayin(request: request)

        let data = response.data
        logger.info("✅ [Noah Simulate Payin] Fiat deposit ID: \(data.fiatDepositId)")
        showStatusView(message: "\(successStatus) Simulated deposit: \(data.fiatDepositId)")
      } catch {
        logger.error("❌ [Noah Simulate Payin] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Simulation failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Get Payment Methods

  @IBAction func noahGetPaymentMethods(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Get Payment Methods] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let response = try await portal.ramps.noah.getPaymentMethods()

        let data = response.data
        logger.info("✅ [Noah Get Payment Methods] Count: \(data.paymentMethods.count)")
        for pm in data.paymentMethods {
          logger.info("  • \(pm.paymentMethodCategory) — id: \(pm.id), country: \(pm.country)")
        }
        showStatusView(message: "\(successStatus) \(data.paymentMethods.count) payment methods")
      } catch {
        logger.error("❌ [Noah Get Payment Methods] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Payment methods failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Get Payout Countries

  @IBAction func noahGetPayoutCountries(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Get Payout Countries] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let response = try await portal.ramps.noah.getPayoutCountries()

        let data = response.data
        logger.info("✅ [Noah Get Payout Countries] \(data.countries.count) countries")
        for (country, currencies) in data.countries {
          logger.info("  • \(country): \(currencies.joined(separator: ", "))")
        }
        showStatusView(message: "\(successStatus) \(data.countries.count) countries supported")
      } catch {
        logger.error("❌ [Noah Get Payout Countries] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Countries failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Get Payout Channels

  @IBAction func noahGetPayoutChannels(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Get Payout Channels] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let request = NoahGetPayoutChannelsRequest(
          country: "US",
          cryptoCurrency: "USDC_TEST",
          fiatCurrency: "USD",
          fiatAmount: "100.00"
        )

        let response = try await portal.ramps.noah.getPayoutChannels(request: request)

        let data = response.data
        logger.info("✅ [Noah Get Payout Channels] \(data.items.count) channels")
        for channel in data.items {
          logger.info("  • \(channel.paymentMethodCategory)/\(channel.paymentMethodType) — id: \(channel.id), rate: \(channel.rate)")
        }
        showStatusView(message: "\(successStatus) \(data.items.count) channels available")
      } catch {
        logger.error("❌ [Noah Get Payout Channels] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Channels failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Get Payout Channel Form

  @IBAction func noahGetPayoutChannelForm(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Get Payout Channel Form] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        // The form endpoint requires a real channel ID. Fetch the available
        // payout channels first and use the first one returned, otherwise Noah
        // responds with a 404 (ResourceNotFound) for unknown channel IDs.
        let channelsRequest = NoahGetPayoutChannelsRequest(
          country: "US",
          cryptoCurrency: "USDC_TEST",
          fiatCurrency: "USD",
          fiatAmount: "100.00"
        )
        let channelsResponse = try await portal.ramps.noah.getPayoutChannels(request: channelsRequest)

        guard let channelId = channelsResponse.data.items.first?.id else {
          logger.error("❌ [Noah Get Payout Channel Form] No payout channels available")
          showStatusView(message: "\(failureStatus) No payout channels available")
          return
        }

        logger.info("ℹ️ [Noah Get Payout Channel Form] Using channel ID: \(channelId)")
        let response = try await portal.ramps.noah.getPayoutChannelForm(channelId: channelId)

        let data = response.data
        logger.info("✅ [Noah Get Payout Channel Form] Schema present: \(data.formSchema != nil), content hash: \(data.formMetadata?.contentHash ?? "n/a")")
        showStatusView(message: "\(successStatus) Channel form loaded")
      } catch {
        logger.error("❌ [Noah Get Payout Channel Form] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Form failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Sample Payout Channel + Form

  /// Fetches the US/USDC_TEST/USD payout channels and returns a bank channel
  /// together with a form payload that satisfies its dynamic schema.
  ///
  /// Noah validates the supplied `form` against the selected channel's
  /// JSON-Schema. The US bank channels returned for USD require
  /// `AccountHolderName`, `AccountHolderAddress`, `BankDetails`, and
  /// `PaymentPurpose`. `AccountHolderName` is itself an object: an
  /// `AccountHolderType` plus a conditional `Name` (a `FirstName`/`LastName`
  /// object for individuals). We prefer a bank channel because its schema is
  /// known; other channels (e.g. cards) expect a different shape.
  private func noahSampleUsdPayoutChannelAndForm(
    portal: PortalProtocol
  ) async throws -> (channelId: String, form: [String: AnyCodable])? {
    let channelsRequest = NoahGetPayoutChannelsRequest(
      country: "US",
      cryptoCurrency: "USDC_TEST",
      fiatCurrency: "USD",
      fiatAmount: "100.00"
    )
    let channelsResponse = try await portal.ramps.noah.getPayoutChannels(request: channelsRequest)

    let bankChannel = channelsResponse.data.items.first { $0.paymentMethodCategory == "Bank" }
    guard let channel = bankChannel ?? channelsResponse.data.items.first else {
      return nil
    }

    var bankDetails: [String: Any] = [
      "AccountNumber": "12345678",
      "BankCode": "123456789"
    ]
    // BankAch channels additionally require an AccountType.
    if channel.paymentMethodType == "BankAch" {
      bankDetails["AccountType"] = "Checking"
    }

    let form: [String: AnyCodable] = [
      "AccountHolderName": AnyCodable([
        "AccountHolderType": "Individual",
        "Name": [
          "FirstName": "John",
          "LastName": "Doe"
        ]
      ] as [String: Any]),
      "AccountHolderAddress": AnyCodable([
        "Address": "123 Main Street",
        "City": "New York",
        "State": "NY",
        "PostalCode": "10001"
      ]),
      "BankDetails": AnyCodable(bankDetails),
      "PaymentPurpose": AnyCodable("Transfer to own account")
    ]

    return (channel.id, form)
  }

  // MARK: - Noah Get Payout Quote

  @IBAction func noahGetPayoutQuote(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Get Payout Quote] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        // The quote endpoint requires a real channel ID (Noah expects a 36-char
        // UUID) and validates the supplied form against the channel's dynamic
        // schema. Fetch a bank channel plus a matching sample form, otherwise
        // Noah rejects the request with a 400 validation error.
        guard let (channelId, form) = try await noahSampleUsdPayoutChannelAndForm(portal: portal) else {
          logger.error("❌ [Noah Get Payout Quote] No payout channels available")
          showStatusView(message: "\(failureStatus) No payout channels available")
          return
        }

        logger.info("ℹ️ [Noah Get Payout Quote] Using channel ID: \(channelId)")

        let request = NoahGetPayoutQuoteRequest(
          channelId: channelId,
          cryptoCurrency: "USDC_TEST",
          fiatAmount: "100.00",
          form: form,
          fiatCurrency: "USD"
        )

        let response = try await portal.ramps.noah.getPayoutQuote(request: request)

        let data = response.data
        logger.info("✅ [Noah Get Payout Quote] Payout ID: \(data.payoutId), fee: \(data.totalFee), crypto est.: \(data.cryptoAmountEstimate)")
        if let nextStep = data.nextStep {
          logger.info("  → Next form step: \(nextStep.stepId) (\(nextStep.stepType.rawValue))")
        }
        showStatusView(message: "\(successStatus) Quote: \(data.payoutId)")
      } catch {
        logger.error("❌ [Noah Get Payout Quote] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Quote failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Noah Initiate Payout

  @IBAction func noahInitiatePayout(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Noah Initiate Payout] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        // A payout must reference a real payoutId, which is issued by the quote
        // endpoint. Fetch a bank channel + matching form, request a quote, then
        // use the returned payoutId. Otherwise Noah responds with a 400
        // ("Payout not found") for an unknown payout.
        guard let (channelId, quoteForm) = try await noahSampleUsdPayoutChannelAndForm(portal: portal) else {
          logger.error("❌ [Noah Initiate Payout] No payout channels available")
          showStatusView(message: "\(failureStatus) No payout channels available")
          return
        }

        let quoteRequest = NoahGetPayoutQuoteRequest(
          channelId: channelId,
          cryptoCurrency: "USDC_TEST",
          fiatAmount: "100.00",
          form: quoteForm,
          fiatCurrency: "USD"
        )
        let quoteResponse = try await portal.ramps.noah.getPayoutQuote(request: quoteRequest)
        let payoutId = quoteResponse.data.payoutId
        logger.info("ℹ️ [Noah Initiate Payout] Using payout ID: \(payoutId)")

        // Noah requires the trigger's nonce/sourceAddress/expiry to match the
        // top-level request values, so compute them once and reuse them.
        let sourceAddress = "0x1111111111111111111111111111111111111111"
        let expiry = "2099-01-01T00:00:00Z"
        let nonce = UUID().uuidString

        let trigger = NoahSingleOnchainDepositSourceTriggerInput(
          conditions: [
            NoahSingleOnchainDepositSourceTriggerCondition(
              amountConditions: [
                NoahSingleOnchainDepositSourceTriggerAmountCondition(
                  comparisonOperator: .gteq,
                  value: "100"
                )
              ],
              network: NoahNetwork.ethereum
            )
          ],
          sourceAddress: sourceAddress,
          expiry: expiry,
          nonce: nonce
        )

        let request = NoahInitiatePayoutRequest(
          payoutId: payoutId,
          sourceAddress: sourceAddress,
          expiry: expiry,
          nonce: nonce,
          network: NoahNetwork.ethereum,
          trigger: trigger
        )

        let response = try await portal.ramps.noah.initiatePayout(request: request)

        let data = response.data
        logger.info("✅ [Noah Initiate Payout] Destination: \(data.destinationAddress ?? "n/a"), conditions: \(data.conditions?.count ?? 0)")
        showStatusView(message: "\(successStatus) Payout initiated")
      } catch {
        logger.error("❌ [Noah Initiate Payout] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Payout failed: \(error.localizedDescription)")
      }
    }
  }
}

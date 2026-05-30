//
//  ViewController+Noah.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Noah on/off-ramp testing functionality
//

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
      } catch {
        logger.error("❌ [Noah Initiate KYC] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) KYC failed: \(error.localizedDescription)")
      }
    }
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
          cryptoCurrency: "USDC",
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
        let request = NoahSimulatePayinRequest(
          paymentMethodId: "pm-sample",
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
          cryptoCurrency: "USDC",
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
        let channelId = "sample-channel-id"
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
        let request = NoahGetPayoutQuoteRequest(
          channelId: "sample-channel-id",
          cryptoCurrency: "USDC",
          fiatAmount: "100.00",
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
          sourceAddress: "0x1111111111111111111111111111111111111111",
          expiry: "2099-01-01T00:00:00Z",
          nonce: UUID().uuidString
        )

        let request = NoahInitiatePayoutRequest(
          payoutId: "sample-payout-id",
          sourceAddress: "0x1111111111111111111111111111111111111111",
          expiry: "2099-01-01T00:00:00Z",
          nonce: UUID().uuidString,
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

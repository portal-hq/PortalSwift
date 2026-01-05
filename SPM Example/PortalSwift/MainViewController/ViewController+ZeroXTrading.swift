//
//  ViewController+ZeroXTrading.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift
import UIKit

// MARK: - ZeroX Trading Extension

@available(iOS 16.0, *)
extension ViewController {
  // MARK: - ZeroX Complete Trading Flow

  @IBAction func handleZeroXTrading() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary,
            let SWAPS_API_KEY: String = infoDictionary["SWAPS_API_KEY"] as? String
      else {
        self.logger.error("ViewController.handleZeroXTrading() - ❌ Error: Do you have `SWAPS_API_KEY=$(SWAPS_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleZeroXTrading() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }

      let chainId = "eip155:1"

      Task {
        do {
          // Step 1: Get sources
          let sourcesResponse = try await portal.trading.zeroX.getSources(
            chainId: chainId,
            zeroXApiKey: SWAPS_API_KEY
          )
          self.logger.info("ViewController.handleZeroXTrading() - ✅ Got sources successfully: \(sourcesResponse.data.sources)")
        } catch {
          self.logger.error("ViewController.handleZeroXTrading() - ❌ Unable to get sources with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get sources with error: \(error)")
          self.stopLoading()
          return
        }

        // Step 2: Get quote
        let quoteRequest = ZeroXQuoteRequest(
          chainId: chainId,
          buyToken: "USDC",
          sellToken: "ETH",
          sellAmount: "100000000000000" // 0.0001 ETH
        )

          var quoteResponse: ZeroXQuoteResponse
          do {
            quoteResponse = try await portal.trading.zeroX.getQuote(
              request: quoteRequest,
              zeroXApiKey: SWAPS_API_KEY
            )
          self.logger.info("ViewController.handleZeroXTrading() - ✅ Got quote successfully:")
          self.logger.info("  Buy Amount: \(quoteResponse.data.quote.buyAmount)")
          self.logger.info("  Sell Amount: \(quoteResponse.data.quote.sellAmount)")
          if let price = quoteResponse.data.quote.price {
            self.logger.info("  Price: \(price)")
          }
        } catch {
          self.logger.error("ViewController.handleZeroXTrading() - ❌ Unable to get quote with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get quote with error: \(error)")
          self.stopLoading()
          return
        }

        // Step 3: Submit transaction
        let transaction = quoteResponse.data.quote.transaction
        let transactionDict: [String: Any] = [
          "data": transaction.data,
          "from": transaction.from,
          "gas": transaction.gas,
          "gasPrice": transaction.gasPrice,
          "to": transaction.to,
          "value": transaction.value
        ]

        do {
          let sendTransactionResponse = try await portal.request(
            chainId: chainId,
            method: .eth_sendTransaction,
            params: [transactionDict],
            options: nil
          )
          guard let transactionHash = sendTransactionResponse.result as? String else {
            throw PortalExampleAppError.invalidResponseTypeForRequest()
          }

          self.logger.info("ViewController.handleZeroXTrading() - ✅ Transaction submitted: \(transactionHash)")
          self.showStatusView(message: "\(self.successStatus) Transaction submitted: \(transactionHash)")
          self.stopLoading()
        } catch {
          self.logger.error("ViewController.handleZeroXTrading() - ❌ Unable to submit transaction with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to submit transaction with error: \(error)")
          self.stopLoading()
        }
      }
    } catch {
      self.logger.error("ViewController.handleZeroXTrading() - ❌ Error: \(error)")
      self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
      self.stopLoading()
    }
  }

  // MARK: - ZeroX Get Sources Only

  @IBAction func handleZeroXGetSources() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary,
            let SWAPS_API_KEY: String = infoDictionary["SWAPS_API_KEY"] as? String
      else {
        self.logger.error("ViewController.handleZeroXGetSources() - ❌ Error: Do you have `SWAPS_API_KEY=$(SWAPS_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleZeroXGetSources() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }

      let chainId = "eip155:1"

      Task {
        do {
          let sourcesResponse = try await portal.trading.zeroX.getSources(
            chainId: chainId,
            zeroXApiKey: SWAPS_API_KEY
          )
          self.logger.info("ViewController.handleZeroXGetSources() - ✅ Got sources: \(sourcesResponse.data.sources)")
          self.showStatusView(message: "\(self.successStatus) Got \(sourcesResponse.data.sources.count) sources")
          self.stopLoading()
        } catch {
          self.logger.error("ViewController.handleZeroXGetSources() - ❌ Error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
          self.stopLoading()
        }
      }
    } catch {
      self.logger.error("ViewController.handleZeroXGetSources() - ❌ Error: \(error)")
      self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
      self.stopLoading()
    }
  }

  // MARK: - ZeroX Get Quote Only

  @IBAction func handleZeroXGetQuote() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary,
            let SWAPS_API_KEY: String = infoDictionary["SWAPS_API_KEY"] as? String
      else {
        self.logger.error("ViewController.handleZeroXGetQuote() - ❌ Error: Do you have `SWAPS_API_KEY=$(SWAPS_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleZeroXGetQuote() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }

      let chainId = "eip155:1"

      Task {
        do {
          let quoteRequest = ZeroXQuoteRequest(
            chainId: chainId,
            buyToken: "USDC",
            sellToken: "ETH",
            sellAmount: "100000000000000" // 0.0001 ETH
          )

          let quoteResponse = try await portal.trading.zeroX.getQuote(
            request: quoteRequest,
            zeroXApiKey: SWAPS_API_KEY
          )

          self.logZeroXQuoteResponse(quoteResponse)
          self.showStatusView(message: "\(self.successStatus) Got quote! Buy: \(quoteResponse.data.quote.buyAmount)")
          self.stopLoading()
        } catch {
          self.logger.error("ViewController.handleZeroXGetQuote() - ❌ Error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
          self.stopLoading()
        }
      }
    } catch {
      self.logger.error("ViewController.handleZeroXGetQuote() - ❌ Error: \(error)")
      self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
      self.stopLoading()
    }
  }

  // MARK: - ZeroX Price Check

  @IBAction func handleZeroXPriceCheck() {
    do {
      guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary,
            let SWAPS_API_KEY: String = infoDictionary["SWAPS_API_KEY"] as? String
      else {
        self.logger.error("ViewController.handleZeroXPriceCheck() - ❌ Error: Do you have `SWAPS_API_KEY=$(SWAPS_API_KEY)` in your Secrets.xcconfig?")
        throw PortalExampleAppError.environmentNotSet()
      }

      self.startLoading()

      guard let portal else {
        self.logger.error("ViewController.handleZeroXPriceCheck() - ❌ Portal not initialized")
        throw PortalExampleAppError.portalNotInitialized()
      }

      let chainId = "eip155:1"

      Task {
        do {
          // Get price quote
          let priceRequest = ZeroXPriceRequest(
            chainId: chainId,
            buyToken: "USDC",
            sellToken: "USDT",
            sellAmount: "1000000000" // 1000 USDT (6 decimals)
          )

          let priceResponse = try await portal.trading.zeroX.getPrice(
            request: priceRequest,
            zeroXApiKey: SWAPS_API_KEY
          )

          // Log price response details
          self.logZeroXPriceResponse(priceResponse)

          self.showStatusView(message: "\(self.successStatus) Price check completed! Buy: \(priceResponse.data.price.buyAmount), Price: \(priceResponse.data.price.price ?? "N/A")")
          self.stopLoading()
        } catch {
          self.logger.error("ViewController.handleZeroXPriceCheck() - ❌ Unable to get price with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get price with error: \(error)")
          self.stopLoading()
        }
      }
    } catch {
      self.logger.error("ViewController.handleZeroXPriceCheck() - ❌ Error: \(error)")
      self.showStatusView(message: "\(self.failureStatus) Error: \(error)")
      self.stopLoading()
    }
  }

  // MARK: - ZeroX Helper Functions

  /// Logs ZeroX price response details
  private func logZeroXPriceResponse(_ response: ZeroXPriceResponse) {
    self.logger.info("ViewController - ✅ Got price:")
    self.logger.info("  Buy Amount: \(response.data.price.buyAmount)")
    self.logger.info("  Sell Amount: \(response.data.price.sellAmount)")
    if let price = response.data.price.price {
      self.logger.info("  Price: \(price)")
    }
    if let liquidityAvailable = response.data.price.liquidityAvailable {
      self.logger.info("  Liquidity Available: \(liquidityAvailable)")
    }

    if let fees = response.data.price.fees {
      self.logger.info("  Fees:")
      if let integratorFee = fees.integratorFee {
        self.logger.info("    Integrator Fee: \(integratorFee.amount ?? "N/A") \(integratorFee.token ?? "N/A")")
      }
      if let zeroExFee = fees.zeroExFee {
        self.logger.info("    ZeroEx Fee: \(zeroExFee.feeAmount ?? "N/A") \(zeroExFee.feeToken ?? "N/A")")
      }
      if let gasFee = fees.gasFee {
        self.logger.info("    Gas Fee: \(gasFee.amount ?? "N/A") \(gasFee.token ?? "N/A")")
      }
    }

    if let issues = response.data.price.issues {
      self.logger.warning("  Issues:")
      if let simulationIncomplete = issues.simulationIncomplete {
        self.logger.warning("    Simulation Incomplete: \(simulationIncomplete)")
      }
      if let invalidSources = issues.invalidSourcesPassed, !invalidSources.isEmpty {
        self.logger.warning("    Invalid Sources: \(invalidSources)")
      }
    }
  }

  /// Logs ZeroX quote response details
  private func logZeroXQuoteResponse(_ response: ZeroXQuoteResponse) {
    self.logger.info("ViewController - ✅ Got quote:")
    self.logger.info("  Buy Amount: \(response.data.quote.buyAmount)")
    self.logger.info("  Sell Amount: \(response.data.quote.sellAmount)")
    if let price = response.data.quote.price {
      self.logger.info("  Price: \(price)")
    }
    if let estimatedGas = response.data.quote.estimatedGas {
      self.logger.info("  Estimated Gas: \(estimatedGas)")
    }
    if let gasPrice = response.data.quote.gasPrice {
      self.logger.info("  Gas Price: \(gasPrice)")
    }
    if let cost = response.data.quote.cost {
      self.logger.info("  Cost: \(cost)")
    }
    if let liquidityAvailable = response.data.quote.liquidityAvailable {
      self.logger.info("  Liquidity Available: \(liquidityAvailable)")
    }
    if let minBuyAmount = response.data.quote.minBuyAmount {
      self.logger.info("  Min Buy Amount: \(minBuyAmount)")
    }

    self.logger.info("  Transaction:")
    self.logger.info("    To: \(response.data.quote.transaction.to)")
    self.logger.info("    From: \(response.data.quote.transaction.from)")
    self.logger.info("    Value: \(response.data.quote.transaction.value)")
    self.logger.info("    Gas: \(response.data.quote.transaction.gas)")

    if let issues = response.data.quote.issues {
      self.logger.warning("  Issues:")
      if let allowance = issues.allowance {
        self.logger.warning("    Allowance: actual=\(allowance.actual), spender=\(allowance.spender)")
      }
      if let balance = issues.balance {
        self.logger.warning("    Balance: actual=\(balance.actual), expected=\(balance.expected)")
      }
      if let simulationIncomplete = issues.simulationIncomplete, simulationIncomplete {
        self.logger.warning("    Simulation Incomplete: true")
      }
      if let invalidSources = issues.invalidSourcesPassed, !invalidSources.isEmpty {
        self.logger.warning("    Invalid Sources: \(invalidSources)")
      }
    }
  }
}

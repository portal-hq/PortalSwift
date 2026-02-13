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

// MARK: - 0x Trading Extension

@available(iOS 16.0, *)
extension ViewController {
  // MARK: - 0x Complete Trading Flow

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
          guard let data = sourcesResponse.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXTrading() - ✅ Got sources successfully: \(data.rawResponse.sources)")
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
          guard let data = quoteResponse.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("  Buy Amount: \(data.rawResponse.buyAmount)")
          self.logger.info("  Sell Amount: \(data.rawResponse.sellAmount)")
          if let buyToken = data.rawResponse.buyToken {
            self.logger.info("  Buy Token: \(buyToken)")
          }
          if let sellToken = data.rawResponse.sellToken {
            self.logger.info("  Sell Token: \(sellToken)")
          }
        } catch {
          self.logger.error("ViewController.handleZeroXTrading() - ❌ Unable to get quote with error: \(error)")
          self.showStatusView(message: "\(self.failureStatus) Unable to get quote with error: \(error)")
          self.stopLoading()
          return
        }

        // Step 3: Submit transaction
        guard let data = quoteResponse.data else {
          throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
        }
        let transaction = data.rawResponse.transaction
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

  // MARK: - 0x Get Sources Only

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
          // Test Case 1: getSources WITH explicit zeroXApiKey parameter (overrides Dashboard config)
          self.logger.info("ViewController.handleZeroXGetSources() - 📝 Test Case 1: getSources WITH explicit zeroXApiKey parameter (overrides Dashboard config)")
          let sourcesResponse1 = try await portal.trading.zeroX.getSources(
            chainId: chainId,
            zeroXApiKey: SWAPS_API_KEY
          )
          guard let data1 = sourcesResponse1.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXGetSources() - ✅ Test Case 1 Success: Got \(data1.rawResponse.sources.count) sources with explicit API key: \(data1.rawResponse.sources)")

          // Test Case 2: getSources WITHOUT zeroXApiKey parameter (uses Dashboard config)
          self.logger.info("ViewController.handleZeroXGetSources() - 📝 Test Case 2: getSources WITHOUT zeroXApiKey parameter (uses Dashboard config)")
          let sourcesResponse2 = try await portal.trading.zeroX.getSources(chainId: chainId)
          guard let data2 = sourcesResponse2.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXGetSources() - ✅ Test Case 2 Success: Got \(data2.rawResponse.sources.count) sources using Dashboard API key: \(data2.rawResponse.sources)")

          self.showStatusView(message: "\(self.successStatus) Test 1: \(data1.rawResponse.sources.count) sources (with API key) | Test 2: \(data2.rawResponse.sources.count) sources (Dashboard key)")
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

  // MARK: - 0x Get Quote Only

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

          // Test Case 1: getQuote WITH explicit zeroXApiKey parameter (overrides Dashboard config)
          self.logger.info("ViewController.handleZeroXGetQuote() - 📝 Test Case 1: getQuote WITH explicit zeroXApiKey parameter (overrides Dashboard config)")
          let quoteResponse1 = try await portal.trading.zeroX.getQuote(
            request: quoteRequest,
            zeroXApiKey: SWAPS_API_KEY
          )
          guard let data1 = quoteResponse1.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXGetQuote() - ✅ Test Case 1 Success: Got quote with explicit API key - Buy: \(data1.rawResponse.buyAmount)")
          self.logZeroXQuoteResponse(quoteResponse1)

          // Test Case 2: getQuote WITHOUT zeroXApiKey parameter (uses Dashboard config)
          self.logger.info("ViewController.handleZeroXGetQuote() - 📝 Test Case 2: getQuote WITHOUT zeroXApiKey parameter (uses Dashboard config)")
          let quoteResponse2 = try await portal.trading.zeroX.getQuote(request: quoteRequest)
          guard let data2 = quoteResponse2.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXGetQuote() - ✅ Test Case 2 Success: Got quote using Dashboard API key - Buy: \(data2.rawResponse.buyAmount)")
          self.logZeroXQuoteResponse(quoteResponse2)

          self.showStatusView(message: "\(self.successStatus) Test 1: Buy \(data1.rawResponse.buyAmount) (with API key) | Test 2: Buy \(data2.rawResponse.buyAmount) (Dashboard key)")
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

  // MARK: - 0x Price Check

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

          // Test Case 1: getPrice WITH explicit zeroXApiKey parameter (overrides Dashboard config)
          self.logger.info("ViewController.handleZeroXPriceCheck() - 📝 Test Case 1: getPrice WITH explicit zeroXApiKey parameter (overrides Dashboard config)")
          let priceResponse1 = try await portal.trading.zeroX.getPrice(
            request: priceRequest,
            zeroXApiKey: SWAPS_API_KEY
          )
          guard let data1 = priceResponse1.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXPriceCheck() - ✅ Test Case 1 Success: Got price with explicit API key - Buy: \(data1.rawResponse.buyAmount)")
          self.logZeroXPriceResponse(priceResponse1)

          // Test Case 2: getPrice WITHOUT zeroXApiKey parameter (uses Dashboard config)
          self.logger.info("ViewController.handleZeroXPriceCheck() - 📝 Test Case 2: getPrice WITHOUT zeroXApiKey parameter (uses Dashboard config)")
          let priceResponse2 = try await portal.trading.zeroX.getPrice(request: priceRequest)
          guard let data2 = priceResponse2.data else {
            throw NSError(domain: "ZeroXError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
          }
          self.logger.info("ViewController.handleZeroXPriceCheck() - ✅ Test Case 2 Success: Got price using Dashboard API key - Buy: \(data2.rawResponse.buyAmount)")
          self.logZeroXPriceResponse(priceResponse2)

          self.showStatusView(message: "\(self.successStatus) Test 1: Buy \(data1.rawResponse.buyAmount) (with API key) | Test 2: Buy \(data2.rawResponse.buyAmount) (Dashboard key)")
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

  // MARK: - 0x Helper Functions

  /// Logs 0x price response details
  private func logZeroXPriceResponse(_ response: ZeroXPriceResponse) {
    guard let data = response.data else {
      self.logger.warning("ViewController - ⚠️ No data in price response")
      if let error = response.error {
        self.logger.error("  Error: \(error)")
      }
      return
    }
    self.logger.info("ViewController - ✅ Got price:")
    self.logger.info("  Buy Amount: \(data.rawResponse.buyAmount)")
    self.logger.info("  Sell Amount: \(data.rawResponse.sellAmount)")
    if let buyToken = data.rawResponse.buyToken {
      self.logger.info("  Buy Token: \(buyToken)")
    }
    if let sellToken = data.rawResponse.sellToken {
      self.logger.info("  Sell Token: \(sellToken)")
    }
    if let totalNetworkFee = data.rawResponse.totalNetworkFee {
      self.logger.info("  Total Network Fee: \(totalNetworkFee)")
    }
    if let blockNumber = data.rawResponse.blockNumber {
      self.logger.info("  Block Number: \(blockNumber)")
    }
    if let gas = data.rawResponse.gas {
      self.logger.info("  Gas: \(gas)")
    }
    if let gasPrice = data.rawResponse.gasPrice {
      self.logger.info("  Gas Price: \(gasPrice)")
    }
    if let liquidityAvailable = data.rawResponse.liquidityAvailable {
      self.logger.info("  Liquidity Available: \(liquidityAvailable)")
    }

    if let fees = data.rawResponse.fees {
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

    if let issues = data.rawResponse.issues {
      self.logger.warning("  Issues:")
      if let simulationIncomplete = issues.simulationIncomplete {
        self.logger.warning("    Simulation Incomplete: \(simulationIncomplete)")
      }
      if let invalidSources = issues.invalidSourcesPassed, !invalidSources.isEmpty {
        self.logger.warning("    Invalid Sources: \(invalidSources)")
      }
    }
  }

  /// Logs 0x quote response details
  private func logZeroXQuoteResponse(_ response: ZeroXQuoteResponse) {
    guard let data = response.data else {
      self.logger.warning("ViewController - ⚠️ No data in quote response")
      if let error = response.error {
        self.logger.error("  Error: \(error)")
      }
      return
    }
    self.logger.info("ViewController - ✅ Got quote:")
    self.logger.info("  Buy Amount: \(data.rawResponse.buyAmount)")
    self.logger.info("  Sell Amount: \(data.rawResponse.sellAmount)")
    if let buyToken = data.rawResponse.buyToken {
      self.logger.info("  Buy Token: \(buyToken)")
    }
    if let sellToken = data.rawResponse.sellToken {
      self.logger.info("  Sell Token: \(sellToken)")
    }
    if let totalNetworkFee = data.rawResponse.totalNetworkFee {
      self.logger.info("  Total Network Fee: \(totalNetworkFee)")
    }
    if let blockNumber = data.rawResponse.blockNumber {
      self.logger.info("  Block Number: \(blockNumber)")
    }
    if let liquidityAvailable = data.rawResponse.liquidityAvailable {
      self.logger.info("  Liquidity Available: \(liquidityAvailable)")
    }
    if let minBuyAmount = data.rawResponse.minBuyAmount {
      self.logger.info("  Min Buy Amount: \(minBuyAmount)")
    }

    self.logger.info("  Transaction:")
    self.logger.info("    To: \(data.rawResponse.transaction.to)")
    self.logger.info("    From: \(data.rawResponse.transaction.from)")
    self.logger.info("    Value: \(data.rawResponse.transaction.value)")
    self.logger.info("    Gas: \(data.rawResponse.transaction.gas)")

    if let issues = data.rawResponse.issues {
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

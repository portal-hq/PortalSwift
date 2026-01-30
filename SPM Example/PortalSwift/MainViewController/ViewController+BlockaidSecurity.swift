//
//  ViewController+BlockaidSecurity.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Blockaid Security testing functionality
//

import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {

  // MARK: - Blockaid Scan EVM Transaction

  @IBAction func blockaidScanEVMTx(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Blockaid Scan EVM Tx] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Blockaid Scan EVM Tx] Starting scan...")

        // Use benign test data: simple transfer to WETH contract on Ethereum mainnet
        let transactionData = BlockaidScanEVMTransactionData(
          from: "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
          to: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
          data: "0x",
          value: "0x0"
        )

        let metadata = BlockaidScanEVMMetadata(domain: "https://app.uniswap.org")

        let request = BlockaidScanEVMRequest(
          chain: "eip155:1",
          metadata: metadata,
          data: transactionData,
          options: [.simulation, .validation],
          block: "21211118"
        )

        let response = try await portal.security.blockaid.scanEVMTx(request: request)

        logEVMResult(response)

        let resultType = response.data?.rawResponse.validation?.resultType ?? "Unknown"
        if resultType == "Malicious" {
          logger.info("⚠️ [Blockaid Scan EVM Tx] Transaction flagged as MALICIOUS")
        } else {
          logger.info("✅ [Blockaid Scan EVM Tx] Transaction appears safe: \(resultType)")
        }
        showStatusView(message: "\(successStatus) EVM Tx scan completed: \(resultType)")

      } catch {
        logger.error("❌ [Blockaid Scan EVM Tx] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) EVM Tx failed: \(error.localizedDescription)")
      }
    }
  }

  private func logEVMResult(_ response: BlockaidScanEVMResponse) {
    logger.info("📊 [Blockaid EVM Result]")

    if let rawResponse = response.data?.rawResponse {
      logger.info("  Chain: \(rawResponse.chain)")
      logger.info("  Block: \(rawResponse.block)")

      if let validation = rawResponse.validation {
        logger.info("  Validation Status: \(validation.status)")
        logger.info("  Result Type: \(validation.resultType)")
        if let reason = validation.reason {
          logger.info("  Reason: \(reason)")
        }
        if let description = validation.description {
          logger.info("  Description: \(description)")
        }
        if let features = validation.features {
          logger.info("  Features: \(features.count)")
          for feature in features {
            logger.info("    - [\(feature.type)] \(feature.featureId): \(feature.description)")
          }
        }
      }

      if let simulation = rawResponse.simulation {
        logger.info("  Simulation Status: \(simulation.status)")
        if let actions = simulation.transactionActions {
          logger.info("  Transaction Actions: \(actions.joined(separator: ", "))")
        }
      }
    }
  }

  // MARK: - Blockaid Scan Solana Transaction

  @IBAction func blockaidScanSolanaTx(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Blockaid Scan Solana Tx] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Blockaid Scan Solana Tx] Starting scan...")

        let transactions = [
          "vxBNpvao9QJmLKXUThbbjRnxm3ufu4Wku97kHd5a67FDjSqeHwcPrBKTjAHp4ECr61eWwoxvUEVTuuWX65P9bCNDJrTJpX64vjdtpHA8cogA4C92Ubj813wUUA8Ey4Bvcrdj5c1bSTCnwoE8HeFYiyioRLNZTpShx8zkyzXaxkpUvPVRN26363bGvJDNSJt8bihmwAPxfrH7kSV9BvAuhRWsiuUAN4GZzyAiptknHZ1xjzrKAHz68UNJpWnYkaUThye6r3iULZUcp7baBaGAtnUmAdDMGG1UpBusWLF"
        ]

        let metadata = BlockaidScanSolanaMetadata(url: "https://phantom.app")

        let request = BlockaidScanSolanaRequest(
          accountAddress: "86xCnPeV69n6t3DnyGvkKobf9FdN2H9oiVDdaMpo2MMY",
          transactions: transactions,
          metadata: metadata,
          encoding: .base58,
          chain: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
          options: [.simulation, .validation],
          method: "signAndSendTransaction"
        )

        let response = try await portal.security.blockaid.scanSolanaTx(request: request)

        logSolanaResult(response)

        let resultType = response.data?.rawResponse.result?.validation?.resultType ?? "Unknown"
        if resultType == "Malicious" {
          logger.info("⚠️ [Blockaid Scan Solana Tx] Transaction flagged as MALICIOUS")
        } else {
          logger.info("✅ [Blockaid Scan Solana Tx] Transaction appears safe: \(resultType)")
        }
        showStatusView(message: "\(successStatus) Solana Tx scan completed: \(resultType)")

      } catch {
        logger.error("❌ [Blockaid Scan Solana Tx] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Solana Tx failed: \(error.localizedDescription)")
      }
    }
  }

  private func logSolanaResult(_ response: BlockaidScanSolanaResponse) {
    logger.info("📊 [Blockaid Solana Result]")

    if let rawResponse = response.data?.rawResponse {
      logger.info("  Status: \(rawResponse.status ?? "Unknown")")
      logger.info("  Encoding: \(rawResponse.encoding ?? "Unknown")")

      if let result = rawResponse.result {
        if let validation = result.validation {
          logger.info("  Result Type: \(validation.resultType)")
          if let reason = validation.reason {
            logger.info("  Reason: \(reason)")
          }
          if let features = validation.features {
            logger.info("  Features: \(features.joined(separator: ", "))")
          }
          if let extendedFeatures = validation.extendedFeatures {
            logger.info("  Extended Features: \(extendedFeatures.count)")
            for feature in extendedFeatures {
              logger.info("    - [\(feature.type)] \(feature.featureId): \(feature.description)")
            }
          }
        }

        if let simulation = result.simulation, let actions = simulation.transactionActions {
          logger.info("  Transaction Actions: \(actions.joined(separator: ", "))")
        }
      }
    }
  }

  // MARK: - Blockaid Scan Address

  @IBAction func blockaidScanAddress(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Blockaid Scan Address] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Blockaid Scan Address] Starting scan...")

        // Use benign addresses: USDC and a known Solana address
        let evmMetadata = BlockaidScanAddressMetadata(domain: "https://app.uniswap.org")
        let evmRequest = BlockaidScanAddressRequest(
          address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC on Ethereum
          chain: "eip155:1",
          metadata: evmMetadata
        )

        logger.info("  Scanning EVM address...")
        let evmResponse = try await portal.security.blockaid.scanAddress(request: evmRequest)
        logAddressResult(evmResponse, label: "EVM")

        let solanaRequest = BlockaidScanAddressRequest(
          address: "So11111111111111111111111111111111111111112", // Wrapped SOL
          chain: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
          metadata: nil
        )

        logger.info("  Scanning Solana address...")
        let solanaResponse = try await portal.security.blockaid.scanAddress(request: solanaRequest)
        logAddressResult(solanaResponse, label: "Solana")

        let evmResultType = evmResponse.data?.rawResponse.resultType ?? "Unknown"
        let solanaResultType = solanaResponse.data?.rawResponse.resultType ?? "Unknown"
        showStatusView(message: "\(successStatus) Address scan completed - EVM: \(evmResultType), Solana: \(solanaResultType)")

      } catch {
        logger.error("❌ [Blockaid Scan Address] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Address scan failed: \(error.localizedDescription)")
      }
    }
  }

  private func logAddressResult(_ response: BlockaidScanAddressResponse, label: String) {
    logger.info("📊 [Blockaid Address Result - \(label)]")

    if let rawResponse = response.data?.rawResponse {
      logger.info("  Result Type: \(rawResponse.resultType)")

      if let features = rawResponse.features {
        logger.info("  Features: \(features.count)")
        for feature in features {
          logger.info("    - [\(feature.type)] \(feature.featureId): \(feature.description)")
        }
      }
    }
  }

  // MARK: - Blockaid Scan Tokens

  @IBAction func blockaidScanTokens(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Blockaid Scan Tokens] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Blockaid Scan Tokens] Starting scan...")

        // Use benign tokens: WETH and USDC on Ethereum mainnet
        let tokens = [
          "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
          "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  // USDC
        ]

        let request = BlockaidScanTokensRequest(
          chain: "eip155:1",
          tokens: tokens,
          metadata: nil
        )

        let response = try await portal.security.blockaid.scanTokens(request: request)

        logTokensResult(response)

        for (address, result) in response.data?.rawResponse.results ?? [:] {
          if result.resultType == "Malicious" {
            logger.info("⚠️ Token \(address) is MALICIOUS")
          }
        }
        showStatusView(message: "\(successStatus) Tokens scan completed successfully")

      } catch {
        logger.error("❌ [Blockaid Scan Tokens] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) Tokens scan failed: \(error.localizedDescription)")
      }
    }
  }

  private func logTokensResult(_ response: BlockaidScanTokensResponse) {
    logger.info("📊 [Blockaid Tokens Result]")

    if let rawResponse = response.data?.rawResponse {
      logger.info("  Results count: \(rawResponse.results.count)")

      for (address, result) in rawResponse.results {
        logger.info("  Token: \(address)")
        logger.info("    Result Type: \(result.resultType)")
        if let score = result.maliciousScore {
          logger.info("    Malicious Score: \(score)")
        }
        if let metadata = result.metadata {
          logger.info("    Name: \(metadata.name ?? "Unknown")")
          logger.info("    Symbol: \(metadata.symbol ?? "Unknown")")
        }
        if let features = result.features {
          logger.info("    Features: \(features.count)")
          for feature in features {
            logger.info("      - [\(feature.type)] \(feature.featureId): \(feature.description)")
          }
        }
      }
    }
  }

  // MARK: - Blockaid Scan URL

  @IBAction func blockaidScanURL(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Blockaid Scan URL] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        logger.info("📝 [Blockaid Scan URL] Starting scan...")

        let metadata = BlockaidScanURLMetadata(type: .catalog)
        let request = BlockaidScanURLRequest(
          url: "https://app.uniswap.org",
          metadata: metadata
        )

        let response = try await portal.security.blockaid.scanURL(request: request)

        logURLResult(response)

        let status = response.data?.rawResponse.status
        if (response.data?.rawResponse.isMalicious ?? false) {
          logger.info("⚠️ [Blockaid Scan URL] URL flagged as MALICIOUS")
        } else if status == "miss" {
          logger.info("ℹ️ [Blockaid Scan URL] URL not in database (miss)")
        } else {
          logger.info("✅ [Blockaid Scan URL] URL appears safe")
        }
        showStatusView(message: "\(successStatus) URL scan completed (\(status ?? "unknown"))")

      } catch {
        logger.error("❌ [Blockaid Scan URL] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) URL scan failed: \(error.localizedDescription)")
      }
    }
  }

  private func logURLResult(_ response: BlockaidScanURLResponse) {
    logger.info("📊 [Blockaid URL Result]")

    if let rawResponse = response.data?.rawResponse {
      logger.info("  Status: \(rawResponse.status)")

      if rawResponse.status == "hit" {
        if let url = rawResponse.url {
          logger.info("  URL: \(url)")
        }
        logger.info("  Is Malicious: \(rawResponse.isMalicious ?? false)")
        logger.info("  Malicious Score: \(rawResponse.maliciousScore ?? 0)")
        logger.info("  Is Reachable: \(rawResponse.isReachable ?? false)")
        logger.info("  Is Web3 Site: \(rawResponse.isWeb3Site ?? false)")

        if let networkOps = rawResponse.networkOperations {
          logger.info("  Network Operations: \(networkOps.count)")
        }
        if let jsonRpcOps = rawResponse.jsonRpcOperations {
          logger.info("  JSON-RPC Operations: \(jsonRpcOps.joined(separator: ", "))")
        }
      }
    }
  }
}

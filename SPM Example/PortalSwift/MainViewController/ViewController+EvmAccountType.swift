//
//  ViewController+EvmAccountType.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  EVM Account Type / EIP-7702 upgrade testing functionality
//

import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  @IBAction func evmAccountGetStatus(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [EVM Account GetStatus] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let chainId = "eip155:10143"

        let statusBefore = try await portal.evmAccountType.getStatus(chainId: chainId)
        logger.info("📝  Status: \(statusBefore.data.status)")
        logger.info("📝  EOA Address: \(statusBefore.metadata.eoaAddress)")
        if let sc = statusBefore.metadata.smartContractAddress {
          logger.info("📝  Smart Contract Address: \(sc)")
        }

      } catch {
        logger.error("❌ EVM Account GetStatus Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Upgrade AA to EIP7702

  @IBAction func upgradeToEIP7702(_: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Upgrade EIP7702] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let chainId = "eip155:10143"

        // Step 1: Upgrade
        logger.info("📝 [Upgrade EIP7702] Step 3: Upgrading to EIP-7702...")
        let txHash = try await portal.evmAccountType.upgradeTo7702(chainId: chainId)
        logger.info("  Transaction Hash: \(txHash)")
        logger.info("  Explorer: https://sepolia.etherscan.io/tx/\(txHash)")

        // Step 2: Wait for transaction confirmation on chain
        logger.info("📝 [Upgrade EIP7702] Step 4: Waiting for transaction confirmation...")
        let confirmed = await waitForTransactionConfirmation(
          txHash: txHash,
          chainId: chainId,
          portal: portal
        )

        guard confirmed else {
          showStatusView(message: "⚠️ Tx not confirmed (\(txHash)). Explorer: https://sepolia.etherscan.io/tx/\(txHash)")
          return
        }

        // Step 3: Verify final status
        logger.info("📝 [Upgrade EIP7702] Step 5: Verifying final status...")
        let statusAfter = try await portal.evmAccountType.getStatus(chainId: chainId)
        logger.info("  Final Status: \(statusAfter.data.status)")

        if statusAfter.data.status == "EIP_7702_EOA" {
          showStatusView(message: "\(successStatus) Upgraded to EIP-7702! Tx: \(txHash)")
        } else {
          showStatusView(message: "⚠️ Tx sent (\(txHash)) but status is \(statusAfter.data.status). Explorer: https://sepolia.etherscan.io/tx/\(txHash)")
        }
      } catch {
        logger.error("❌ [Upgrade EIP7702] Error: \(error.localizedDescription)")
        showStatusView(message: "\(failureStatus) \(error.localizedDescription)")
      }
    }
  }
}

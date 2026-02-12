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

  // MARK: - Upgrade AA to EIP7702

  @IBAction func upgradeToEIP7702(_ sender: Any) {
    startLoading()

    Task { @MainActor in
      defer { stopLoading() }

      guard let portal = portal else {
        logger.error("❌ [Upgrade EIP7702] Portal not initialized")
        showStatusView(message: "\(failureStatus) Portal not initialized")
        return
      }

      do {
        let chainId = "eip155:11155111"

        // Step 1: Check current status
        logger.info("📝 [Upgrade EIP7702] Step 1: Checking account type status...")
        let statusBefore = try await portal.evmAccountType.getStatus(chainId: chainId)
        logger.info("  Status: \(statusBefore.data.status)")
        logger.info("  EOA Address: \(statusBefore.metadata.eoaAddress)")
        if let sc = statusBefore.metadata.smartContractAddress {
          logger.info("  Smart Contract Address: \(sc)")
        }

        // Step 2: Pause and ask user to fund the address
        logger.info("📝 [Upgrade EIP7702] Step 2: Ensure EOA address \(statusBefore.metadata.eoaAddress) is funded with ETH for gas")
        let shouldContinue = await showFundingAlert(address: statusBefore.metadata.eoaAddress)
        guard shouldContinue else {
          logger.info("📝 [Upgrade EIP7702] User cancelled upgrade.")
          showStatusView(message: "Upgrade cancelled by user.")
          return
        }

        // Step 3: Upgrade
        logger.info("📝 [Upgrade EIP7702] Step 3: Upgrading to EIP-7702...")
        let txHash = try await portal.evmAccountType.upgradeTo7702(chainId: chainId)
        logger.info("  Transaction Hash: \(txHash)")
        logger.info("  Explorer: https://sepolia.etherscan.io/tx/\(txHash)")

        // Step 4: Wait for transaction confirmation on chain
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

        // Step 5: Verify final status
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

  // MARK: - Funding Alert

  /// Shows an alert asking the user to fund the EOA address before continuing.
  /// Returns `true` if the user taps "Continue", `false` if they tap "Cancel".
  @MainActor
  private func showFundingAlert(address: String) async -> Bool {
    await withCheckedContinuation { continuation in
      let alert = UIAlertController(
        title: "Fund Your Address",
        message: "Please fund the following address with Sepolia ETH for gas before continuing:\n\n\(address)",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
        continuation.resume(returning: false)
      })
      alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
        continuation.resume(returning: true)
      })
      self.present(alert, animated: true)
    }
  }

}

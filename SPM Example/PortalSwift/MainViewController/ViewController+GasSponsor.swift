//
//  ViewController+GasSponsor.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 16/12/2025.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import os.log
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  @IBAction func handleTestGasSponsor() {
    Task {
      guard let portal = self.portal else {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Portal not initialized")
        self.showStatusView(message: "\(self.failureStatus) Portal not initialized")
        return
      }

      self.startLoading()
      let chainId = "eip155:11155111"
      let recipientAddress = "0xdFd8302f44727A6348F702fF7B594f127dE3A902"
      let amount = "0.000001"
      let token = "NATIVE"

      // 1st gas sponsor test case is to call sendAsset passing no gas sponsor flag, it should be defaulted to true from the backend side
      do {
        self.logger.info("1st gas sponsor test case is to call sendAsset passing no gas sponsor flag, it should be defaulted to true from the backend side")
        let params1 = SendAssetParams(to: recipientAddress, amount: amount, token: token)
        let response1 = try await portal.sendAsset(chainId: chainId, params: params1)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 1 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(response1.txHash)?network=sepolia&section=overview")
        
        // Wait for transaction confirmation before proceeding
          let confirmed1 = await self.waitForUserOperationConfirmation(txHash: response1.txHash, chainId: chainId, portal: portal, waitingInSeconds: 5)
        self.logger.info("Test 1 transaction confirmation: \(confirmed1 ? "✅ Confirmed" : "❌ Not confirmed")")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 1 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 1 failed: \(error)")
      }

      // 2nd gas sponsor test case is to call sendAsset passing `true` gas sponsor flag
      do {
        self.logger.info("2nd gas sponsor test case is to call sendAsset passing `true` gas sponsor flag")
        let params2 = SendAssetParams(to: recipientAddress, amount: amount, token: token, sponsorGas: true)
        let response2 = try await portal.sendAsset(chainId: chainId, params: params2)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 2 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(response2.txHash)?network=sepolia&section=overview")
        
        // Wait for transaction confirmation before proceeding
        let confirmed2 = await self.waitForUserOperationConfirmation(txHash: response2.txHash, chainId: chainId, portal: portal, waitingInSeconds: 5)
        self.logger.info("Test 2 transaction confirmation: \(confirmed2 ? "✅ Confirmed" : "❌ Not confirmed")")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 2 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 2 failed: \(error)")
      }

      // 3rd gas sponsor test case is to call sendAsset passing `false` gas sponsor flag
      do {
        self.logger.info("3rd gas sponsor test case is to call sendAsset passing `false` gas sponsor flag")
        let params3 = SendAssetParams(to: recipientAddress, amount: amount, token: token, sponsorGas: false)
        let response3 = try await portal.sendAsset(chainId: chainId, params: params3)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 3 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(response3.txHash)?network=sepolia&section=overview")
        
        // Wait for transaction confirmation before proceeding
        let confirmed3 = await self.waitForUserOperationConfirmation(txHash: response3.txHash, chainId: chainId, portal: portal, waitingInSeconds: 5)
        self.logger.info("Test 3 transaction confirmation: \(confirmed3 ? "✅ Confirmed" : "❌ Not confirmed")")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 3 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 3 failed: \(error)")
      }

      // 4th gas sponsor test case is to call request(eth_sendTransaction) passing no gas sponsor flag, it should be defaulted to true from the backend side
      do {
        self.logger.info("4th gas sponsor test case is to call request(eth_sendTransaction) passing no gas sponsor flag, it should be defaulted to true from the backend side")
        let transactionParam1 = BuildTransactionParam(
          to: recipientAddress,
          token: token,
          amount: amount
        )
        let transactionResponse1 = try await portal.buildEip155Transaction(chainId: chainId, params: transactionParam1)
        let sendTransactionResponse1 = try await portal.request(
          chainId: chainId,
          method: .eth_sendTransaction,
          params: [transactionResponse1.transaction],
          options: nil
        )
        guard let transactionHash1 = sendTransactionResponse1.result as? String else {
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 4 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(transactionHash1)?network=sepolia&section=overview")
        
        // Wait for transaction confirmation before proceeding
        let confirmed4 = await self.waitForUserOperationConfirmation(txHash: transactionHash1, chainId: chainId, portal: portal, waitingInSeconds: 5)
        self.logger.info("Test 4 transaction confirmation: \(confirmed4 ? "✅ Confirmed" : "❌ Not confirmed")")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 4 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 4 failed: \(error)")
      }

      // 5th gas sponsor test case is to call request(eth_sendTransaction) passing `true` gas sponsor flag
      do {
        self.logger.info("5th gas sponsor test case is to call request(eth_sendTransaction) passing `true` gas sponsor flag")
        let transactionParam2 = BuildTransactionParam(
          to: recipientAddress,
          token: token,
          amount: amount
        )
        let transactionResponse2 = try await portal.buildEip155Transaction(chainId: chainId, params: transactionParam2)
        let sendTransactionResponse2 = try await portal.request(
          chainId: chainId,
          method: .eth_sendTransaction,
          params: [transactionResponse2.transaction],
          options: RequestOptions(sponsorGas: true)
        )
        guard let transactionHash2 = sendTransactionResponse2.result as? String else {
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 5 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(transactionHash2)?network=sepolia&section=overview")
        
        // Wait for transaction confirmation before proceeding
        let confirmed5 = await self.waitForUserOperationConfirmation(txHash: transactionHash2, chainId: chainId, portal: portal, waitingInSeconds: 5)
        self.logger.info("Test 5 transaction confirmation: \(confirmed5 ? "✅ Confirmed" : "❌ Not confirmed")")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 5 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 5 failed: \(error)")
      }

      // 6th gas sponsor test case is to call request(eth_sendTransaction) passing `false` gas sponsor flag
      do {
        self.logger.info("6th gas sponsor test case is to call request(eth_sendTransaction) passing `false` gas sponsor flag")
        let transactionParam3 = BuildTransactionParam(
          to: recipientAddress,
          token: token,
          amount: amount
        )
        let transactionResponse3 = try await portal.buildEip155Transaction(chainId: chainId, params: transactionParam3)
        let sendTransactionResponse3 = try await portal.request(
          chainId: chainId,
          method: .eth_sendTransaction,
          params: [transactionResponse3.transaction],
          options: RequestOptions(sponsorGas: false)
        )
        guard let transactionHash3 = sendTransactionResponse3.result as? String else {
          throw PortalExampleAppError.invalidResponseTypeForRequest()
        }
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 6 Success: Transaction: https://jiffyscan.xyz/userOpHash/\(transactionHash3)?network=sepolia&section=overview")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 6 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 6 failed: \(error)")
      }

      self.showStatusView(message: "\(self.successStatus) Gas sponsor tests completed")
      self.stopLoading()
    }
  }
    
    func waitForUserOperationConfirmation(
      txHash: String,
      chainId: String,
      portal: PortalProtocol,
      maxAttempts: Int = 30,
      waitingInSeconds: Int = 2
    ) async -> Bool {
      self.logger.info("Waiting for transaction confirmation: \(txHash) on chain: \(chainId)")

      for attempt in 0 ..< maxAttempts {
        do {
          // Wait `waitingInSeconds` seconds between attempts
            let waitingTimeInNanoSeconds: UInt64 = UInt64(waitingInSeconds * 1_000_000_000)
            try await Task.sleep(nanoseconds: waitingTimeInNanoSeconds)

          // Check transaction receipt
          let response = try await portal.request(chainId, withMethod: .eth_getUserOperationReceipt, andParams: [txHash])
          // The result is a UserOperationResponse
          if let userOpResponse = response.result as? UserOperationResponse {
            // The actual receipt is in userOpResponse.result
            if let status = userOpResponse.result?.receipt?.status {
              if status == "0x1" {
                self.logger.info("Transaction \(txHash) confirmed successfully after \(attempt + 1) attempts")
                return true
              } else {
                self.logger.error("Transaction \(txHash) failed (reverted) after \(attempt + 1) attempts")
                return false
              }
            } else {
              self.logger.info("Transaction \(txHash) receipt found but status not available, attempt \(attempt + 1)/\(maxAttempts)")
            }
          } else {
            self.logger.info("Transaction \(txHash) not yet mined, attempt \(attempt + 1)/\(maxAttempts)")
          }
        } catch {
          self.logger.error("Error checking transaction confirmation: \(error.localizedDescription)")
        }
      }

      self.logger.error("Transaction \(txHash) not confirmed after \(maxAttempts) attempts")
      return false
    }
}

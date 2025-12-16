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

      // 1st gas sponsor test case is to call sendAsset passing no gas sponsor flag, it should be defaulted to false from the backend side
      do {
        self.logger.info("1st gas sponsor test case is to call sendAsset passing no gas sponsor flag, it should be defaulted to false from the backend side")
        let params1 = SendAssetParams(to: recipientAddress, amount: amount, token: token)
        let response1 = try await portal.sendAsset(chainId: chainId, params: params1)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 1 Success: Transaction Hash: \(response1.txHash)")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 1 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 1 failed: \(error)")
      }

      // 2nd gas sponsor test case is to call sendAsset passing `true` gas sponsor flag
      do {
        self.logger.info("2nd gas sponsor test case is to call sendAsset passing `true` gas sponsor flag")
        let params2 = SendAssetParams(to: recipientAddress, amount: amount, token: token, sponsorGas: true)
        let response2 = try await portal.sendAsset(chainId: chainId, params: params2)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 2 Success: Transaction Hash: \(response2.txHash)")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 2 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 2 failed: \(error)")
      }

      // 3rd gas sponsor test case is to call sendAsset passing `false` gas sponsor flag
      do {
        self.logger.info("3rd gas sponsor test case is to call sendAsset passing `false` gas sponsor flag")
        let params3 = SendAssetParams(to: recipientAddress, amount: amount, token: token, sponsorGas: false)
        let response3 = try await portal.sendAsset(chainId: chainId, params: params3)
        self.logger.info("ViewController.handleTestGasSponsor() - ✅ Test 3 Success: Transaction Hash: \(response3.txHash)")
      } catch {
        self.logger.error("ViewController.handleTestGasSponsor() - ❌ Test 3 Error: \(error)")
        self.showStatusView(message: "\(self.failureStatus) Test 3 failed: \(error)")
      }

      self.showStatusView(message: "\(self.successStatus) Gas sponsor tests completed")
      self.stopLoading()
    }
  }
}

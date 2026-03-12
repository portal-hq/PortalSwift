//
//  ViewController+SendAssetBenchmark.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 04/03/2026.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import os.log
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  @IBAction func handleBenchmarkSendAsset() {
    Task {
      guard let portal = self.portal else {
        self.logger.error("SendAssetBenchmark - Portal not initialized")
        self.showStatusView(message: "\(self.failureStatus) Portal not initialized")
        return
      }

      self.startLoading()

      let iterations = 10
      let chainId = "eip155:10143"
      let recipientAddress = "0xdFd8302f44727A6348F702fF7B594f127dE3A902"
      let amount = "0.000001"
      let token = "NATIVE"
      let usePresignatures = Settings.shared.usePresignatures

      self.logger.info("SendAssetBenchmark - Starting \(iterations) iterations (presignatures: \(usePresignatures))")
      self.showStatusView(message: "Benchmark running... 0/\(iterations)")

      var durations: [TimeInterval] = []
      var failures = 0

      for i in 1 ... iterations {
        let start = CFAbsoluteTimeGetCurrent()
        do {
          let params = SendAssetParams(to: recipientAddress, amount: amount, token: token)
          let response = try await portal.sendAsset(chainId: chainId, params: params)
          let elapsed = CFAbsoluteTimeGetCurrent() - start
          durations.append(elapsed)
          self.logger.info("SendAssetBenchmark - [\(i)/\(iterations)] \(String(format: "%.3f", elapsed))s - txHash: \(response.txHash)")
          self.showStatusView(message: "Benchmark running... \(i)/\(iterations)")
        } catch {
          let elapsed = CFAbsoluteTimeGetCurrent() - start
          failures += 1
          self.logger.error("SendAssetBenchmark - [\(i)/\(iterations)] FAILED after \(String(format: "%.3f", elapsed))s - \(error)")
        }
      }

      self.logBenchmarkResults(label: "SendAssetBenchmark", durations: durations, failures: failures, iterations: iterations, usePresignatures: usePresignatures)
      self.stopLoading()
    }
  }

  @IBAction func handleBenchmarkPersonalSign() {
    Task {
      guard let portal = self.portal else {
        self.logger.error("PersonalSignBenchmark - Portal not initialized")
        self.showStatusView(message: "\(self.failureStatus) Portal not initialized")
        return
      }

      self.startLoading()

      let iterations = 10
      let chainId = "eip155:10143"
      let usePresignatures = Settings.shared.usePresignatures

      guard let address = await portal.getAddress(chainId) else {
        self.logger.error("PersonalSignBenchmark - Address not found")
        self.showStatusView(message: "\(self.failureStatus) Address not found")
        self.stopLoading()
        return
      }

      self.logger.info("PersonalSignBenchmark - Starting \(iterations) iterations (presignatures: \(usePresignatures))")
      self.showStatusView(message: "Benchmark running... 0/\(iterations)")

      var durations: [TimeInterval] = []
      var failures = 0

      for i in 1 ... iterations {
        let start = CFAbsoluteTimeGetCurrent()
        do {
          let response = try await portal.request(
            chainId: chainId,
            method: .personal_sign,
            params: ["0xdeadbeef", address],
            options: nil
          )
          let elapsed = CFAbsoluteTimeGetCurrent() - start
          durations.append(elapsed)
          let signature = (response.result as? String) ?? "unknown"
          self.logger.info("PersonalSignBenchmark - [\(i)/\(iterations)] \(String(format: "%.3f", elapsed))s - sig: \(signature.prefix(20))...")
          self.showStatusView(message: "Benchmark running... \(i)/\(iterations)")
        } catch {
          let elapsed = CFAbsoluteTimeGetCurrent() - start
          failures += 1
          self.logger.error("PersonalSignBenchmark - [\(i)/\(iterations)] FAILED after \(String(format: "%.3f", elapsed))s - \(error)")
        }
      }

      self.logBenchmarkResults(label: "PersonalSignBenchmark", durations: durations, failures: failures, iterations: iterations, usePresignatures: usePresignatures)
      self.stopLoading()
    }
  }

  private func logBenchmarkResults(label: String, durations: [TimeInterval], failures: Int, iterations: Int, usePresignatures: Bool) {
    if !durations.isEmpty {
      let avg = durations.reduce(0, +) / Double(durations.count)
      let minTime = durations.min()!
      let maxTime = durations.max()!
      let allTimes = durations.map { String(format: "%.3f", $0) }.joined(separator: ", ")

      self.logger.info("""
      \(label) Results (presignatures: \(usePresignatures)):
        Iterations: \(iterations) (\(failures) failed)
        Average: \(String(format: "%.3f", avg))s
        Min:     \(String(format: "%.3f", minTime))s
        Max:     \(String(format: "%.3f", maxTime))s
        All:     [\(allTimes)]s
      """)
      self.showStatusView(
        message: "\(self.successStatus) Presig=\(usePresignatures) | Avg: \(String(format: "%.3f", avg))s | Min: \(String(format: "%.3f", minTime))s | Max: \(String(format: "%.3f", maxTime))s"
      )
    } else {
      self.showStatusView(message: "\(self.failureStatus) All \(iterations) iterations failed")
    }
  }
}

//
//  ViewController+HyperNativeSecurity.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Hypernative Security testing functionality
//

import PortalSwift
import UIKit

// MARK: - Hypernative Security Test Actions

@available(iOS 16.0, *)
extension ViewController {
  
  // MARK: - IBActions
  
  /// Tests all transaction scan functions: EIP-155, EIP-712, and Solana
  @IBAction func hypernativeScanTx(_ sender: Any) {
    startLoading()
    
    Task {
      logger.info("ViewController.hypernativeScanTx() - 📝 Starting transaction scans...")
      
      // Test EIP-155 Transaction Scan
      await testEip155Scan()
      
      // Test EIP-712 Transaction Scan
      await testEip712Scan()
      
      // Test Solana Transaction Scan
      await testSolanaScan()
      
      await MainActor.run {
        self.stopLoading()
        self.showStatusView(message: "\(self.successStatus) All transaction scans completed! Check logs for details.")
      }
    }
  }
  
  /// Tests address screening functionality
  @IBAction func hypernativeScanAddresses(_ sender: Any) {
    startLoading()
    
    Task {
      do {
        logger.info("ViewController.hypernativeScanAddresses() - 📝 Starting address scan...")
        
        let request = ScanAddressesRequest(
          addresses: [
            "0x31c05d73f2333b5a176cfdbb7c5ef96ec7bb04ac",
            "0x2753a0d37a2ad09be3ccc0afcb650bea8ea57a8f"
          ],
          screenerPolicyId: nil
        )
        
        guard let portal = portal else {
          logger.error("ViewController.hypernativeScanAddresses() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        
        let response = try await portal.security.hypernative.scanAddresses(request: request)
        
        logAddressScanResult(response)
        
        await MainActor.run {
          self.stopLoading()
          self.showStatusView(message: "\(self.successStatus) Address scan completed! Check logs for details.")
        }
      } catch {
        await handleError(error, context: "Address Scan")
      }
    }
  }
  
  /// Tests NFT scanning functionality
  @IBAction func hypernativeScanNfts(_ sender: Any) {
    startLoading()
    
    Task {
      do {
        logger.info("ViewController.hypernativeScanNfts() - 📝 Starting NFT scan...")
        
        let request = ScanNftsRequest(
          nfts: [
            ScanNftsRequestItem(
              address: "0x5C1B9caA8492585182eD994633e76d744A876548",
              chain: nil,
              evmChainId: "eip155:1"
            ),
            ScanNftsRequestItem(
              address: "0xC2e0cA5FE0b9AbE1B86f3cC0b865448908D20A16",
              chain: nil,
              evmChainId: "eip155:1"
            )
          ]
        )
        
        guard let portal = portal else {
          logger.error("ViewController.hypernativeScanNfts() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        
        let response = try await portal.security.hypernative.scanNfts(request: request)
        
        logNftScanResult(response)
        
        await MainActor.run {
          self.stopLoading()
          self.showStatusView(message: "\(self.successStatus) NFT scan completed! Check logs for details.")
        }
      } catch {
        await handleError(error, context: "NFT Scan")
      }
    }
  }
  
  /// Tests token scanning functionality
  @IBAction func hypernativeScanTokens(_ sender: Any) {
    startLoading()
    
    Task {
      do {
        logger.info("ViewController.hypernativeScanTokens() - 📝 Starting token scan...")
        
        let request = ScanTokensRequest(
          tokens: [
            ScanTokensRequestItem(
              address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
              chain: nil,
              evmChainId: "eip155:1"
            )
          ]
        )
        
        guard let portal = portal else {
          logger.error("ViewController.hypernativeScanTokens() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        
        let response = try await portal.security.hypernative.scanTokens(request: request)
        
        logTokenScanResult(response)
        
        await MainActor.run {
          self.stopLoading()
          self.showStatusView(message: "\(self.successStatus) Token scan completed! Check logs for details.")
        }
      } catch {
        await handleError(error, context: "Token Scan")
      }
    }
  }
  
  /// Tests URL scanning functionality
  @IBAction func hypernativeScanURL(_ sender: Any) {
    startLoading()
    
    Task {
      do {
        logger.info("ViewController.hypernativeScanURL() - 📝 Starting URL scan...")
        
        let request = ScanUrlRequest(url: "curve.fi")
        
        guard let portal = portal else {
          logger.error("ViewController.hypernativeScanURL() - ❌ Portal not initialized")
          throw PortalExampleAppError.portalNotInitialized()
        }
        
        let response = try await portal.security.hypernative.scanURL(request: request)
        
        logUrlScanResult(response)
        
        await MainActor.run {
          self.stopLoading()
          let isMalicious = response.data?.rawResponse.data?.isMalicious ?? false
          let statusEmoji = isMalicious ? "⚠️" : "✅"
          self.showStatusView(message: "\(self.successStatus) URL scan completed! \(statusEmoji) Is malicious: \(isMalicious)")
        }
      } catch {
        await handleError(error, context: "URL Scan")
      }
    }
  }
  
  // MARK: - Private Helper Methods
  
  private func testEip155Scan() async {
    do {
      logger.info("ViewController.testEip155Scan() - 📝 Testing EIP-155 transaction scan...")
      
      guard let portal = portal else {
        logger.error("ViewController.testEip155Scan() - ❌ Portal not initialized")
        return
      }
      
      let transaction = HypernativeTransactionObject(
        chain: "eip155:1",
        fromAddress: "0x7C01728004d3F2370C1BBC36a4Ad680fE6FE8729",
        toAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        input: "0x095ea7b300000000000000000000000066ba61be3bab35c0c00038f335850a390b086fe300000000000000000000000000000000000000000fffffffffffffffffffffff",
        value: 0,
        nonce: 2340,
        hash: nil,
        gas: 3000000,
        gasPrice: 3000000,
        maxPriorityFeePerGas: nil,
        maxFeePerGas: nil
      )
      
      let request = ScanEip155Request(
        transaction: transaction,
        url: nil,
        blockNumber: nil,
        validateNonce: nil,
        showFullFindings: nil,
        policy: nil
      )
      
      let response = try await portal.security.hypernative.scanEip155Tx(request: request)
      
      logger.info("ViewController.testEip155Scan() - ✅ EIP-155 scan completed successfully")
      logEip155Result(response)
      
    } catch {
      logger.error("ViewController.testEip155Scan() - ❌ EIP-155 scan failed: \(error.localizedDescription)")
    }
  }
  
  private func testEip712Scan() async {
    do {
      logger.info("ViewController.testEip712Scan() - 📝 Testing EIP-712 transaction scan...")
      
      guard let portal = portal else {
        logger.error("ViewController.testEip712Scan() - ❌ Portal not initialized")
        return
      }
      
      let domain = Eip712Domain(
        name: "MyToken",
        version: "1",
        chainId: "eip155:1",
        verifyingContract: "0xa0b86991c6218b36c1d19d4a2e9Eb0cE3606eB48",
        salt: nil
      )
      
      let types: [String: [Eip712TypeProperty]] = [
        "EIP712Domain": [
          Eip712TypeProperty(name: "name", type: "string"),
          Eip712TypeProperty(name: "version", type: "string"),
          Eip712TypeProperty(name: "chainId", type: "uint256"),
          Eip712TypeProperty(name: "verifyingContract", type: "address")
        ],
        "Permit": [
          Eip712TypeProperty(name: "owner", type: "address"),
          Eip712TypeProperty(name: "spender", type: "address"),
          Eip712TypeProperty(name: "value", type: "uint256"),
          Eip712TypeProperty(name: "nonce", type: "uint256"),
          Eip712TypeProperty(name: "deadline", type: "uint256")
        ]
      ]
      
      let message = Eip712TypedData(
        primaryType: "Permit",
        types: types,
        domain: domain,
        message: Eip712Message(
          owner: "0x7b1363f33b86d16ef7c8d03d11f4394a37d95c36",
          spender: "0x67beb4dd770a9c2cbc7133ba428b9eecdcf09186",
          value: 3000,
          nonce: 0,
          deadline: 50000000000
        )
      )
      
      let request = ScanEip712Request(
        walletAddress: "0x12345",
        chainId: "eip155:1",
        eip712Message: message,
        showFullFindings: nil,
        policy: nil
      )
      
      let response = try await portal.security.hypernative.scanEip712Tx(request: request)
      
      logger.info("ViewController.testEip712Scan() - ✅ EIP-712 scan completed successfully")
      logEip712Result(response)
      
    } catch {
      logger.error("ViewController.testEip712Scan() - ❌ EIP-712 scan failed: \(error.localizedDescription)")
    }
  }
  
  private func testSolanaScan() async {
    do {
      logger.info("ViewController.testSolanaScan() - 📝 Testing Solana transaction scan...")
      
      guard let portal = portal else {
        logger.error("ViewController.testSolanaScan() - ❌ Portal not initialized")
        return
      }
      
      let transaction = SolanaTransaction(
        message: nil,
        signatures: nil,
        rawTransaction: "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAQADCQkVR3SiiKbW0l4c3NBsEn6+zn1o0YsyypPwN0GUhg4K5HK0Tb5GckDLYW+MsovQASt5EZ3bSH3nluRJAE69H61w0BRUDTrpYQcXosUun6/z2BROkRoH/1bL7KLU9s4lCav6k3ZZgV6qeZFwu4pu89WoIGaqUxG4C93XwVmmDy81v8qBaCSP4/UZfdo3q1bud/W+ixymkH8IMe0laQZYrSx4Uhyxec67hYm1VqLV7JTSSYaC/fm7KvWtZOSRzEFT2gMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAAT4tlY/P4mFG1wDJl0ektVggHiZf73lTlHBVJ3fK0nDoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANG5fPtlMEOI/eXV7aPDlpcdLUKm8L3VoW6k/oJlCNLaBQYABQLARQQABgAJAwYAAAAAAAAABzwACQoLCwgyMzQMNQ0ONjcPEDg5EgETFBUWOhEXGBkaGxwdHh8gISI7IyQlJicCKCkqKywtAwQuLzAxPBFVCg8JAQcHBgYBAAAAAwHwCgYBExUbBgICAAAPAwIAAAYBISMoEQQBGQAPAwIAAAYBLjA2DwMCAAAGAgIAAAAIBgYICAADAQkGCQUFBgACBQAEBwEAAAgCAAUMAgAAADwaAAAAAAAABgAFBGDMBQAEPPm21Wu6wrmHu23/ZFNIumpp+ADooZjd4JQgvjnBxkUJAgEDBqWqCgmmCAUIBwu1tp+gcP/+Ri3C1tRXUbPdgqo6rVsj/qnqC959wTdC/mRARysLz9HS09TW19jZ2tsC1QYsNrdxMcm5Nq5FXZrM0IXpEA+ApFa+pz/JvkLz0+2vnwuztLW2t7i5uru8vgAPvBv8VUeRwDy9yD1NHIH5Ji6ZA+zrmpHejKOz4MP8SwrKy8zNzs/S09TVAdY=",
        version: "0"
      )
      
      let request = ScanSolanaRequest(
        transaction: transaction,
        url: nil,
        validateRecentBlockHash: nil,
        showFullFindings: true,
        policy: nil
      )
      
      let response = try await portal.security.hypernative.scanSolanaTx(request: request)
      
      logger.info("ViewController.testSolanaScan() - ✅ Solana scan completed successfully")
      logSolanaResult(response)
      
    } catch {
      logger.error("ViewController.testSolanaScan() - ❌ Solana scan failed: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Logging Helpers
  
  private func logEip155Result(_ response: ScanEip155Response) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ EIP-155 Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        logger.info("  Recommendation: \(data.recommendation.rawValue)")
        logger.info("  Assessment ID: \(data.assessmentId ?? "N/A")")
        if let findings = data.findings {
          logger.info("  Findings count: \(findings.count)")
          for finding in findings {
            logger.info("    - \(finding.title): \(finding.severity.rawValue)")
          }
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ EIP-155 Scan Error: \(error)")
    }
  }
  
  private func logEip712Result(_ response: ScanEip712Response) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ EIP-712 Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        logger.info("  Recommendation: \(data.recommendation.rawValue)")
        logger.info("  Assessment ID: \(data.assessmentId ?? "N/A")")
        if let findings = data.findings {
          logger.info("  Findings count: \(findings.count)")
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ EIP-712 Scan Error: \(error)")
    }
  }
  
  private func logSolanaResult(_ response: ScanSolanaResponse) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ Solana Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        logger.info("  Recommendation: \(data.recommendation.rawValue)")
        if let findings = data.findings {
          logger.info("  Findings count: \(findings.count)")
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ Solana Scan Error: \(error)")
    }
  }
  
  private func logAddressScanResult(_ response: ScanAddressesResponse) {
    if let data = response.data {
      logger.info("ViewController - ✅ Address Scan Result:")
      for addressResult in data.rawResponse {
        logger.info("  Address: \(addressResult.address)")
        logger.info("    Recommendation: \(addressResult.recommendation)")
        logger.info("    Severity: \(addressResult.severity)")
        logger.info("    Flags count: \(addressResult.flags.count)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ Address Scan Error: \(error)")
    }
  }
  
  private func logNftScanResult(_ response: ScanNftsResponse) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ NFT Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        for nft in data.nfts {
          logger.info("  NFT: \(nft.address)")
          logger.info("    Chain: \(nft.chain)")
          logger.info("    Accept: \(nft.accept)")
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ NFT Scan Error: \(error)")
    }
  }
  
  private func logTokenScanResult(_ response: ScanTokensResponse) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ Token Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        for token in data.tokens {
          logger.info("  Token: \(token.address)")
          logger.info("    Chain: \(token.chain)")
          if let reputation = token.reputation {
            logger.info("    Reputation: \(reputation.recommendation)")
          }
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ Token Scan Error: \(error)")
    }
  }
  
  private func logUrlScanResult(_ response: ScanUrlResponse) {
    if let rawResponse = response.data?.rawResponse {
      logger.info("ViewController - ✅ URL Scan Result:")
      logger.info("  Success: \(rawResponse.success)")
      if let data = rawResponse.data {
        let statusEmoji = data.isMalicious ? "⚠️" : "✅"
        logger.info("  \(statusEmoji) Is Malicious: \(data.isMalicious)")
        if let deepScan = data.deepScanTriggered {
          logger.info("  Deep Scan Triggered: \(deepScan)")
        }
      }
      if let error = rawResponse.error {
        logger.error("  ❌ Error: \(error)")
      }
    } else if let error = response.error {
      logger.error("ViewController - ❌ URL Scan Error: \(error)")
    }
  }
  
  private func handleError(_ error: Error, context: String) async {
    logger.error("ViewController.\(context) - ❌ Error: \(error.localizedDescription)")
    await MainActor.run {
      self.stopLoading()
      self.showStatusView(message: "\(self.failureStatus) \(context) failed: \(error.localizedDescription)")
    }
  }
}

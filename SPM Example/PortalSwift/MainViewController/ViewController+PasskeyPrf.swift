//
//  ViewController+PasskeyPrf.swift
//  SPM Example
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//
//  Passkey PRF backup (`BackupMethods.PasskeyPrf`). A backup made here recovers in the React
//  Native and web example apps from the same passkey under the same relying party.
//

import Foundation
import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  /// Passkey PRF needs iOS 18.4; earlier devices keep the buttons disabled.
  var isPasskeyPrfAvailable: Bool {
    if #available(iOS 18.4, *) {
      return true
    }
    return false
  }

  /// Registers `PasskeyPrfStorage` under the same relying party the enclave passkey uses, which
  /// this app is associated with through its `webcredentials` entitlement.
  func registerPasskeyPrfBackup(_ portal: Portal, relyingParty: String) {
    guard #available(iOS 18.4, *) else {
      return
    }
    portal.registerBackupMethod(.PasskeyPrf, withStorage: PasskeyPrfStorage(relyingParty: relyingParty))
  }

  @IBAction func handlePasskeyPrfBackup(_: UIButton!) {
    Task {
      do {
        guard let userId = user?.exchangeUserId else {
          self.logger.error("ViewController.handlePasskeyPrfBackup() - No userId found. Please login before using Portal.")
          return
        }
        self.startLoading()
        defer { self.stopLoading() }
        self.logger.debug("ViewController.handlePasskeyPrfBackup() - Starting backup...")
        _ = try await self.backup(userId, withMethod: .PasskeyPrf)
        self.logger.debug("ViewController.handlePasskeyPrfBackup(): ✅ Successfully backed up with Passkey PRF.")
        self.showStatusView(message: "\(self.successStatus) Successfully backed up with Passkey PRF.")
        self.updateUIComponents()
      } catch {
        self.logger.error("ViewController.handlePasskeyPrfBackup() - Error running backup: \(Self.describePasskeyPrfError(error))")
        self.showStatusView(message: "\(self.failureStatus) Error running backup \(Self.describePasskeyPrfError(error))")
      }
    }
  }

  @IBAction func handlePasskeyPrfRecover(_: UIButton!) {
    Task {
      do {
        guard let userId = user?.exchangeUserId else {
          self.logger.error("ViewController.handlePasskeyPrfRecover() - No userId found. Please login before using Portal.")
          return
        }
        self.startLoading()
        defer { self.stopLoading() }
        self.logger.debug("ViewController.handlePasskeyPrfRecover() - Starting recover...")
        let (ethereum, solana) = try await recover(userId, withBackupMethod: .PasskeyPrf)
        let debugMessage = "ViewController.handlePasskeyPrfRecover() - ✅ Wallet successfully recovered! ETH address: \(ethereum), Solana address: \(solana ?? "N/A")"
        self.logger.log(level: .debug, "\(debugMessage, privacy: .public)")
        self.showStatusView(message: "\(self.successStatus) Wallet successfully recovered!")
        DispatchQueue.main.async {
          if let addressInformation = self.addressInformation {
            addressInformation.text = ethereum
          }
        }
        self.updateUIComponents()
      } catch {
        self.logger.error("ViewController.handlePasskeyPrfRecover() - Error running recover: \(Self.describePasskeyPrfError(error))")
        self.showStatusView(message: "\(self.failureStatus) Error running recover \(Self.describePasskeyPrfError(error))")
      }
    }
  }

  /// Leads with the cross-SDK reason, so a cancelled prompt reads as a cancel, not a failure, and
  /// ends with the platform's own error, which names setup problems such as a missing
  /// `webcredentials` association.
  static func describePasskeyPrfError(_ error: Error) -> String {
    if let prfError = error as? PortalPasskeyPrfError {
      var description = "\(prfError.reason.rawValue): \(prfError.errorDescription ?? "")"
      if let cause = prfError.cause {
        description += " Cause: \(cause as NSError)"
      }
      return description
    }
    return "\(error)"
  }
}

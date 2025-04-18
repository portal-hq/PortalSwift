//
//  HomeViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//
import Foundation
import PortalSwift
import UIKit

final class HomeViewModel: ObservableObject {
  enum WalletState {
    case loading
    case noWalletAvailable
    case available(ethAddress: String, solanaAddress: String)
    case error(errorMessage: String)
  }

  // MARK: - UI Properties

  @Published private(set) var state: WalletState = .loading

  func getPortal() -> Portal? {
    guard let portal = PortalInstance.shared.portal else {
      setState(.error(errorMessage: "❌ Portal not initialized, please initialize Portal first."))
      print("❌ Portal not initialized, please initialize Portal first.")
      return nil
    }
    return portal
  }
}

// MARK: - Presentation Helpers

extension HomeViewModel {
  private func setState(_ state: WalletState) {
    DispatchQueue.main.async {
      self.state = state
    }
  }
}

extension HomeViewModel {
  func loadWalletState() {
    guard let portal = getPortal() else { return }

    setState(.loading)

    Task {
      do {
        let isWalletExists = try await portal.doesWalletExist()
        if isWalletExists,
           let ethAddress = try? await portal.addresses[.eip155],
           let ethAddress,
           let solanaAddress = try? await portal.addresses[.solana],
           let solanaAddress
        {
          setState(.available(ethAddress: ethAddress, solanaAddress: solanaAddress))
        } else {
          setState(.noWalletAvailable)
        }
      } catch {
        setState(.noWalletAvailable)
      }
    }
  }
}

// MARK: - Generate Wallet

extension HomeViewModel {
  func generateWallet() {
    guard let portal = PortalInstance.shared.portal else {
      setState(.error(errorMessage: "❌ Portal not initialized, please call \"initializePortal()\" first."))
      print("❌ Portal not initialized, please call \"initializePortal()\" first.")
      return
    }

    setState(.loading)

    Task {
      do {
        // create a the wallet
        let wallets = try await portal.createWallet()
        print("✅ wallet created successfully - ETH address: \(wallets.ethereum), Solana address: \(wallets.solana)")
        setState(.available(ethAddress: wallets.ethereum, solanaAddress: wallets.solana))

      } catch {
        setState(.noWalletAvailable)
        print("❌ Error generating wallet:", error.localizedDescription)
      }
    }
  }
}

// MARK: - Copy wallet addresses

extension HomeViewModel {
  func copyEthereumAddress() {
    if case let .available(ethAddress, _) = state {
      copyToClipboard(address: ethAddress)
    }
  }

  func copySolanaAddress() {
    if case let .available(_, solanaAddress) = state {
      copyToClipboard(address: solanaAddress)
    }
  }

  private func copyToClipboard(address: String) {
    UIPasteboard.general.string = address
  }
}

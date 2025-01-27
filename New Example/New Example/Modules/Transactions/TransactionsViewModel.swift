//
//  TransactionsViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation
import PortalSwift

final class TransactionsViewModel: ObservableObject {
    
    enum TransactionState: Equatable {
        case none
        case loading
        case success(message: String)
        case error(errorMessage: String)
    }
    
    @Published private(set) var state: TransactionState = .none
    
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

extension TransactionsViewModel {
  private func setState(_ state: TransactionState) {
    DispatchQueue.main.async {
      self.state = state
    }
  }
}

// MARK: - ETH sign

extension TransactionsViewModel {
    func ethSign() {
        Task {
            guard let portal = getPortal() else { return }

            let chainId = "eip155:11155111"
            guard let address = await portal.getAddress(chainId) else {
                setState(.error(errorMessage: "Address not found"))
                return
            }

            setState(.loading)
            
            let params = [address, "0xdeadbeef"]

            do {
                let response = try await portal.request(chainId, withMethod: .eth_sign, andParams: params)

                guard let signature = response.result as? String else {
                    setState(.error(errorMessage: "Invalid response type for request: \(response.result)"))
                    return
                }
                
                setState(.success(message: "Successfully signed message: \(signature)"))
            } catch {
                setState(.error(errorMessage: "Failed to process request with error: \(error.localizedDescription)"))
            }
        }
    }
}

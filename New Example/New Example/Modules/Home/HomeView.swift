//
//  HomeView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct HomeView: View {
  // ViewModel
  @ObservedObject private var viewModel = HomeViewModel()

  var body: some View {
    VStack {
      switch viewModel.state {
      case .loading:
        ProgressView()
      case .error(errorMessage: let errorMessage):
        Text(errorMessage)
      case .available(ethAddress: let ethAddress, solanaAddress: let solanaAddress):
          VStack {
              WalletDetails(
                ethAddress: ethAddress,
                solanaAddress: solanaAddress,
                onCopyEthAddressClick: {
                    viewModel.copyEthereumAddress()
                },
                onCopySolanaAddressClick: {
                    viewModel.copySolanaAddress()
                }
              )
              
              Rectangle()
                  .frame(height: 1)
              
              BackupAndRecoverView()
                  .padding(.top)
          }
      case .noWalletAvailable:
        PortalButton(title: "Generate Wallet") {
          viewModel.generateWallet()
        }
        .frame(height: 40)
      }
      Spacer()
    }
    .padding()
    .onAppear {
      viewModel.loadWalletState()
    }
  }
}

#Preview {
  HomeView()
}

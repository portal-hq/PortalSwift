//
//  WalletDetails.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct WalletDetails: View {
  let ethAddress: String
  let solanaAddress: String

  var onCopyEthAddressClick: (() -> Void)?
  var onCopySolanaAddressClick: (() -> Void)?

  var body: some View {
    VStack {
      HStack {
        Text("ETH ADDRESS:")
          .font(.headline)
          .bold()

        Button {
          onCopyEthAddressClick?()
        } label: {
          Image(systemName: "doc.on.doc")
        }
        Spacer()
      }

      LeadingText(ethAddress)
        .font(.body)
        .padding(.bottom, 10)

      HStack {
        Text("Solana ADDRESS:")
          .font(.headline)
          .bold()

        Button {
          onCopySolanaAddressClick?()
        } label: {
          Image(systemName: "doc.on.doc")
        }
        Spacer()
      }

      LeadingText(solanaAddress)
        .font(.body)
        .padding(.bottom, 10)
    }
  }
}

#Preview {
  WalletDetails(ethAddress: "ETH address should be here...", solanaAddress: "Solana address should be here...")
}

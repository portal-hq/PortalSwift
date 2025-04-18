//
//  TransactionsView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct TransactionsView: View {
  // ViewModel
  @ObservedObject private var viewModel = TransactionsViewModel()

  var body: some View {
    VStack {
      PortalButton(title: "ETH sign") {
        viewModel.ethSign()
      }
      .frame(height: 40)
      .disabled(viewModel.state == .loading)

      switch viewModel.state {
      case .loading:
        ProgressView()
      case .success(message: let message):
        Text(message)
      case .error(errorMessage: let message):
        Text(message)
      case .none:
        Text("Click the button to sign transaction")
      }
    }
    .padding()
  }
}

#Preview {
  TransactionsView()
}

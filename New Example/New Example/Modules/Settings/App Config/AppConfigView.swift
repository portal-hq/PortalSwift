//
//  AppConfigView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct AppConfigView: View {
  @ObservedObject var viewModel = AppConfigViewModel()

  var body: some View {
    VStack {
      List {
        ForEach(viewModel.appConfig, id: \.key) { config in
          HStack {
            Text("\(config.key): ")
              .font(.headline)
              .bold()
            Text(config.value)
            Spacer()
            Button {
              viewModel.copyToClipboard(for: config.key)
            } label: {
              Image(systemName: "doc.on.doc")
            }
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .listStyle(.plain)
    }
  }
}

#Preview {
  AppConfigView()
}

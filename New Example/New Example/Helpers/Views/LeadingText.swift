//
//  LeadingText.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

/// Reusable Leading Text View
struct LeadingText: View {
  let text: String
  var body: some View {
    HStack {
      Text(text)
      Spacer()
    }
  }

  init(_ text: String) {
    self.text = text
  }
}

#Preview {
  LeadingText("Wallet")
}

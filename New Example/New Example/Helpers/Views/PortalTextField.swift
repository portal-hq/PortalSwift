//
//  PortalTextField.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct PortalTextField: View {
  let placeholder: String
  @Binding var text: String
  var body: some View {
    TextField(placeholder, text: $text)
      .textInputAutocapitalization(.never)
      .frame(height: 40)
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray, lineWidth: 1))
      .multilineTextAlignment(.center)
  }
}

#Preview {
  PortalTextField(placeholder: "Enter Text", text: .constant(""))
}

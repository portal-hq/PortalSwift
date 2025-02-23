//
//  PortalButton.swift
//  PortalHackathonKit
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

enum ButtonStyle {
  case primary
  case secondary
  case negative
}

/// Reusable button View
struct PortalButton: View {
  var title: String?
  var style: ButtonStyle = .primary
  var isEnabled: Bool = true
  var onPress: (() -> Void)?
  var cornerRadius: CGFloat = 12

  var body: some View {
    GeometryReader { geometry in
      getButton(for: geometry, style: style)
    }
  }

  @ViewBuilder func getButton(for geometry: GeometryProxy, style: ButtonStyle) -> some View {
    Button {
      onPress?()
    } label: {
      Text(title ?? "")
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        .background(getBackgroundColor(for: style))
        .foregroundColor(getForegroundColor(for: style))
        .font(.headline)
    }
    .disabled(!isEnabled)
    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
    .background(getBackgroundColor(for: style))
    .foregroundColor(getForegroundColor(for: style))
    .font(.headline)
    .cornerRadius(cornerRadius)
    .clipped()
  }

  func getBackgroundColor(for style: ButtonStyle) -> Color? {
    if !isEnabled {
      return .gray.opacity(0.15)
    }
    switch style {
    case .primary:
      return .black
    case .secondary:
      return .gray
    case .negative:
      return .red
    }
  }

  func getForegroundColor(for style: ButtonStyle) -> Color? {
    if !isEnabled {
      return .gray.opacity(0.5)
    }
    switch style {
    case .primary, .negative:
      return .white
    case .secondary:
      return .black
    }
  }
}

#Preview {
  PortalButton()
    .previewLayout(.fixed(width: 200, height: 80))
}

//
//  ContentView.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    if AppState.shared.sessionMode == .anonymous {
      AuthView()
    } else {
      MainTabBar()
    }
  }
}

#Preview {
  ContentView()
}

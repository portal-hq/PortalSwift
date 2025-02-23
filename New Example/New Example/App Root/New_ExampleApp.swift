//
//  New_ExampleApp.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import SwiftUI

@main
struct New_ExampleApp: App {
  @StateObject var appState = AppState.shared

  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
      .id(appState.sessionMode)
    }
  }
}

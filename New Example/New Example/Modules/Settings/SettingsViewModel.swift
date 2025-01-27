//
//  SettingsViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation

final class SettingsViewModel: ObservableObject {
  enum Destination {
    case appConfiguration
  }

  // MARK: - UI Properties

  @Published private(set) var destination: Destination?
}

extension SettingsViewModel {
  func selectDestination(_ destination: Destination) {
    self.destination = destination
  }
}

//
//  AppState.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//
import Foundation

class AppState: ObservableObject {
  static let shared = AppState()
  @Published var sessionMode: SessionMode = .anonymous // the default is anonymous
}

enum SessionMode: String {
  case anonymous
  case authorized
}

//
//  ViewController+DebugConsole.swift
//  SPM Example
//
//  Created by Ahmed Ragab on 04/03/2026.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Pulse
import PulseUI
import SwiftUI
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  @IBAction func handleOpenDebugConsole() {
    LoggerStore.shared.storeMessage(
      label: "app",
      level: .debug,
      message: "Debug console opened"
    )
    let consoleView = NavigationView {
      ConsoleView()
        .navigationBarItems(trailing: Button("Done") {
          UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true)
        })
    }
    let hostingController = UIHostingController(rootView: consoleView)
    hostingController.modalPresentationStyle = .fullScreen
    present(hostingController, animated: true)
  }
}

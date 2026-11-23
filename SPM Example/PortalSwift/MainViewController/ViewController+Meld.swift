//
//  ViewController+Meld.swift
//  SPM Example
//
//  Created by Ahmed Ragab
//

import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  /// Opens the Meld ramps screen.
  @IBAction func openMeldRamps(_: Any) {
    guard let portal else {
      logger.error("❌ [Meld] Portal not initialized")
      showStatusView(message: "\(failureStatus) Portal not initialized")
      return
    }
    let navigationController = UINavigationController(rootViewController: MeldViewController(portal: portal))
    present(navigationController, animated: true)
  }
}

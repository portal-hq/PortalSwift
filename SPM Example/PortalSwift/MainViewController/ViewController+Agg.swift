//
//  ViewController+Agg.swift
//  SPM Example
//
//  Created by Ahmed Ragab
//

import PortalSwift
import UIKit

@available(iOS 16.0, *)
extension ViewController {
  /// Opens the Agg prediction-markets screen.
  @IBAction func openAggPredictionMarkets(_: Any) {
    guard let portal else {
      logger.error("❌ [Agg] Portal not initialized")
      showStatusView(message: "\(failureStatus) Portal not initialized")
      return
    }
    let navigationController = UINavigationController(rootViewController: AggViewController(portal: portal))
    present(navigationController, animated: true)
  }
}

//
//  WebViewController.swift
//  PortalSwift_Example
//
//  Created by Blake Williams on 7/7/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import PortalSwift
import SwiftUI

class WebViewController: UIViewController {
  public var portal: Portal?
  public var url: String?

  private var activityIndicator: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()

    // Initialize the activity indicator and add it to the view
    self.activityIndicator = UIActivityIndicatorView(style: .large)
    self.activityIndicator.color = UIColor(hex: "#3e71f8")
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(self.activityIndicator)

    NSLayoutConstraint.activate([
      self.activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      self.activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    guard let portal = self.portal else {
      print("No self.portal found")
      return
    }

    if self.portal != nil && self.url != nil {
      guard let url = URL(string: url ?? "") else {
        print("WebViewController error: URL could not be derived.")
        return
      }

      let webViewController = PortalWebView(
        portal: portal,
        url: url,
        onError: onError,
        onPageStart: onPageStart,
        onPageComplete: onPageComplete
      )

      // Install the WebViewController as a child view controller.
      addChild(webViewController)

      guard let webViewControllerView = webViewController.view else {
        print("WebViewController error: webViewController.view could not be derived.")
        return
      }

      view.addSubview(webViewControllerView)
      webViewController.didMove(toParent: self)
    }
  }

  // Ensure the activity indicator is always centered, even after layout changes
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.activityIndicator.center = view.center
  }

  func onPageStart() {
    print("🔄 PortalWebView: Page loading started")
    self.activityIndicator.startAnimating()
    view.bringSubviewToFront(self.activityIndicator)
  }

  func onPageComplete() {
    print("✅ PortalWebView: Page loading completed")
    self.activityIndicator.stopAnimating()
  }

  func onError(result: Result<Any>) {
    if let error = result.error {
      print("PortalWebviewError:", error, "Description:", error.localizedDescription)
      return
    }

    guard let dataAsAnyObject = result.data as? AnyObject,
          let nestedResult = dataAsAnyObject.result as? Result<Any>
    else {
      print("❌ Unable to cast result data")
      return
    }

    if let nestedError = nestedResult.error {
      print("❌ Error in nested PortalWebviewError:", nestedError)
      return
    }
  }
}

// UIColor extension to handle hex color strings
extension UIColor {
  convenience init(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)

    let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
    let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
    let blue = CGFloat(rgb & 0x0000FF) / 255.0
    let alpha = CGFloat(1.0)

    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }
}

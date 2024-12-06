//
//  WebViewController.swift
//  PortalSwift_Example
//
//  Created by Blake Williams on 7/7/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import PortalSwift
import WebKit

class WebViewController: UIViewController, PortalWebViewDelegate {
  var portal: Portal?
  var url: String?
  var webViewController: PortalWebView?
  let persistSessionData = false
  let eip6963Icon = EIP6963Constants.eip6963Icon
  let eip6963Name = EIP6963Constants.eip6963Name
  let eip6963Rdns = EIP6963Constants.eip6963Rdns
  let eip6963Uuid = EIP6963Constants.eip6963Uuid

  private var activityIndicator: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()
    addActivityIndicator()

    guard let portal else {
      print("❌ WebViewController error: The portal object is nil.")
      return
    }

    guard let url else {
      print("❌ WebViewController error: The url object is nil.")
      return
    }

    guard let url = URL(string: url) else {
      print("❌ WebViewController error: URL could not be derived.")
      return
    }

    webViewController = PortalWebView(
      portal: portal, // Your Portal instance.
      url: url, // The URL the web view should start at.
      persistSessionData: persistSessionData, // Will persist browser session data (local-storage, cookies, etc...) when enabled.
      onError: self.onErrorHandler, // An error handler in case the web view throws errors.
      onPageStart: self.onPageStartHandler, // A handler that fires when the web view is starting to load a page.
      onPageComplete: self.onPageCompleteHandler, // A handler that fires when the web view has finished loading a page.
      eip6963Icon: eip6963Icon, // A string representing the Base64-encoded icon for EIP-6963 compliance.
      eip6963Name: eip6963Name, // A string representing the name for EIP-6963 compliance.
      eip6963Rdns: eip6963Rdns, // A reverse DNS string for identifying the application in EIP-6963-compliant contexts.
      eip6963Uuid: eip6963Uuid // A unique identifier string for EIP-6963 compliance.
    )

    guard let webViewController = webViewController else {
      print("❌ WebViewController error: the PortalWebView object is nil.")
      return
    }

    webViewController.delegate = self

    // Install the WebViewController as a child view controller.
    addChild(webViewController)

    guard let webViewControllerView = webViewController.view else {
      print("❌ WebViewController error: webViewController.view could not be derived.")
      return
    }

    view.addSubview(webViewControllerView)
    webViewController.didMove(toParent: self)
  }

  private func addActivityIndicator() {
    // Initialize the activity indicator and add it to the view
    self.activityIndicator = UIActivityIndicatorView(style: .large)
    self.activityIndicator.color = UIColor.blue
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(self.activityIndicator)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.webViewController = nil
  }

  func onPageStartHandler() {
    print("🔄 PortalWebView: Page loading started")
    self.activityIndicator.startAnimating()
    view.bringSubviewToFront(self.activityIndicator)
  }

  func onPageCompleteHandler() {
    print("✅ PortalWebView: Page loading completed")
    self.activityIndicator.stopAnimating()
  }

  func onErrorHandler(result: Result<Any>) {
    if let error = result.error {
      print("❌ PortalWebViewError:", error, "Description:", error.localizedDescription)
      return
    }

    guard let dataAsAnyObject = result.data as? AnyObject,
          let nestedResult = dataAsAnyObject.result as? Result<Any>
    else {
      print("❌ Unable to cast result data")
      return
    }

    if let nestedError = nestedResult.error {
      print("❌ Error in nested PortalWebViewError:", nestedError)
      return
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    print("✅ Delegate method fired!", webView, navigationAction, decisionHandler)
    decisionHandler(.allow)
  }
}

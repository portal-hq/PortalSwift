//
//  PortalWebViewDelegate.swift
//  PortalSwift
//
//  Created by Blake Williams on 12/7/23.
//

import Foundation
import WebKit

public protocol PortalWebViewDelegate: NSObjectProtocol {
  /** @abstract Decides whether to allow or cancel a navigation.
   @param webView The web view invoking the delegate method.
   @param navigationAction Descriptive information about the action
   triggering the navigation request.
   @param decisionHandler The decision handler to call to allow or cancel the
   navigation. The argument is one of the constants of the enumerated type WKNavigationActionPolicy.
   @discussion If you do not implement this method, the web view will load the request or, if appropriate, forward it to another application.
   */
  @available(iOS 8.0, *)
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
}

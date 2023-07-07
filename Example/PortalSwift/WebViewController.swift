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

  override func viewDidLoad() {
    super.viewDidLoad()

    if portal != nil && url != nil {
      let webViewController = PortalWebView(portal: portal!, url: URL(string: url!)!, onError: onError)
      // Install the WebViewController as a child view controller.
      addChild(webViewController)
      let webViewControllerView = webViewController.view!
      view.addSubview(webViewControllerView)
      webViewController.didMove(toParent: self)
    }
  }

  func onError(result: Result<Any>) {
    print("PortalWebviewError:", result.error!, "Description:", result.error!.localizedDescription)
    guard result.error == nil else {
      print("❌ Error in PortalWebviewError:", result.error)
      return
    }
    guard ((result.data! as AnyObject).result as! Result<Any>).error == nil else {
      print("❌ Error in PortalWebviewError:", (result.data as! AnyObject).result as! Result<Any>)
      return
    }
  }
}

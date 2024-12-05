//
//  PortalWebView.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import WebKit

/// The expected response from portal.provider.request
public struct PortalProviderResponse: Codable {
  public var data: String
  public var error: String
}

/// The result of PortalMessageBody.data
public struct PortalMessageBodyData {
  public var method: String
  public var params: [Any]
}

/// The unpacked WKScriptMessage.
public struct PortalMessageBody {
  public var data: PortalMessageBodyData
  public var type: String
}

/// The errors the web view controller can throw.
enum WebViewControllerErrors: LocalizedError {
  case unparseableMessage
  case MissingFieldsForEIP1559Transation
  case unknownMessageType(type: String)
  case dataNilError
  case invalidResponseType
  case signatureNilError
}

/// A controller that allows you to create Portal's web view.
open class PortalWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
  public var chainId: Int
  public var delegate: PortalWebViewDelegate?
  public var webView: WKWebView!
  public var webViewContentIsLoaded = false

  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private var eip6963Icon: String
  private var eip6963Name: String
  private var eip6963Rdns: String
  private var eip6963Uuid: String
  private var portal: Portal
  private var url: URL
  private var onError: (Result<Any>) -> Void
  private var onPageStart: (() -> Void)?
  private var onPageComplete: (() -> Void)?

  /// The constructor for Portal's PortalWebView.
  /// - Parameters:
  ///   - portal: Your Portal instance.
  ///   - url: The URL the web view should start at.
  ///   - persistSessionData: Will persist browser session data (local-storage, cookies, etc...) when enabled.
  ///   - onError: An error handler in case the web view throws errors.
  ///   - onPageStart: A handler that fires when the web view is starting to load a page.
  ///   - onPageComplete: A handler that fires when the web view has finished loading a page.
  ///   - eip6963Icon: A string representing the Base64-encoded icon for EIP-6963 compliance.
  ///   - eip6963Name: A string representing the name for EIP-6963 compliance.
  ///   - eip6963Rdns: A reverse DNS string for identifying the application in EIP-6963-compliant contexts.
  ///   - eip6963Uuid: A unique identifier string for EIP-6963 compliance.
  public init(
    portal: Portal,
    url: URL,
    persistSessionData: Bool = false,
    onError: @escaping (Result<Any>) -> Void,
    onPageStart: (() -> Void)? = nil,
    onPageComplete: (() -> Void)? = nil,
    eip6963Icon: String = EIP6963Constants.eip6963Icon,
    eip6963Name: String = EIP6963Constants.eip6963Name,
    eip6963Rdns: String = EIP6963Constants.eip6963Rdns,
    eip6963Uuid: String = EIP6963Constants.eip6963Uuid
  ) {
    self.chainId = portal.chainId ?? 11_155_111
    self.eip6963Icon = eip6963Icon
    self.eip6963Name = eip6963Name
    self.eip6963Rdns = eip6963Rdns
    self.eip6963Uuid = eip6963Uuid
    self.portal = portal
    self.url = url
    self.onError = onError
    self.onPageStart = onPageStart
    self.onPageComplete = onPageComplete

    super.init(nibName: nil, bundle: nil)

    guard let address = portal.address else {
      print("[PortalWebView] No address found for user. Cannot inject provider into web page.")
      return
    }
    do {
      self.webView = try self.initWebView(address: address, persistSessionData: persistSessionData)
      self.bindPortalEvents(portal: portal)
    } catch {
      print("Error initializing WebView: ❌ \(error.localizedDescription)")
    }
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func bindPortalEvents(portal: Portal) {
    portal.on(event: Events.ChainChanged.rawValue) { data in
      if let data = data as? [String: String] {
        let chainIdString = data["chainId"] ?? "0" // Get the string value, defaulting to "0" if nil

        guard let chainId = Int(chainIdString, radix: 16) else {
          print("[PortalWebView] Invalid chainId provided to `portal_chainChanged` event. Ignoring...")
          return
        }

        self.updateWebViewChain(chainId: chainId)
      }
    }
  }

  /// When the view loads, add the web view as a subview. Also add default configuration values for the web view.
  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(self.webView)

    self.webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.webView.topAnchor.constraint(equalTo: view.topAnchor),
      self.webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      self.webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      self.webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
  }

  /// When the view will appear, load the web view to the url.
  /// - Parameter animated: Determines if the view will be animated when appearing or not.
  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !self.webViewContentIsLoaded {
      let request = URLRequest(url: url)

      self.webView.load(request)

      self.webViewContentIsLoaded = true
    }
  }

  private func initWebView(address: String, persistSessionData: Bool = false, debugEnabled _: Bool = false) throws -> WKWebView {
    let gatewayConfig: [Int: String] = Dictionary(portal.rpcConfig.map { key, value in
      let chainIdParts = key.split(separator: ":").map(String.init)
      let newKey = Int(chainIdParts[1]) ?? 1
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })

    guard let rpcUrl = gatewayConfig[chainId] else {
      throw PortalWebViewError.unexpectedError("❌ No rpc url found for chainId: \(self.chainId)")
    }

    // build WKUserScript
    let scriptSource = self.injectPortal(
      address: address,
      apiKey: self.portal.apiKey,
      chainId: String(self.portal.chainId ?? 11_155_111),
      gatewayConfig: rpcUrl,
      eip6963Icon: self.eip6963Icon,
      eip6963Name: self.eip6963Name,
      eip6963Rdns: self.eip6963Rdns,
      eip6963Uuid: self.eip6963Uuid,
      autoApprove: self.portal.autoApprove,
      enableMpc: true
    )

    let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    // build the WekUserContentController
    let contentController = WKUserContentController()
    contentController.addUserScript(script)
    contentController.add(self, name: "WebViewControllerMessageHandler")

    // build the WKWebViewConfiguration
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController

    // Allows for data persistence across sessions
    if persistSessionData {
      configuration.websiteDataStore = WKWebsiteDataStore.default()
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.bounces = false
    webView.navigationDelegate = self
    webView.uiDelegate = self

    // Enable debugging the webview in Safari.
    // #if directive used  to start a conditional compilation block.
    // @WARNING: Uncomment this section to enable debugging in Safari.
    #if canImport(UIKit)
      #if targetEnvironment(simulator)
        if #available(iOS 16.4, *) {
          webView.isInspectable = true
        }
      #endif
    #endif

    return webView
  }

  private func evaluateJavascript(_ javascript: String, sourceURL: String? = nil, completion: ((_ error: String?) -> Void)? = nil) {
    var javascript = javascript

    // Adding a sourceURL comment makes the javascript source visible when debugging the simulator via Safari in Mac OS
    if let sourceURL {
      javascript = "//# sourceURL=\(sourceURL).js\n" + javascript
    }

    DispatchQueue.main.async {
      self.webView.evaluateJavaScript(javascript) { _, error in
        completion?(error?.localizedDescription)
      }
    }
  }

  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    self.delegate?.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
  }

  /// Called when the web view starts loading a new page.
  /// - Parameters:
  ///   - webView: The WKWebView instance that started loading.
  ///   - navigation: The navigation information associated with the event.
  public func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
    self.onPageStart?()
  }

  /// Called when the web view finishes loading a page.
  /// - Parameters:
  ///   - webView: The WKWebView instance that finished loading.
  ///   - navigation: The navigation information associated with the event.
  public func webView(_: WKWebView, didFinish _: WKNavigation!) {
    self.onPageComplete?()
  }

  /// Called when a new tab is opened.
  public func webView(_ webView: WKWebView, createWebViewWith _: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
    if navigationAction.targetFrame == nil {
      webView.load(navigationAction.request)

      // if we instead wanted to open a new tab in Safari instead
      // of the current WebView we can use this line
      // UIApplication.shared.open(navigationAction.request.url!, options: [:])
    }
    return nil
  }

  /// The controller used to handle messages to and from the web view.
  /// - Parameters:
  ///   - userContentController: The WKUserContentController instance.
  ///   - message: The message received from the web view.
  public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
    do {
      let portalMessageBody = try unpackWKScriptMessage(message: message)

      switch portalMessageBody.type as String {
      case "portal_sign":
        if TransactionMethods.contains(portalMessageBody.data.method) {
          try self.handlePortalSignTransaction(method: portalMessageBody.data.method, params: portalMessageBody.data.params)
        } else {
          try self.handlePortalSign(method: portalMessageBody.data.method, params: portalMessageBody.data.params)
        }
      default:
        self.onError(Result(error: WebViewControllerErrors.unknownMessageType(type: portalMessageBody.type)))
      }
    } catch {
      self.onError(Result(error: error))
    }
  }

  private func unpackWKScriptMessage(message: WKScriptMessage) throws -> PortalMessageBody {
    // Convert the message to a JSON dictionary.
    let bodyString = message.body as? String
    let bodyData = bodyString!.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

    // Unpack what we need from the message.
    let data = json["data"]! as! [String: Any]
    let type = json["type"]! as! String
    let method = data["method"]! as! String
    let params = data["params"]! as! [Any]

    return PortalMessageBody(data: PortalMessageBodyData(method: method, params: params), type: type)
  }

  private func handlePortalSign(method: String, params: [Any]) throws {
    // Perform a long-running task
    let encodedParams = params.map { param in
      AnyCodable(param)
    }
    let payload = ETHRequestPayload(
      method: method,
      params: encodedParams,
      chainId: chainId
    )

    if method == PortalRequestMethod.wallet_switchEthereumChain.rawValue {
      try self.handleWalletSwitchEthereumChain(method: method, params: params)
    } else if signerMethods.contains(method) {
      self.portal.provider.request(payload: payload, completion: self.signerRequestCompletion, connect: nil)
    } else {
      self.portal.provider.request(payload: payload, completion: self.gatewayRequestCompletion, connect: nil)
    }
  }

  private func handlePortalSignTransaction(method: String, params: [Any]) throws {
    let firstParams = params.first! as! [String: String]
    let transactionParam: ETHTransactionParam
    if firstParams["maxPriorityFeePerGas"] != nil, firstParams["maxFeePerGas"] != nil {
      guard firstParams["maxPriorityFeePerGas"]!.isEmpty || firstParams["maxFeePerGas"]!.isEmpty else {
        throw WebViewControllerErrors.MissingFieldsForEIP1559Transation
      }
      transactionParam = ETHTransactionParam(
        from: firstParams["from"]!,
        to: firstParams["to"]!,
        gas: firstParams["gas"] ?? "",
        value: firstParams["value"] ?? "0x0",
        data: firstParams["data"]!,
        maxPriorityFeePerGas: firstParams["maxPriorityFeePerGas"] ?? "",
        maxFeePerGas: firstParams["maxFeePerGas"] ?? ""
      )
    } else {
      transactionParam = ETHTransactionParam(
        from: firstParams["from"]!,
        to: firstParams["to"]!,
        gas: firstParams["gas"] ?? "",
        gasPrice: firstParams["gasPrice"] ?? "",
        value: firstParams["value"] ?? "0x0",
        data: firstParams["data"]!
      )
    }
    let payload = ETHTransactionPayload(method: method, params: [transactionParam], chainId: chainId)

    if signerMethods.contains(method) {
      self.portal.provider.request(payload: payload, completion: self.signerTransactionRequestCompletion, connect: nil)
    } else {
      self.portal.provider.request(payload: payload, completion: self.gatewayTransactionRequestCompletion, connect: nil)
    }
  }

  private func signerTransactionRequestCompletion(result: Result<TransactionCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))

      if let error = error as? ProviderSigningError {
        print("Received a ProviderSigningError: \(error)")

        if error == ProviderSigningError.userDeclinedApproval {
          print("Received userDeclinedApproval. Sending rejection to dApp.")

          // Handle Signature Rejection
          let javascript = "window.postMessage(JSON.stringify({ type: 'portal_signingRejected', data: {} }));"
          self.evaluateJavascript(javascript)
        }
      }

      return
    }

    guard let signature = result.data!.result as? String else {
      self.onError(Result(error: PortalWebViewError.unexpectedError("Unable to parse signature for request")))
      return
    }
    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params.map { p in
        [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data
        ]
      }),
      "signature": AnyCodable(signature)
    ]
    self.postMessage(payload: payload)
  }

  private func handleWalletSwitchEthereumChain(method: String, params: [Any]) throws {
    let encodedParams = try JSONSerialization.data(withJSONObject: params)
    let params = try decoder.decode([ChainChangedParam].self, from: encodedParams)

    print("⚠️ Params: \(params)")

    let rawChainId = params[0].chainId

    print("⚠️ Raw Chain ID: \(rawChainId)")
    let chainId = try parseRawChainId(rawChainId: rawChainId)

    print("⚠️ Chain ID: \(chainId)")

    // Set the chainId locally
    self.chainId = chainId

    self.updateWebViewChain(chainId: chainId)

    let jsonData = "[{ \"chainId\": \"\(rawChainId)\" }]"

    let signatureReceivedJavascript = """
      window.postMessage(JSON.stringify({ type: 'portal_signatureReceived', data: { method: '\(method)', params: \(jsonData) }, signature: "null" }))
    """

    print("⚠️ Signature Received JS: \(signatureReceivedJavascript)")
    self.evaluateJavascript(signatureReceivedJavascript)
  }

  private func updateWebViewChain(chainId: Int) {
    // Set the chainId in the WebView
    let chainChangedJavascript = """
      window.postMessage(JSON.stringify({ type: 'portal_chainChanged', data: { chainId: \(chainId) } }));
    """
    self.evaluateJavascript(chainChangedJavascript)

    // Update the RPC URL
    if let rpcUrl = portal.rpcConfig["eip155:\(chainId)"] {
      let updateRpcUrlJavascript = """
        window.postMessage(JSON.stringify({ type: 'portal_updateRpcUrl', data: { rpcUrl: '\(rpcUrl)' } }))
      """
      self.evaluateJavascript(updateRpcUrlJavascript)
    }
  }

  private func gatewayTransactionRequestCompletion(result: Result<TransactionCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params.map { p in
        [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data
        ]
      }),
      "signature": AnyCodable(result.data!.result)
    ]
    self.postMessage(payload: payload)
  }

  private func parseRawChainId(rawChainId: String) throws -> Int {
    let chainId = if rawChainId.starts(with: "0x") {
      Int(rawChainId.replacingOccurrences(of: "0x", with: ""), radix: 16)
    } else {
      Int(rawChainId)
    }

    guard let chainId = chainId else {
      throw ProviderInvalidArgumentError.invalidParamsForSwitchingChain
    }

    return chainId
  }

  private func signerRequestCompletion(result: Result<RequestCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    guard let requestData = result.data else {
      self.onError(Result(error: WebViewControllerErrors.dataNilError))
      return
    }

    guard let signature = requestData.result as? String else {
      self.onError(Result(error: WebViewControllerErrors.invalidResponseType))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(requestData.method),
      "params": AnyCodable(requestData.params),
      "signature": AnyCodable(signature)
    ]
    self.postMessage(payload: payload)
  }

  private func gatewayRequestCompletion(result: Result<RequestCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params),
      "signature": AnyCodable(result.data!.result)
    ]
    self.postMessage(payload: payload)
  }

  private func postMessage(payload: [String: AnyCodable]) {
    do {
      let data = try encoder.encode(payload)
      let dataString = String(data: data, encoding: .utf8)
      let javascript = "window.postMessage(JSON.stringify({ type: 'portal_signatureReceived', data: \(dataString!) }));"

      self.evaluateJavascript(javascript, sourceURL: "portal_sign")
    } catch {
      self.onError(Result(error: error))
    }
  }

  private func injectPortal(
    address: String,
    apiKey _: String,
    chainId: String,
    gatewayConfig: String,
    eip6963Icon: String,
    eip6963Name: String,
    eip6963Rdns: String,
    eip6963Uuid: String,
    autoApprove: Bool = false,
    enableMpc: Bool = true
  ) -> String {
    "window.portalAddress='\(address)';window.portalApiKey='';window.portalAutoApprove=\(String(autoApprove));window.portalChainId='\(chainId)';window.portalGatewayConfig='\(gatewayConfig)';window.portalMPCEnabled='\(String(enableMpc))';window.portalEIP6963Uuid='\(eip6963Uuid)';window.portalEIP6963Name='\(eip6963Name)';window.portalEIP6963Rdns='\(eip6963Rdns)';window.portalEIP6963Icon='\(eip6963Icon)';\(PortalInjectionScript.SCRIPT)true"
  }
}

public struct ChainChangedParam: Codable {
  public let chainId: String
}

enum PortalWebViewError: LocalizedError {
  case unexpectedError(String)
}

struct WalletSwitchEthereumChainParam {
  let chainId: Int
}

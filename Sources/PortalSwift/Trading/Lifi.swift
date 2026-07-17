//
//  Lifi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// Protocol defining the interface for Lifi trading provider functionality.
public protocol LifiProtocol {
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse
  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse
  func tradeAsset(params: LifiTradeAssetParams) async throws -> LifiTradeAssetResult
  func pollStatus(
    request: LifiStatusRequest,
    onUpdate: ((LifiStatusRawResponse) -> Bool)?,
    options: LifiPollStatusOptions
  ) async throws -> LifiStatusRawResponse
}

public extension LifiProtocol {
  /// Convenience overload that polls with default options and no update callback.
  func pollStatus(request: LifiStatusRequest) async throws -> LifiStatusRawResponse {
    return try await pollStatus(request: request, onUpdate: nil, options: LifiPollStatusOptions())
  }

  /// Convenience overload that polls with custom options and no update callback.
  func pollStatus(request: LifiStatusRequest, options: LifiPollStatusOptions) async throws -> LifiStatusRawResponse {
    return try await pollStatus(request: request, onUpdate: nil, options: options)
  }

  /// Convenience overload that polls with an update callback and default options.
  func pollStatus(
    request: LifiStatusRequest,
    onUpdate: @escaping (LifiStatusRawResponse) -> Bool
  ) async throws -> LifiStatusRawResponse {
    return try await pollStatus(request: request, onUpdate: onUpdate, options: LifiPollStatusOptions())
  }
}

/// Lifi provider implementation for trading functionality.
public class Lifi: LifiProtocol {
  /// The smallest interval, in milliseconds, allowed between status polls (guards against busy-waiting).
  private static let minPollIntervalMs = 100

  /// The largest millisecond value that can be converted to nanoseconds without overflowing `UInt64`.
  private static let maxSleepMs = Int(UInt64.max / 1_000_000)

  /// Converts a millisecond duration into nanoseconds for `Task.sleep`, clamping to a non-negative
  /// value that can't overflow `UInt64` when multiplied by 1_000_000.
  private static func sleepNanoseconds(fromMs ms: Int) -> UInt64 {
    return UInt64(min(max(0, ms), maxSleepMs)) * 1_000_000
  }

  private let api: PortalLifiTradingApiProtocol
  private let signAndSendTransaction: LifiSignAndSendTransaction?
  private let waitForConfirmation: LifiWaitForConfirmation?
  private let stepPollOptions: LifiPollStatusOptions
  private let logger = PortalLogger.shared

  /// Create an instance of Lifi.
  /// - Parameters:
  ///   - api: The PortalLifiTradingApi instance to use for trading operations.
  ///   - signAndSendTransaction: Closure that signs and submits an EVM transaction (injected by Portal).
  ///   - waitForConfirmation: Closure that waits for on-chain confirmation (injected by Portal).
  ///   - stepPollOptions: Polling configuration used per-step while executing `tradeAsset`.
  public init(
    api: PortalLifiTradingApiProtocol,
    signAndSendTransaction: LifiSignAndSendTransaction? = nil,
    waitForConfirmation: LifiWaitForConfirmation? = nil,
    stepPollOptions: LifiPollStatusOptions = LifiPollStatusOptions(everyMs: 10_000, initialDelayMs: 10_000, timeoutMs: 600_000)
  ) {
    self.api = api
    self.signAndSendTransaction = signAndSendTransaction
    self.waitForConfirmation = waitForConfirmation
    self.stepPollOptions = stepPollOptions
  }

  /// Retrieves routes from the Lifi integration.
  public func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    return try await api.getRoutes(request: request)
  }

  /// Retrieves a quote from the Lifi integration.
  public func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    return try await api.getQuote(request: request)
  }

  /// Retrieves the status of a transaction from the Lifi integration.
  public func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    return try await api.getStatus(request: request)
  }

  /// Retrieves an unsigned transaction from the Lifi integration that has yet to be signed/submitted.
  public func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    return try await api.getRouteStep(request: request)
  }

  /// High-level bridging method that fetches routes, executes each step sequentially
  /// (sign, confirm on-chain, poll LiFi status until terminal), and returns the resulting
  /// transaction hashes, executed steps, and the selected route.
  /// - Parameter params: The parameters describing the desired trade.
  /// - Returns: A `LifiTradeAssetResult` containing the executed transaction hashes, steps, and route.
  public func tradeAsset(params: LifiTradeAssetParams) async throws -> LifiTradeAssetResult {
    let report: (LifiTradeAssetProgressStatus, LifiTradeAssetProgressData) -> Void = { status, data in
      params.onProgress?(status, data)
    }

    do {
      return try await executeTradeAsset(params: params, report: report)
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      report(.failed, LifiTradeAssetProgressData(errorMessage: message))
      throw error
    }
  }

  /// Polls the LiFi status for a transfer until it reaches a terminal state (DONE / FAILED) or times out.
  /// - Parameters:
  ///   - request: The status request describing which transfer to poll.
  ///   - onUpdate: Optional callback invoked on each non-terminal status. Return `false` to stop polling.
  ///   - options: Polling configuration (interval, initial delay, timeout).
  /// - Returns: The terminal `LifiStatusRawResponse`.
  public func pollStatus(
    request: LifiStatusRequest,
    onUpdate: ((LifiStatusRawResponse) -> Bool)?,
    options: LifiPollStatusOptions
  ) async throws -> LifiStatusRawResponse {
    return try await pollStatusUntilTerminal(request: request, options: options, onUpdate: onUpdate)
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func executeTradeAsset(
    params: LifiTradeAssetParams,
    report: @escaping (LifiTradeAssetProgressStatus, LifiTradeAssetProgressData) -> Void
  ) async throws -> LifiTradeAssetResult {
    guard let signAndSend = signAndSendTransaction else {
      throw LifiTradeAssetError.missingSigner
    }
    guard let waitForConfirmation = waitForConfirmation else {
      throw LifiTradeAssetError.missingConfirmation
    }

    report(.fetchingRoutes, LifiTradeAssetProgressData())

    let routesRequest = LifiRoutesRequest(
      fromChainId: params.fromChain,
      fromAmount: params.amount,
      fromTokenAddress: params.fromToken,
      toChainId: params.toChain,
      toTokenAddress: params.toToken,
      fromAddress: params.fromAddress,
      // Honor the documented behavior: when no recipient is provided, fall back to the sender.
      toAddress: params.toAddress ?? params.fromAddress
    )

    let routesResponse = try await api.getRoutes(request: routesRequest)
    guard let routes = routesResponse.data?.rawResponse.routes, !routes.isEmpty else {
      throw LifiTradeAssetError.noRoutesFound
    }

    let routeIndex = params.routeIndex ?? 0
    guard routeIndex >= 0, routeIndex < routes.count else {
      throw LifiTradeAssetError.routeIndexOutOfBounds
    }

    let route = routes[routeIndex]
    guard !route.steps.isEmpty else {
      throw LifiTradeAssetError.routeHasNoSteps
    }

    let totalSteps = route.steps.count
    report(.routeSelected, LifiTradeAssetProgressData(routeIndex: routeIndex, totalSteps: totalSteps, route: route))

    var hashes: [String] = []
    var executedSteps: [LifiStep] = []

    for (stepIndex, step) in route.steps.enumerated() {
      report(.preparingStep, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: step))

      let stepResponse = try await api.getRouteStep(request: step)
      guard let rawStep = stepResponse.data?.rawResponse else {
        throw LifiTradeAssetError.missingTransactionRequest
      }
      executedSteps.append(rawStep)

      guard let transactionRequest = rawStep.transactionRequest,
            let txParams = transactionRequest.value as? [String: Any]
      else {
        throw LifiTradeAssetError.missingTransactionRequest
      }

      let ethTransaction = try parseLifiTransactionRequest(txParams)
      let network = resolveStepNetworkCaip2(step: rawStep, txParams: txParams)

      report(.signing, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep))

      let txHash = try await signAndSend(ethTransaction, network)
      hashes.append(txHash)

      report(.submitted, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep, txHash: txHash))
      report(.confirming, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep, txHash: txHash))

      let confirmation = try await waitForConfirmation(txHash, network)
      switch confirmation {
      case .confirmed:
        break
      case .reverted:
        throw LifiTradeAssetError.transactionConfirmationFailed(txHash)
      case .timedOut:
        throw LifiTradeAssetError.transactionConfirmationTimedOut(txHash)
      }

      report(.lifiPending, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep, txHash: txHash))

      let statusRequest = LifiStatusRequest(
        txHash: txHash,
        bridge: statusBridgeFromTool(rawStep.tool),
        fromChain: rawStep.action.fromChainId,
        toChain: rawStep.action.toChainId
      )

      let terminal = try await pollStatusUntilTerminal(
        request: statusRequest,
        options: stepPollOptions,
        onUpdate: { raw in
          report(.lifiPending, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep, txHash: txHash, lifiStatus: raw))
          return true
        }
      )

      report(.stepDone, LifiTradeAssetProgressData(routeIndex: routeIndex, stepIndex: stepIndex, totalSteps: totalSteps, route: route, step: rawStep, txHash: txHash, lifiStatus: terminal))
    }

    report(.complete, LifiTradeAssetProgressData(routeIndex: routeIndex, totalSteps: totalSteps, route: route))

    return LifiTradeAssetResult(hashes: hashes, steps: executedSteps, route: route)
  }

  private func pollStatusUntilTerminal(
    request: LifiStatusRequest,
    options: LifiPollStatusOptions,
    onUpdate: ((LifiStatusRawResponse) -> Bool)?
  ) async throws -> LifiStatusRawResponse {
    let startTime = Date()

    // Clamp interval/delay so the UInt64 conversions below can't trap on negatives and a
    // zero/negative `everyMs` can't turn the loop into a busy-wait.
    let initialDelayMs = max(0, options.initialDelayMs)
    let pollIntervalMs = max(Self.minPollIntervalMs, options.everyMs)

    if initialDelayMs > 0 {
      // Use `try` (not `try?`) so task cancellation propagates during the initial delay.
      try await Task.sleep(nanoseconds: Self.sleepNanoseconds(fromMs: initialDelayMs))
    }

    while true {
      try Task.checkCancellation()

      if Date().timeIntervalSince(startTime) > Double(options.timeoutMs) / 1000.0 {
        throw LifiTradeAssetError.pollTimeout
      }

      do {
        let response = try await api.getStatus(request: request)
        if let raw = response.data?.rawResponse {
          switch raw.status {
          case .done:
            return raw
          case .failed:
            let detail = raw.substatusMessage ?? raw.substatus?.rawValue ?? "LiFi transfer FAILED"
            throw LifiTradeAssetError.lifiTransferFailed(detail)
          default:
            if let onUpdate = onUpdate {
              let carryOn = onUpdate(raw)
              if !carryOn {
                return raw
              }
            }
          }
        }
      } catch let error as LifiTradeAssetError {
        // Terminal/programmer errors should propagate; transient network errors are retried below.
        throw error
      } catch is CancellationError {
        // Cancellation must stop polling immediately rather than being treated as transient.
        throw CancellationError()
      } catch {
        logger.warn("Lifi.pollStatus() - transient error, will retry: \(error.localizedDescription)")
      }

      // Use `try` (not `try?`) so task cancellation propagates between polls.
      try await Task.sleep(nanoseconds: Self.sleepNanoseconds(fromMs: pollIntervalMs))
    }
  }

  /// Parses a LiFi step's `transactionRequest` dictionary into an `ETHTransactionParam`.
  private func parseLifiTransactionRequest(_ txParams: [String: Any]) throws -> ETHTransactionParam {
    guard let from = txParams["from"] as? String,
          let to = txParams["to"] as? String
    else {
      throw LifiTradeAssetError.invalidTransactionRequest
    }

    var value = "0x0"
    if let valueString = txParams["value"] as? String {
      value = valueString
    } else if let valueInt = txParams["value"] as? Int, valueInt >= 0 {
      // Use %llx (64-bit) so large wei amounts are not truncated like %x (32-bit) would.
      value = String(format: "0x%llx", UInt64(valueInt))
    } else if let valueDouble = txParams["value"] as? Double {
      // Some decoders surface JSON numbers as Double. EVM `value` is an integer wei amount, so
      // reject fractional/out-of-range values rather than silently truncating to a wrong amount.
      guard valueDouble >= 0,
            valueDouble <= Double(UInt64.max),
            valueDouble.rounded(.towardZero) == valueDouble
      else {
        throw LifiTradeAssetError.invalidTransactionRequest
      }
      value = String(format: "0x%llx", UInt64(valueDouble))
    }

    let data = txParams["data"] as? String ?? "0x"

    var ethTransaction = ETHTransactionParam(from: from, to: to, value: value, data: data)

    // Map gasLimit -> gas; leave nonce nil so multi-step trades get a fresh nonce per step.
    if let gasLimit = txParams["gasLimit"] as? String {
      ethTransaction.gas = gasLimit
    } else if let gas = txParams["gas"] as? String {
      ethTransaction.gas = gas
    }
    if let gasPrice = txParams["gasPrice"] as? String {
      ethTransaction.gasPrice = gasPrice
    }
    if let maxFeePerGas = txParams["maxFeePerGas"] as? String {
      ethTransaction.maxFeePerGas = maxFeePerGas
    }
    if let maxPriorityFeePerGas = txParams["maxPriorityFeePerGas"] as? String {
      ethTransaction.maxPriorityFeePerGas = maxPriorityFeePerGas
    }

    return ethTransaction
  }

  /// Resolves the CAIP-2 network identifier for a step, preferring the transaction request's
  /// chainId and falling back to the step's action.fromChainId.
  private func resolveStepNetworkCaip2(step: LifiStep, txParams: [String: Any]?) -> String {
    var raw: String?
    if let chainIdValue = txParams?["chainId"] {
      if let intValue = chainIdValue as? Int {
        raw = String(intValue)
      } else if let stringValue = chainIdValue as? String {
        raw = stringValue
      } else if let doubleValue = chainIdValue as? Double,
                doubleValue.rounded(.towardZero) == doubleValue,
                doubleValue >= Double(Int.min), doubleValue <= Double(Int.max) {
        // Only accept an integral, in-range Double; anything else falls back to the step's chain.
        raw = String(Int(doubleValue))
      }
    }
    if raw == nil {
      raw = step.action.fromChainId
    }
    return normalizeToCaip2(raw ?? "")
  }

  /// Normalizes a chain identifier into CAIP-2 form (e.g. "8453" -> "eip155:8453").
  private func normalizeToCaip2(_ value: String) -> String {
    if value.hasPrefix("eip155:") || value.hasPrefix("solana:") {
      return value
    }
    if value.hasPrefix("0x"), let intValue = Int(value.dropFirst(2), radix: 16) {
      return "eip155:\(intValue)"
    }
    return "eip155:\(value)"
  }

  /// Maps a LiFi tool string to a `LifiStatusBridge`, if it corresponds to a known bridge.
  private func statusBridgeFromTool(_ tool: String) -> LifiStatusBridge? {
    return LifiStatusBridge(rawValue: tool)
  }
}

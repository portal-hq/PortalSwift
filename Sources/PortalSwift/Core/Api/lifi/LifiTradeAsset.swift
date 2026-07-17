//
//  LifiTradeAsset.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2025 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Closure invoked with progress updates while `tradeAsset` executes.
public typealias LifiProgressHandler = (_ status: LifiTradeAssetProgressStatus, _ data: LifiTradeAssetProgressData) -> Void

/// Closure that signs and submits an EVM transaction, returning the transaction hash.
public typealias LifiSignAndSendTransaction = (_ transaction: ETHTransactionParam, _ chainId: String) async throws -> String

/// The outcome of waiting for an on-chain transaction confirmation.
public enum LifiConfirmationResult: Equatable {
  /// The transaction was mined and reported a success status.
  case confirmed
  /// The transaction was mined but reverted (receipt status != 0x1).
  case reverted
  /// Confirmation could not be determined within the allotted attempts (still pending or the node
  /// was unreachable). This is distinct from a definitive on-chain revert.
  case timedOut
}

/// Closure that waits for an on-chain transaction confirmation.
/// Throws `CancellationError` if the surrounding task is cancelled so polling can stop promptly.
public typealias LifiWaitForConfirmation = (_ txHash: String, _ chainId: String) async throws -> LifiConfirmationResult

/// Parameters for the high-level `tradeAsset` bridging method.

// MARK: - LifiTradeAssetParams

public struct LifiTradeAssetParams {
  /// The sending chain. Can be the chain id or chain key (e.g. "8453").
  public let fromChain: String
  /// The receiving chain. Can be the chain id or chain key (e.g. "137").
  public let toChain: String
  /// The token that should be transferred. Can be the address or the symbol.
  public let fromToken: String
  /// The token that should be transferred to. Can be the address or the symbol.
  public let toToken: String
  /// The amount that should be sent including all decimals.
  public let amount: String
  /// The sending wallet address.
  public let fromAddress: String?
  /// The receiving wallet address. If none is provided, the fromAddress will be used.
  public let toAddress: String?
  /// The index of the route to execute from the routes response (defaults to 0).
  public let routeIndex: Int?
  /// Optional callback that receives progress updates as the trade executes.
  public let onProgress: LifiProgressHandler?

  public init(
    fromChain: String,
    toChain: String,
    fromToken: String,
    toToken: String,
    amount: String,
    fromAddress: String? = nil,
    toAddress: String? = nil,
    routeIndex: Int? = nil,
    onProgress: LifiProgressHandler? = nil
  ) {
    self.fromChain = fromChain
    self.toChain = toChain
    self.fromToken = fromToken
    self.toToken = toToken
    self.amount = amount
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.routeIndex = routeIndex
    self.onProgress = onProgress
  }
}

/// The result of a successful `tradeAsset` execution.

// MARK: - LifiTradeAssetResult

public struct LifiTradeAssetResult {
  /// One transaction hash per executed step, in execution order.
  public let hashes: [String]
  /// The enriched steps (with populated transactionRequest) that were executed.
  public let steps: [LifiStep]
  /// The route that was selected and executed.
  public let route: LifiRoute

  public init(hashes: [String], steps: [LifiStep], route: LifiRoute) {
    self.hashes = hashes
    self.steps = steps
    self.route = route
  }
}

/// Progress status values emitted by `tradeAsset` via the `onProgress` callback.

// MARK: - LifiTradeAssetProgressStatus

public enum LifiTradeAssetProgressStatus: String {
  /// Emitted before requesting routes.
  case fetchingRoutes = "fetching_routes"
  /// Emitted once a route has been selected.
  case routeSelected = "route_selected"
  /// Emitted before requesting the transaction details for a step.
  case preparingStep = "preparing_step"
  /// Emitted before signing and submitting a step's transaction.
  case signing
  /// Emitted after a step's transaction hash has been returned.
  case submitted
  /// Emitted before waiting for on-chain confirmation.
  case confirming
  /// Emitted while polling the LiFi status for a step.
  case lifiPending = "lifi_pending"
  /// Emitted once a step has reached a terminal LiFi status.
  case stepDone = "step_done"
  /// Emitted once all steps have completed.
  case complete
  /// Emitted when the trade fails.
  case failed
}

/// Contextual data passed alongside a progress status.

// MARK: - LifiTradeAssetProgressData

public struct LifiTradeAssetProgressData {
  public var routeIndex: Int?
  public var stepIndex: Int?
  public var totalSteps: Int?
  public var route: LifiRoute?
  public var step: LifiStep?
  public var txHash: String?
  public var lifiStatus: LifiStatusRawResponse?
  public var errorMessage: String?

  public init(
    routeIndex: Int? = nil,
    stepIndex: Int? = nil,
    totalSteps: Int? = nil,
    route: LifiRoute? = nil,
    step: LifiStep? = nil,
    txHash: String? = nil,
    lifiStatus: LifiStatusRawResponse? = nil,
    errorMessage: String? = nil
  ) {
    self.routeIndex = routeIndex
    self.stepIndex = stepIndex
    self.totalSteps = totalSteps
    self.route = route
    self.step = step
    self.txHash = txHash
    self.lifiStatus = lifiStatus
    self.errorMessage = errorMessage
  }
}

/// Options controlling the LiFi status polling behavior.

// MARK: - LifiPollStatusOptions

public struct LifiPollStatusOptions {
  /// The interval between status polls, in milliseconds (default: 10000).
  public let everyMs: Int
  /// An initial delay before the first poll, in milliseconds (default: 0).
  public let initialDelayMs: Int
  /// The overall timeout for polling, in milliseconds (default: 600000).
  public let timeoutMs: Int

  public init(everyMs: Int = 10_000, initialDelayMs: Int = 0, timeoutMs: Int = 600_000) {
    self.everyMs = everyMs
    self.initialDelayMs = initialDelayMs
    self.timeoutMs = timeoutMs
  }
}

/// Errors that can be thrown by the high-level `tradeAsset` / `pollStatus` methods.

// MARK: - LifiTradeAssetError

public enum LifiTradeAssetError: Error, LocalizedError, Equatable {
  /// A signing closure was not provided when constructing the Lifi instance.
  case missingSigner
  /// A confirmation closure was not provided when constructing the Lifi instance.
  case missingConfirmation
  /// No routes were returned for the requested trade.
  case noRoutesFound
  /// The provided route index is out of bounds.
  case routeIndexOutOfBounds
  /// The selected route contains no steps.
  case routeHasNoSteps
  /// The step did not contain a transaction request to sign.
  case missingTransactionRequest
  /// The step's transaction request was missing required fields.
  case invalidTransactionRequest
  /// The transaction was mined but reverted on-chain for the given transaction hash.
  case transactionConfirmationFailed(String)
  /// On-chain confirmation could not be determined before timing out (transaction may still be
  /// pending, or the node was unreachable). Distinct from a definitive revert.
  case transactionConfirmationTimedOut(String)
  /// The LiFi transfer reached a FAILED terminal state.
  case lifiTransferFailed(String)
  /// Polling exceeded the configured timeout.
  case pollTimeout

  public var errorDescription: String? {
    switch self {
    case .missingSigner:
      return "Lifi.tradeAsset requires a signAndSendTransaction closure (injected by Portal)."
    case .missingConfirmation:
      return "Lifi.tradeAsset requires a waitForConfirmation closure (injected by Portal)."
    case .noRoutesFound:
      return "No routes were returned for the requested trade."
    case .routeIndexOutOfBounds:
      return "The provided routeIndex is out of bounds."
    case .routeHasNoSteps:
      return "The selected route contains no steps."
    case .missingTransactionRequest:
      return "The route step did not contain a transaction request to sign."
    case .invalidTransactionRequest:
      return "The route step's transaction request was missing required fields."
    case let .transactionConfirmationFailed(txHash):
      return "Transaction reverted on-chain: \(txHash)."
    case let .transactionConfirmationTimedOut(txHash):
      return "Timed out waiting for on-chain confirmation of transaction: \(txHash). It may still be pending."
    case let .lifiTransferFailed(detail):
      return "LiFi transfer FAILED: \(detail)."
    case .pollTimeout:
      return "Timed out while polling LiFi status."
    }
  }
}

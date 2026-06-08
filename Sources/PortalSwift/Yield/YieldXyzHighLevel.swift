//
//  YieldXyzHighLevel.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation

/// Identifies the yield to act on for a high-level deposit/withdraw.
///
/// - `yieldId`: an explicit yield identifier (skips the defaults lookup).
/// - `chainAndToken`: a full CAIP-2 chain (e.g. `eip155:1`) plus a token symbol (e.g. `USDC`);
///   the SDK resolves the `yieldId` from the Portal yield defaults.
public enum YieldActionTarget {
  case yieldId(String)
  case chainAndToken(chain: String, token: String)
}

/// Parameters for a high-level `deposit` / `withdraw`.
///
/// The wallet address is auto-resolved from the Portal wallet for the resolved chain, so it is
/// not part of these parameters. Use `arguments` to provide yield-specific inputs such as
/// `validatorAddress` for native staking; `amount` is merged into the action arguments.
public struct YieldDepositParams {
  public let target: YieldActionTarget
  public let amount: String
  public let arguments: YieldXyzEnterArguments?

  public init(target: YieldActionTarget, amount: String, arguments: YieldXyzEnterArguments? = nil) {
    self.target = target
    self.amount = amount
    self.arguments = arguments
  }
}

public typealias YieldWithdrawParams = YieldDepositParams

/// Per-transaction progress step emitted by `YieldSubmitOptions.onProgress`.
public enum YieldSubmitStep: String {
  case signing
  case submitted
  case confirming
  case confirmed
}

/// A single progress event for a deposit/withdraw transaction.
public struct YieldSubmitProgress {
  public let step: YieldSubmitStep
  public let index: Int
  public let total: Int
  public let hash: String?

  public init(step: YieldSubmitStep, index: Int, total: Int, hash: String? = nil) {
    self.step = step
    self.index = index
    self.total = total
    self.hash = hash
  }
}

/// Final status of a high-level deposit/withdraw.
public enum YieldSubmitResultStatus: String {
  case success = "SUCCESS"
  case partialSuccess = "PARTIAL_SUCCESS"
  case failed = "FAILED"
}

/// A summary of the executed yield action.
///
/// Note: this is action-level metadata, NOT the full yield opportunity. Use `discover` for full
/// opportunity details.
public struct YieldOpportunityDetails {
  public let yieldId: String
  public let intent: YieldXyzActionIntent?
  public let type: YieldXyzActionType?
  public let executionPattern: YieldXyzActionExecutionPattern?
  public let status: YieldXyzActionStatus?
  public let amount: String?
  public let amountUsd: String?

  public init(
    yieldId: String,
    intent: YieldXyzActionIntent? = nil,
    type: YieldXyzActionType? = nil,
    executionPattern: YieldXyzActionExecutionPattern? = nil,
    status: YieldXyzActionStatus? = nil,
    amount: String? = nil,
    amountUsd: String? = nil
  ) {
    self.yieldId = yieldId
    self.intent = intent
    self.type = type
    self.executionPattern = executionPattern
    self.status = status
    self.amount = amount
    self.amountUsd = amountUsd
  }
}

/// Result of a high-level `deposit` / `withdraw`.
public struct YieldDepositResult {
  public let hashes: [String]
  public let yieldId: String
  public let status: YieldSubmitResultStatus
  /// Set only when the action was resolved via `chainAndToken`.
  public let chain: String?
  /// Set only when the action was resolved via `chainAndToken`.
  public let token: String?
  public let yieldOpportunityDetails: YieldOpportunityDetails

  public init(
    hashes: [String],
    yieldId: String,
    status: YieldSubmitResultStatus,
    chain: String? = nil,
    token: String? = nil,
    yieldOpportunityDetails: YieldOpportunityDetails
  ) {
    self.hashes = hashes
    self.yieldId = yieldId
    self.status = status
    self.chain = chain
    self.token = token
    self.yieldOpportunityDetails = yieldOpportunityDetails
  }
}

public typealias YieldWithdrawResult = YieldDepositResult

/// Options for high-level `deposit` / `withdraw`.
public struct YieldSubmitOptions {
  /// Called for each transaction with `signing`, `submitted`, `confirming`, and `confirmed` steps.
  public let onProgress: ((YieldSubmitProgress) -> Void)?
  /// Seconds between confirmation polls (default 4).
  public let pollIntervalSeconds: Int
  /// Max seconds to wait for a transaction to confirm before treating it as uncertain (default 900).
  public let timeoutSeconds: Int

  public init(
    onProgress: ((YieldSubmitProgress) -> Void)? = nil,
    pollIntervalSeconds: Int = 4,
    timeoutSeconds: Int = 900
  ) {
    self.onProgress = onProgress
    self.pollIntervalSeconds = pollIntervalSeconds
    self.timeoutSeconds = timeoutSeconds
  }
}

/// Errors thrown by the high-level YieldXyz deposit/withdraw flow.
public enum YieldXyzError: LocalizedError, Equatable {
  case portalNotInitialized
  case emptyYieldId
  case invalidChainId(String)
  case noYieldForChainToken(String)
  case yieldNotFound(String)
  case addressUnavailable(String)
  case noTransactions
  case missingTransactionField(String)
  case unsupportedNetwork(String)
  case invalidSignResponse
  case transactionFailed(String)
  case noValidators(String)

  public var errorDescription: String? {
    switch self {
    case .portalNotInitialized:
      return "Portal instance is not available for signing or sending transactions."
    case .emptyYieldId:
      return "yieldId is required and must not be empty."
    case let .invalidChainId(chain):
      return "chain must be a full CAIP-2 id (e.g. eip155:1). Received: \"\(chain)\""
    case let .noYieldForChainToken(key):
      return "No default yield for key \"\(key)\". Use chain and token exactly as in the Portal yield defaults."
    case let .yieldNotFound(yieldId):
      return "Yield \"\(yieldId)\" was not found."
    case let .addressUnavailable(chain):
      return "No wallet address available for chain \"\(chain)\". Create or load a wallet first."
    case .noTransactions:
      return "No transactions in yield action response."
    case let .missingTransactionField(field):
      return "Transaction is missing required field: \(field)."
    case let .unsupportedNetwork(network):
      return "Unsupported network for high-level deposit/withdraw: \(network)."
    case .invalidSignResponse:
      return "Invalid response from signing/sending the transaction."
    case let .transactionFailed(hash):
      return "Transaction \(hash) failed on-chain."
    case let .noValidators(yieldId):
      return "No validators found for yieldId \"\(yieldId)\"."
    }
  }
}

/// Minimal Portal capabilities required by the high-level YieldXyz deposit/withdraw flow.
///
/// `Portal` conforms to this protocol; tests can substitute a small mock. Mirrors the
/// `EvmAccountTypePortalDependency` pattern.
public protocol YieldXyzPortalDependency: AnyObject {
  func request(chainId: String, method: PortalRequestMethod, params: [Any], options: RequestOptions?) async throws -> PortalProviderResult
  func getAddress(_ forChainId: String) async -> String?
  func getTransactionDetails(chain: String, signature: String) async throws -> GetTransactionDetailsResponse
}

//
//  YieldXyzPerpsExecutionTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Progress

/// A step of `executeAction` / `signAndSubmitAction`, reported through
/// `YieldXyzPerpsExecuteOptions.onProgress`.
public enum YieldXyzPerpsExecutionStep: String, Equatable {
  /// About to sign a transaction.
  case signing
  /// The signature or transaction hash was accepted by Yield.xyz.
  case submitted
  /// An on-chain leg was broadcast; waiting for its receipt.
  case confirming
  /// The on-chain leg confirmed.
  case confirmed
  /// The action was read back to track its status.
  case polling
  /// Execution stopped; `error` carries the reason.
  case failed
}

/// One progress event of an execution.
public struct YieldXyzPerpsExecutionProgress {
  public let step: YieldXyzPerpsExecutionStep
  public let actionId: String
  public let transactionId: String?
  /// How many transactions this call signed or submitted before this one. Transactions already
  /// submitted when the call started are not counted.
  public let index: Int?
  public let signingFormat: YieldXyzPerpsSigningFormat?
  public let transactionHash: String?
  public let actionStatus: YieldXyzPerpsActionStatus?
  public let error: YieldXyzPerpsExecutionError?

  public init(
    step: YieldXyzPerpsExecutionStep,
    actionId: String,
    transactionId: String? = nil,
    index: Int? = nil,
    signingFormat: YieldXyzPerpsSigningFormat? = nil,
    transactionHash: String? = nil,
    actionStatus: YieldXyzPerpsActionStatus? = nil,
    error: YieldXyzPerpsExecutionError? = nil
  ) {
    self.step = step
    self.actionId = actionId
    self.transactionId = transactionId
    self.index = index
    self.signingFormat = signingFormat
    self.transactionHash = transactionHash
    self.actionStatus = actionStatus
    self.error = error
  }
}

// MARK: - Signers

/// A request to sign EIP-712 typed data.
public struct YieldXyzPerpsSignTypedDataRequest: Equatable {
  /// The account to sign with.
  public let address: String
  /// JSON-encoded EIP-712 typed data, including `types.EIP712Domain`.
  public let typedData: String
  /// The CAIP-2 chain the signing request is routed through.
  public let chainId: String

  public init(address: String, typedData: String, chainId: String) {
    self.address = address
    self.typedData = typedData
    self.chainId = chainId
  }
}

/// Signs EIP-712 typed data and returns the 65-byte hex signature, or `nil` when the signing
/// request was not approved.
public typealias YieldXyzPerpsSignTypedData = (_ request: YieldXyzPerpsSignTypedDataRequest) async throws -> String?

/// Signs and broadcasts an `EVM_TRANSACTION` leg with `eth_sendTransaction` and returns the
/// transaction hash, or `nil` when the signing request was not approved. `idempotencyKey` is set
/// unless `YieldXyzPerpsExecuteOptions.useIdempotencyKeys` is `false`; pass it as
/// `RequestOptions(idempotencyKey:)`.
public typealias YieldXyzPerpsSignAndSendTransaction = (
  _ transaction: ETHTransactionParam,
  _ chainId: String,
  _ idempotencyKey: String?
) async throws -> String?

/// Waits for an on-chain leg and returns `true` only when it confirmed successfully.
public typealias YieldXyzPerpsWaitForConfirmation = (_ transactionHash: String, _ chainId: String) async throws -> Bool

/// What `YieldXyzPerps` needs from Portal to sign and confirm transactions. `Portal` provides all
/// of them; a standalone instance can supply its own.
public struct YieldXyzPerpsExecutionDependencies {
  /// The Portal wallet's EVM address; also the default `address` for account requests.
  public var getWalletAddress: (() async throws -> String?)?
  public var signTypedData: YieldXyzPerpsSignTypedData?
  public var signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction?
  public var waitForConfirmation: YieldXyzPerpsWaitForConfirmation?
  /// Whether a signing request can be routed through a CAIP-2 chain (an RPC endpoint is
  /// configured for it).
  public var isChainConfigured: ((_ chainId: String) async -> Bool)?

  public init(
    getWalletAddress: (() async throws -> String?)? = nil,
    signTypedData: YieldXyzPerpsSignTypedData? = nil,
    signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction? = nil,
    waitForConfirmation: YieldXyzPerpsWaitForConfirmation? = nil,
    isChainConfigured: ((_ chainId: String) async -> Bool)? = nil
  ) {
    self.getWalletAddress = getWalletAddress
    self.signTypedData = signTypedData
    self.signAndSendTransaction = signAndSendTransaction
    self.waitForConfirmation = waitForConfirmation
    self.isChainConfigured = isChainConfigured
  }
}

// MARK: - Options

/// How the action is read back while it is executed.
public struct YieldXyzPerpsPollOptions: Equatable {
  /// Seconds between reads (at least 0.25); grows by 1.5× after each read, up to 10 seconds.
  public var intervalSeconds: TimeInterval
  /// Applies to each wait separately: the read before each signature, and each wait for the action
  /// to reach a final status or add a transaction to sign. The read before each signature uses these
  /// options even when `pollAction` is `false`. Each wait reads the action at least once, even
  /// with a timeout of `0`.
  public var timeoutSeconds: TimeInterval

  public init(intervalSeconds: TimeInterval = 2, timeoutSeconds: TimeInterval = 600) {
    self.intervalSeconds = intervalSeconds
    self.timeoutSeconds = timeoutSeconds
  }
}

/// Options for `executeAction` / `signAndSubmitAction`.
public struct YieldXyzPerpsExecuteOptions {
  /// An observer of the execution. It runs after a transaction may already be broadcast, so it
  /// must not throw or block.
  public var onProgress: ((YieldXyzPerpsExecutionProgress) -> Void)?
  /// The CAIP-2 chain EIP-712 signing requests are routed through. It must have an RPC endpoint
  /// in `rpcConfig`; the typed data's own domain chain (e.g. Hyperliquid's `1337`) is never used
  /// for routing.
  public var signingChainId: String
  /// Poll the action after its transactions are submitted until it reaches a final status,
  /// signing any transactions Yield.xyz adds meanwhile. Without polling, the call still signs every
  /// awaiting transaction the action lists when it is read back, then returns without waiting.
  public var pollAction: Bool
  public var pollOptions: YieldXyzPerpsPollOptions
  /// Attach the idempotency key `yieldxyz-perps-<transactionId>` to each `EVM_TRANSACTION` leg, so
  /// that while Portal remembers the key (at least 24 hours) it broadcasts the leg at most once, for
  /// example when an execution is resumed after the app was killed before the hash reached
  /// Yield.xyz. On by default.
  ///
  /// A send Portal reports as still in progress is retried a few times with the same key; each retry
  /// is a new signing request, so it asks for approval again when `autoApprove` is off. A leg Portal
  /// refuses to send again fails with `transactionAlreadyBroadcast` (resume with `broadcastHashes`)
  /// or, when Portal cannot say whether the earlier send broadcast it, `broadcastOutcomeUnknown`
  /// naming the idempotency error. That includes a leg whose earlier send failed, for example for
  /// lack of gas: Portal refuses its key even once the cause is fixed. To send a leg again, check
  /// the chain first, then build a new action (its legs get new keys) or resume this one with
  /// `useIdempotencyKeys` set to `false`.
  public var useIdempotencyKeys: Bool
  /// Per-call override of the typed-data signer.
  public var signTypedData: YieldXyzPerpsSignTypedData?
  /// Per-call override of the on-chain transaction signer.
  public var signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction?
  /// Per-call override of the on-chain confirmation waiter.
  public var waitForConfirmation: YieldXyzPerpsWaitForConfirmation?
  /// Hashes of `EVM_TRANSACTION` legs already broadcast by an earlier attempt, keyed by transaction
  /// id — the `broadcastHash` of a `YieldXyzPerpsExecutionError`. Such a leg is confirmed and
  /// submitted with this hash instead of being signed and broadcast again.
  public var broadcastHashes: [String: String]

  public init(
    onProgress: ((YieldXyzPerpsExecutionProgress) -> Void)? = nil,
    signingChainId: String = "eip155:42161",
    pollAction: Bool = true,
    pollOptions: YieldXyzPerpsPollOptions = YieldXyzPerpsPollOptions(),
    useIdempotencyKeys: Bool = true,
    signTypedData: YieldXyzPerpsSignTypedData? = nil,
    signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction? = nil,
    waitForConfirmation: YieldXyzPerpsWaitForConfirmation? = nil,
    broadcastHashes: [String: String] = [:]
  ) {
    self.onProgress = onProgress
    self.signingChainId = signingChainId
    self.pollAction = pollAction
    self.pollOptions = pollOptions
    self.useIdempotencyKeys = useIdempotencyKeys
    self.signTypedData = signTypedData
    self.signAndSendTransaction = signAndSendTransaction
    self.waitForConfirmation = waitForConfirmation
    self.broadcastHashes = broadcastHashes
  }
}

// MARK: - Result

/// What an execution did with one transaction.
public struct YieldXyzPerpsTransactionExecution: Equatable {
  public let transactionId: String
  public let type: YieldXyzPerpsTransactionType
  /// `EIP712_TYPED_DATA` or `EVM_TRANSACTION`: the formats the SDK signs.
  public let signingFormat: YieldXyzPerpsSigningFormat
  /// The signature, for an `EIP712_TYPED_DATA` transaction.
  public let signedPayload: String?
  /// The broadcast hash, for an `EVM_TRANSACTION` leg.
  public let transactionHash: String?
  /// `nil` when the outcome was confirmed by reading the action back after an ambiguous failure.
  public let submitResult: YieldXyzPerpsSubmitResult?

  public init(
    transactionId: String,
    type: YieldXyzPerpsTransactionType,
    signingFormat: YieldXyzPerpsSigningFormat,
    signedPayload: String? = nil,
    transactionHash: String? = nil,
    submitResult: YieldXyzPerpsSubmitResult? = nil
  ) {
    self.transactionId = transactionId
    self.type = type
    self.signingFormat = signingFormat
    self.signedPayload = signedPayload
    self.transactionHash = transactionHash
    self.submitResult = submitResult
  }
}

/// The outcome of `executeAction` / `signAndSubmitAction`.
public struct YieldXyzPerpsExecutionResult: Equatable {
  public let actionId: String
  /// The latest known state of the action.
  public let action: YieldXyzPerpsAction
  public let status: YieldXyzPerpsActionStatus
  public let transactions: [YieldXyzPerpsTransactionExecution]

  public init(
    actionId: String,
    action: YieldXyzPerpsAction,
    status: YieldXyzPerpsActionStatus,
    transactions: [YieldXyzPerpsTransactionExecution]
  ) {
    self.actionId = actionId
    self.action = action
    self.status = status
    self.transactions = transactions
  }
}

// MARK: - Errors

/// Why an execution stopped.
public enum YieldXyzPerpsExecutionErrorReason: String, Equatable {
  /// The transaction's `signingFormat` is missing or not supported (Solana and Cosmos are not
  /// supported yet).
  case unsupportedSigningFormat = "UNSUPPORTED_SIGNING_FORMAT"
  /// The `signablePayload` is missing or malformed.
  case invalidSignablePayload = "INVALID_SIGNABLE_PAYLOAD"
  /// No EVM wallet address is available to sign with.
  case missingWalletAddress = "MISSING_WALLET_ADDRESS"
  /// The transaction was built for an address other than the Portal wallet's EVM address.
  case signerAddressMismatch = "SIGNER_ADDRESS_MISMATCH"
  /// The chain the signing request must be routed through has no RPC endpoint in `rpcConfig`.
  case signingChainNotConfigured = "SIGNING_CHAIN_NOT_CONFIGURED"
  /// A signer or confirmation waiter needed for this transaction is not configured.
  case dependencyUnavailable = "DEPENDENCY_UNAVAILABLE"
  /// The signing request was rejected (no signature was returned).
  case signatureRejected = "SIGNATURE_REJECTED"
  /// The signer returned, or `broadcastHashes` supplied, a value that is not a 65-byte hex
  /// signature or a 32-byte transaction hash.
  case invalidSignature = "INVALID_SIGNATURE"
  /// Signing failed, or an `EVM_TRANSACTION` leg failed before it was broadcast; `underlyingError`
  /// holds the cause. A send that may have reached the chain is `broadcastOutcomeUnknown` instead.
  case signingFailed = "SIGNING_FAILED"
  /// Portal refused to broadcast an `EVM_TRANSACTION` leg again because its idempotency key shows
  /// it was already broadcast. Portal does not return that broadcast's hash: look the transaction
  /// up on-chain and resume with `broadcastHashes`.
  case transactionAlreadyBroadcast = "TRANSACTION_ALREADY_BROADCAST"
  /// An `EVM_TRANSACTION` leg may have been broadcast: an earlier send under its idempotency key is
  /// still in progress, failed, or has an unknown outcome, or the send failed in a way that does not
  /// prove it never reached the chain (for example an RPC timeout after the node accepted it, or a
  /// connection dropped after the broadcast). Do not build a new action blindly: check the chain,
  /// then resume with `broadcastHashes` if it was broadcast, or else resume the action or build a new
  /// one, as the message says. `underlyingError` holds the cause.
  case broadcastOutcomeUnknown = "BROADCAST_OUTCOME_UNKNOWN"
  /// An on-chain leg was broadcast but did not confirm successfully.
  case transactionNotConfirmed = "TRANSACTION_NOT_CONFIRMED"
  /// The Portal API rejected the submission; `underlyingError` holds the backend error.
  case submitRejected = "SUBMIT_REJECTED"
  /// The submission was accepted but Yield.xyz reported the transaction as `FAILED`.
  case submitFailed = "SUBMIT_FAILED"
  /// The outcome of a transaction could not be confirmed: its submission failed ambiguously, or
  /// the task was cancelled after an on-chain leg was broadcast (`broadcastHash` is then set:
  /// resume with it in `broadcastHashes`). Do not resubmit blindly.
  case submitOutcomeUnknown = "SUBMIT_OUTCOME_UNKNOWN"
  /// The action ended as `FAILED`, `CANCELED` or `STALE`.
  case actionFailed = "ACTION_FAILED"
  /// Another call on this Portal instance is already executing the action; this call signed
  /// nothing.
  case actionInProgress = "ACTION_IN_PROGRESS"
  /// The action could not be read back while tracking it; `underlyingError` holds the cause.
  case pollingFailed = "POLLING_FAILED"
  /// The action did not reach a final status before the polling deadline.
  case timeout = "TIMEOUT"
}

/// A failure while signing, submitting or tracking a Yield.xyz Perps action. It carries the action
/// and transaction ids so the application can persist them and resume with `getAction` /
/// `signAndSubmitAction`.
///
/// When it carries a `broadcastHash`, that `EVM_TRANSACTION` leg was already broadcast and
/// Yield.xyz may not have recorded it yet: resume with `broadcastHashes: [transactionId:
/// broadcastHash]`, so the leg is confirmed and submitted instead of signed again.
public struct YieldXyzPerpsExecutionError: LocalizedError {
  public let reason: YieldXyzPerpsExecutionErrorReason
  public let message: String
  public let actionId: String?
  public let transactionId: String?
  /// The hash the signer returned for an `EVM_TRANSACTION` leg. Set whenever that leg was already
  /// broadcast.
  public let broadcastHash: String?
  public let transactionHash: String?
  /// The latest known state of the action, when available.
  public let action: YieldXyzPerpsAction?
  /// The error that caused this one, when there is one. `YieldXyzPerpsApiError.from(_:)` reads the
  /// Portal API error behind it.
  public let underlyingError: Error?

  public init(
    reason: YieldXyzPerpsExecutionErrorReason,
    message: String,
    actionId: String? = nil,
    transactionId: String? = nil,
    broadcastHash: String? = nil,
    transactionHash: String? = nil,
    action: YieldXyzPerpsAction? = nil,
    underlyingError: Error? = nil
  ) {
    self.reason = reason
    self.message = message
    self.actionId = actionId
    self.transactionId = transactionId
    self.broadcastHash = broadcastHash
    self.transactionHash = transactionHash
    self.action = action
    self.underlyingError = underlyingError
  }

  public var errorDescription: String? {
    "[YieldXyzPerps] \(message)"
  }
}

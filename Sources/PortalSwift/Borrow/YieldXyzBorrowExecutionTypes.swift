//
//  YieldXyzBorrowExecutionTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Progress

/// A step of `executeAction` / `signAndSubmitAction`, reported through
/// `YieldXyzBorrowExecuteOptions.onProgress`.
public enum YieldXyzBorrowExecutionStep: String, Equatable {
  /// About to sign and broadcast a transaction.
  case signing
  /// The transaction was broadcast (`broadcastHash`); resolving its on-chain hash.
  case confirming
  /// The on-chain hash was submitted to Yield.xyz.
  case submitted
  /// The action was read back to track it.
  case polling
  /// Yield.xyz reports the transaction as `CONFIRMED` or `SKIPPED`.
  case confirmed
  /// The next step's transactions were fetched; `action` carries the new step in signing order.
  case nextStep
  /// Execution stopped; `error` carries the reason.
  case failed
}

/// One progress event of an execution.
public struct YieldXyzBorrowExecutionProgress {
  public let step: YieldXyzBorrowExecutionStep
  public let actionId: String
  public let transactionId: String?
  /// How many transactions this call signed or submitted before this one, across steps.
  /// Transactions already settled when the call started are not counted.
  public let index: Int?
  /// With `nextStep`: the step now being executed (1-indexed).
  public let currentStep: Int?
  public let totalSteps: Int?
  /// The hash the signer returned: the transaction hash for an EOA, or the user operation hash for
  /// an account-abstracted client. Persist it as soon as it is reported: it is how a transaction
  /// already broadcast is resumed (`broadcastHashes`).
  public let broadcastHash: String?
  /// The on-chain transaction hash (the bundle transaction's for an account-abstracted client).
  public let transactionHash: String?
  public let userOperationHash: String?
  public let actionStatus: YieldXyzBorrowActionStatus?
  /// With `nextStep`: the action as the new step returned it, with its transactions in signing
  /// order. Persist it: resuming that step from it keeps this order, which `getAction` may not.
  public let action: YieldXyzBorrowAction?
  public let error: YieldXyzBorrowExecutionError?

  public init(
    step: YieldXyzBorrowExecutionStep,
    actionId: String,
    transactionId: String? = nil,
    index: Int? = nil,
    currentStep: Int? = nil,
    totalSteps: Int? = nil,
    broadcastHash: String? = nil,
    transactionHash: String? = nil,
    userOperationHash: String? = nil,
    actionStatus: YieldXyzBorrowActionStatus? = nil,
    action: YieldXyzBorrowAction? = nil,
    error: YieldXyzBorrowExecutionError? = nil
  ) {
    self.step = step
    self.actionId = actionId
    self.transactionId = transactionId
    self.index = index
    self.currentStep = currentStep
    self.totalSteps = totalSteps
    self.broadcastHash = broadcastHash
    self.transactionHash = transactionHash
    self.userOperationHash = userOperationHash
    self.actionStatus = actionStatus
    self.action = action
    self.error = error
  }
}

// MARK: - Dependencies

/// Signs and broadcasts a transaction with `eth_sendTransaction` on `chainId` and returns the hash
/// the signer reports (a user operation hash for an account-abstracted client), or `nil` when the
/// signing request was not approved. `idempotencyKey` is set unless
/// `YieldXyzBorrowExecuteOptions.useIdempotencyKeys` is `false`; pass it as
/// `RequestOptions(idempotencyKey:)`.
public typealias YieldXyzBorrowSignAndSendTransaction = (
  _ transaction: ETHTransactionParam,
  _ chainId: String,
  _ idempotencyKey: String?
) async throws -> String?

/// Reads back the transaction or user operation behind a broadcast hash.
typealias YieldXyzBorrowLookupEvmTransaction = (_ chainId: String, _ hash: String) async throws -> YieldXyzEvmTransactionLookup?

/// What `YieldXyzBorrow` needs from Portal to sign transactions. `Portal` provides all of them; a
/// standalone instance can supply its own.
public struct YieldXyzBorrowExecutionDependencies {
  /// The Portal wallet's EVM address; the action and every transaction must have been built for
  /// it.
  public var getWalletAddress: (() async throws -> String?)?
  public var signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction?
  /// Whether `signAndSendTransaction` can route a signing request through a CAIP-2 chain (an RPC
  /// endpoint is configured for it).
  public var isChainConfigured: ((_ chainId: String) async -> Bool)?

  public init(
    getWalletAddress: (() async throws -> String?)? = nil,
    signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction? = nil,
    isChainConfigured: ((_ chainId: String) async -> Bool)? = nil
  ) {
    self.getWalletAddress = getWalletAddress
    self.signAndSendTransaction = signAndSendTransaction
    self.isChainConfigured = isChainConfigured
  }
}

// MARK: - Options

/// How the action, and the on-chain hash of a broadcast transaction, are read back.
public struct YieldXyzBorrowPollOptions: Equatable {
  /// Seconds between reads (at least 0.25); grows by 1.5× after each read, up to 10 seconds.
  public var intervalSeconds: TimeInterval
  /// Applies to each wait separately: each wait for a transaction to be signable, to be resolved
  /// on-chain or to be confirmed by Yield.xyz, and each wait for the step's outcome. A zero timeout
  /// fails with `timeout` before the action is read, so nothing is signed.
  public var timeoutSeconds: TimeInterval

  public init(intervalSeconds: TimeInterval = 2, timeoutSeconds: TimeInterval = 600) {
    self.intervalSeconds = intervalSeconds
    self.timeoutSeconds = timeoutSeconds
  }
}

/// Options for `executeAction` / `signAndSubmitAction`.
public struct YieldXyzBorrowExecuteOptions {
  /// An observer of the execution. It runs after a transaction may already be broadcast, so it
  /// must not block.
  public var onProgress: ((YieldXyzBorrowExecutionProgress) -> Void)?
  public var pollOptions: YieldXyzBorrowPollOptions
  /// Attach the idempotency key `yieldxyz-borrow-<transactionId>` to each transaction, so that
  /// while Portal remembers the key (at least 24 hours) it broadcasts the transaction at most once,
  /// for example when an execution is resumed after the app was killed before the hash reached
  /// Yield.xyz. On by default.
  ///
  /// A send Portal reports as still in progress is retried a few times with the same key; each
  /// retry is a new signing request, so it asks for approval again when `autoApprove` is off. A
  /// transaction Portal refuses to send again fails with `transactionAlreadyBroadcast` (resume with
  /// `broadcastHashes`) or, when Portal cannot say whether the earlier send broadcast it,
  /// `broadcastOutcomeUnknown` naming the idempotency error. That includes a transaction whose
  /// earlier send failed, for example for lack of gas: Portal refuses its key even once the cause
  /// is fixed. To sign a transaction again, after `userOperationFailed` or once you have checked the
  /// chain that the earlier send did not go through, build a new action (its transactions get new
  /// keys) or set this to `false`.
  public var useIdempotencyKeys: Bool
  /// Per-call signer. The chain then needs no `rpcConfig` entry.
  public var signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction?
  /// Hashes of transactions already broadcast by an earlier attempt, keyed by transaction id (the
  /// `broadcastHash` of a `YieldXyzBorrowExecutionError` or of a `confirming` progress event). Such a
  /// transaction is resolved on-chain and submitted with this hash instead of being signed and
  /// broadcast again.
  public var broadcastHashes: [String: String]

  public init(
    onProgress: ((YieldXyzBorrowExecutionProgress) -> Void)? = nil,
    pollOptions: YieldXyzBorrowPollOptions = YieldXyzBorrowPollOptions(),
    useIdempotencyKeys: Bool = true,
    signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction? = nil,
    broadcastHashes: [String: String] = [:]
  ) {
    self.onProgress = onProgress
    self.pollOptions = pollOptions
    self.useIdempotencyKeys = useIdempotencyKeys
    self.signAndSendTransaction = signAndSendTransaction
    self.broadcastHashes = broadcastHashes
  }
}

// MARK: - Result

/// What an execution did with one transaction.
public struct YieldXyzBorrowTransactionExecution: Equatable {
  public let transactionId: String
  public let type: YieldXyzBorrowTransactionType
  /// The on-chain transaction hash submitted to Yield.xyz (the bundle transaction's for an
  /// account-abstracted client).
  public let transactionHash: String
  /// The user operation hash, for an account-abstracted client.
  public let userOperationHash: String?
  /// `nil` when the outcome was confirmed by reading the action back after an ambiguous failure.
  public let submitResult: YieldXyzBorrowSubmitTransactionResult?

  public init(
    transactionId: String,
    type: YieldXyzBorrowTransactionType,
    transactionHash: String,
    userOperationHash: String? = nil,
    submitResult: YieldXyzBorrowSubmitTransactionResult? = nil
  ) {
    self.transactionId = transactionId
    self.type = type
    self.transactionHash = transactionHash
    self.userOperationHash = userOperationHash
    self.submitResult = submitResult
  }
}

/// The outcome of `executeAction` / `signAndSubmitAction`.
public struct YieldXyzBorrowExecutionResult: Equatable {
  public let actionId: String
  /// The latest known state of the action.
  public let action: YieldXyzBorrowAction
  public let status: YieldXyzBorrowActionStatus
  public let transactions: [YieldXyzBorrowTransactionExecution]

  public init(
    actionId: String,
    action: YieldXyzBorrowAction,
    status: YieldXyzBorrowActionStatus,
    transactions: [YieldXyzBorrowTransactionExecution]
  ) {
    self.actionId = actionId
    self.action = action
    self.status = status
    self.transactions = transactions
  }
}

// MARK: - Errors

/// Why an execution stopped.
public enum YieldXyzBorrowExecutionErrorReason: String, Equatable {
  /// The transaction's `signingFormat` is not `EVM_TRANSACTION`, the only format Borrow signs.
  case unsupportedSigningFormat = "UNSUPPORTED_SIGNING_FORMAT"
  /// The transaction's `network` is not an EIP-155 chain Portal supports.
  case unsupportedNetwork = "UNSUPPORTED_NETWORK"
  /// The `signablePayload` is missing or is not a valid EVM transaction, or the transaction has no
  /// id to submit it under.
  case invalidSignablePayload = "INVALID_SIGNABLE_PAYLOAD"
  /// No EVM wallet address is available to sign with.
  case missingWalletAddress = "MISSING_WALLET_ADDRESS"
  /// The action or the transaction was built for an address other than the Portal wallet's EVM
  /// address.
  case signerAddressMismatch = "SIGNER_ADDRESS_MISMATCH"
  /// The transaction's chain has no RPC endpoint in `rpcConfig`, which the Portal signer needs.
  case signingChainNotConfigured = "SIGNING_CHAIN_NOT_CONFIGURED"
  /// A signer or transaction lookup needed to execute the action is not configured.
  case dependencyUnavailable = "DEPENDENCY_UNAVAILABLE"
  /// The signing request was rejected (no hash was returned).
  case signatureRejected = "SIGNATURE_REJECTED"
  /// The signer returned, or `broadcastHashes` supplied, a value that is not a 32-byte hex hash.
  case invalidTransactionHash = "INVALID_TRANSACTION_HASH"
  /// Signing or broadcasting failed; `underlyingError` holds the cause. Without an idempotency key
  /// (or once Portal no longer remembers it), the signer may still have broadcast the transaction
  /// without returning its hash: there is then no `broadcastHash` to resume with, and a retry may
  /// broadcast it a second time. Check the chain before signing it again. With a key, a send whose
  /// outcome Portal cannot confirm fails with `broadcastOutcomeUnknown` instead.
  case signingFailed = "SIGNING_FAILED"
  /// Portal refused to broadcast the transaction again because its idempotency key shows it was
  /// already broadcast. Portal does not return that broadcast's hash: resume with the
  /// `broadcastHash` the `confirming` progress event reported, or look the transaction up on-chain.
  case transactionAlreadyBroadcast = "TRANSACTION_ALREADY_BROADCAST"
  /// Portal cannot say whether the transaction was broadcast: an earlier send under its idempotency
  /// key is still in progress, failed, or has an unknown outcome. Nothing here proves the
  /// transaction was not sent, so do not build a new action blindly: check the chain, then resume
  /// with `broadcastHashes` if it was broadcast, or else build a new action or resume with
  /// `useIdempotencyKeys` set to `false`. `underlyingError` holds Portal's idempotency error.
  case broadcastOutcomeUnknown = "BROADCAST_OUTCOME_UNKNOWN"
  /// The user operation was included on-chain but did not succeed. It was already processed:
  /// passing its `broadcastHash` in `broadcastHashes` only reproduces this failure, and signing the
  /// transaction again needs a new action, or `useIdempotencyKeys` set to `false`.
  case userOperationFailed = "USER_OPERATION_FAILED"
  /// Yield.xyz reported the transaction as `FAILED`.
  case transactionFailed = "TRANSACTION_FAILED"
  /// The Portal API rejected the submission, or the SDK could not send it; `underlyingError` holds
  /// the backend error, or the SDK's.
  case submitRejected = "SUBMIT_REJECTED"
  /// The submission was accepted but Yield.xyz reported the transaction as `FAILED`.
  case submitFailed = "SUBMIT_FAILED"
  /// The submission failed ambiguously, or was cancelled, and its outcome could not be confirmed;
  /// check the action before retrying.
  case submitOutcomeUnknown = "SUBMIT_OUTCOME_UNKNOWN"
  /// The next step could not be fetched, or had nothing to sign; `underlyingError` holds the backend
  /// error when there is one. Yield.xyz may have moved to the next step even though its response was
  /// lost, so `action` can still be the previous step's: resuming from it then signs the new step's
  /// transactions in the order `getAction` lists them, which may not be their signing order.
  case nextStepFailed = "NEXT_STEP_FAILED"
  /// The action ended as `FAILED`, `CANCELED` or `STALE`.
  case actionFailed = "ACTION_FAILED"
  /// Another call on this instance (or on another `borrow` of the same Portal, which shares the
  /// guard) is already executing the action; this call signed nothing.
  case actionInProgress = "ACTION_IN_PROGRESS"
  /// The action or a transaction could not be read back while tracking it; `underlyingError`
  /// holds the cause.
  case pollingFailed = "POLLING_FAILED"
  /// A transaction or the action did not reach the awaited status before the polling deadline.
  case timeout = "TIMEOUT"
}

/// A failure while signing, submitting or tracking a Yield.xyz Borrow action. It carries the action
/// and transaction ids, and the latest known `action` with its transactions in signing order, so
/// the application can persist them and resume with `signAndSubmitAction(error.action)`.
///
/// When it carries a `broadcastHash`, that transaction was already broadcast and Yield.xyz may not
/// have recorded it yet: resume with `broadcastHashes: [transactionId: broadcastHash]`, so the
/// transaction is submitted instead of signed again. `userOperationFailed` is the exception: its
/// user operation was already processed and did not succeed.
///
/// Two failures cannot be fully recovered from: without an idempotency key, a `signingFailed`
/// signer may have broadcast without returning a hash, and after a `nextStepFailed` the `action`
/// may still be the previous step's.
public struct YieldXyzBorrowExecutionError: LocalizedError {
  public let reason: YieldXyzBorrowExecutionErrorReason
  public let message: String
  public let actionId: String?
  public let transactionId: String?
  /// The hash the signer returned (a user operation hash for an account-abstracted client). Set
  /// whenever the transaction was already broadcast.
  public let broadcastHash: String?
  /// The on-chain transaction hash, once known.
  public let transactionHash: String?
  public let userOperationHash: String?
  /// The latest known state of the action, with its transactions in signing order, when available.
  public let action: YieldXyzBorrowAction?
  /// The error that caused this one, when there is one. `YieldXyzBorrowApiError.from(_:)` reads the
  /// Portal API error behind it.
  public let underlyingError: Error?

  public init(
    reason: YieldXyzBorrowExecutionErrorReason,
    message: String,
    actionId: String? = nil,
    transactionId: String? = nil,
    broadcastHash: String? = nil,
    transactionHash: String? = nil,
    userOperationHash: String? = nil,
    action: YieldXyzBorrowAction? = nil,
    underlyingError: Error? = nil
  ) {
    self.reason = reason
    self.message = message
    self.actionId = actionId
    self.transactionId = transactionId
    self.broadcastHash = broadcastHash
    self.transactionHash = transactionHash
    self.userOperationHash = userOperationHash
    self.action = action
    self.underlyingError = underlyingError
  }

  public var errorDescription: String? {
    "[YieldXyzBorrow] \(message)"
  }
}

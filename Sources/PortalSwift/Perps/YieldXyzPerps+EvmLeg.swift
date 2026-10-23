//
//  YieldXyzPerps+EvmLeg.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// The `EVM_TRANSACTION` leg: send under an idempotency key, confirm, then submit the hash.
extension YieldXyzPerps {
  /// The idempotency key of an `EVM_TRANSACTION` leg, or `nil` when the transaction id cannot form a
  /// valid key (1–255 characters of `A-Z a-z 0-9 . _ ~ -`).
  static func idempotencyKey(forTransactionId transactionId: String) -> String? {
    YieldXyzIdempotency.key(prefix: idempotencyKeyPrefix, transactionId: transactionId)
  }

  func processEvmTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let request: YieldXyzEvmTransactionRequest
    switch YieldXyzEvmTransactionParams.parse(transaction.signablePayload, defaultFrom: transaction.address) {
    case let .success(parsed):
      request = parsed
    case let .failure(problem):
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) \(problem.description)."
      )
    }
    guard request.from.lowercased() == context.walletAddress.lowercased() else {
      throw transactionError(
        context,
        transaction,
        reason: .signerAddressMismatch,
        message: "The signablePayload of transaction \(transaction.id) sends from \(request.from), not the Portal wallet \(context.walletAddress)."
      )
    }

    let chainId = try resolveEvmChainId(context, transaction)
    try await assertSigningChain(context, transaction, chainId: chainId)

    let signAndSendTransaction = context.options.signAndSendTransaction ?? dependencies.signAndSendTransaction
    let suppliedBroadcastHash = context.options.broadcastHashes[transaction.id]
    guard let waitForConfirmation = context.options.waitForConfirmation ?? dependencies.waitForConfirmation else {
      throw transactionError(
        context,
        transaction,
        reason: .dependencyUnavailable,
        message: suppliedBroadcastHash == nil && signAndSendTransaction == nil
          ? "No transaction signer and confirmation waiter are configured."
          : "No confirmation waiter is configured."
      )
    }

    let transactionHash: String
    if let suppliedBroadcastHash {
      // A leg the caller reports as already broadcast is confirmed and submitted from that hash
      // but never signed, so it cannot be broadcast twice.
      guard YieldXyzEvmTransactionParams.isTransactionHash(suppliedBroadcastHash) else {
        throw transactionError(
          context,
          transaction,
          reason: .invalidSignature,
          message: "The broadcast hash supplied for transaction \(transaction.id) is not a transaction hash."
        )
      }
      transactionHash = suppliedBroadcastHash
    } else if let signAndSendTransaction {
      transactionHash = try await signAndSendEvmTransaction(
        context,
        transaction: transaction,
        index: index,
        param: YieldXyzEvmTransactionParams.toSendTransactionParam(request),
        chainId: chainId,
        signAndSendTransaction: signAndSendTransaction
      )
    } else {
      throw transactionError(context, transaction, reason: .dependencyUnavailable, message: "No transaction signer is configured.")
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .confirming,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    let confirmed: Bool
    do {
      confirmed = try await waitForConfirmation(transactionHash, chainId)
    } catch let error where Self.isCancellation(error) {
      // The leg is on-chain and may still confirm: it has not failed, so keep its hash for a resume
      // with `broadcastHashes` instead of reporting it as not confirmed.
      throw transactionError(
        context,
        transaction,
        reason: .submitOutcomeUnknown,
        message: "Confirming transaction \(transaction.id) (\(transactionHash)) was cancelled; resume with broadcastHashes.",
        broadcastHash: transactionHash,
        underlyingError: CancellationError()
      )
    } catch {
      throw transactionError(
        context,
        transaction,
        reason: .transactionNotConfirmed,
        message: "Confirming transaction \(transaction.id) (\(transactionHash)) failed.",
        broadcastHash: transactionHash,
        underlyingError: error
      )
    }
    guard confirmed else {
      throw transactionError(
        context,
        transaction,
        reason: .transactionNotConfirmed,
        message: "Transaction \(transaction.id) (\(transactionHash)) did not confirm successfully.",
        broadcastHash: transactionHash
      )
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .confirmed,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    let submitResult: YieldXyzPerpsSubmitResult?
    do {
      submitResult = try await submitWithReconciliation(context, transaction, body: .transactionHash(transactionHash))
    } catch let error where Self.isCancellation(error) {
      // The leg is on-chain: keep its hash so the caller can resume with `broadcastHashes`.
      throw transactionError(
        context,
        transaction,
        reason: .submitOutcomeUnknown,
        message: "Submitting transaction \(transaction.id) (\(transactionHash)) was cancelled; resume with broadcastHashes.",
        broadcastHash: transactionHash,
        underlyingError: CancellationError()
      )
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .submitted,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    return YieldXyzPerpsTransactionExecution(
      transactionId: transaction.id,
      type: transaction.type,
      signingFormat: .evmTransaction,
      transactionHash: transactionHash,
      submitResult: submitResult
    )
  }

  /// Signs and broadcasts an on-chain leg. With an idempotency key, Portal broadcasts the leg at
  /// most once: a send it reports as still in progress is retried with the same key a few times,
  /// and a send it reports as already completed stops with `transactionAlreadyBroadcast`, because
  /// Portal does not return the hash of that broadcast.
  func signAndSendEvmTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int,
    param: ETHTransactionParam,
    chainId: String,
    signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction
  ) async throws -> String {
    var idempotencyKey: String?
    if context.options.useIdempotencyKeys {
      idempotencyKey = Self.idempotencyKey(forTransactionId: transaction.id)
      if idempotencyKey == nil {
        logger.warn("YieldXyzPerps - Transaction id \(transaction.id) cannot form an idempotency key; it is sent without one.")
      }
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .signing,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
    ))

    var inProgressRetries = 0
    var returned: String?
    while true {
      do {
        returned = try await signAndSendTransaction(param, chainId, idempotencyKey)
        break
      } catch let error where Self.isCancellation(error) {
        throw CancellationError()
      } catch let error as PortalMpcError where idempotencyKey != nil && error.id == PortalIdempotencyErrorId.requestInProgress {
        guard inProgressRetries < retryPolicy.idempotencyInProgressDelays.count else {
          // The send Portal is still processing may yet broadcast the leg.
          throw transactionError(
            context,
            transaction,
            reason: .broadcastOutcomeUnknown,
            message: "Portal is still processing the send of transaction \(transaction.id) and may yet broadcast it; resume the action later.",
            underlyingError: error
          )
        }
        try await Self.sleep(seconds: retryPolicy.idempotencyInProgressDelays[inProgressRetries])
        inProgressRetries += 1
      } catch let error as PortalMpcError where idempotencyKey != nil && error.id == PortalIdempotencyErrorId.requestAlreadyCompleted {
        throw transactionError(
          context,
          transaction,
          reason: .transactionAlreadyBroadcast,
          message: "Portal already broadcast transaction \(transaction.id) and does not return its hash; look it up on-chain and resume with broadcastHashes.",
          underlyingError: error
        )
      } catch let error as PortalMpcError where idempotencyKey != nil && error.isIdempotencyRejection {
        // Portal cannot say whether the earlier send under this key broadcast the leg, and gives
        // every later send the same answer while it remembers the key, even once the cause (for
        // example missing gas) is fixed.
        throw transactionError(
          context,
          transaction,
          reason: .broadcastOutcomeUnknown,
          message: "Portal refused to send transaction \(transaction.id) under its idempotency key (\(error.id ?? "unknown")): an earlier send of this leg failed or has an unknown outcome, and Portal gives that answer for at least 24 hours. Check the chain for that send: if it was broadcast, resume with broadcastHashes; if not, build a new action, or resume this one with useIdempotencyKeys set to false.",
          underlyingError: error
        )
      } catch {
        if Self.failedBeforeSending(error) {
          throw transactionError(
            context,
            transaction,
            reason: .signingFailed,
            message: "Sending transaction \(transaction.id) failed before it was broadcast.",
            underlyingError: error
          )
        }
        // Any other failure may come after the broadcast: an RPC call that times out after the node
        // accepted the transaction, or a connection that drops once it was broadcast, looks the same
        // as one that never reached the chain. Building a new action would send the leg again.
        let ifNotBroadcast = idempotencyKey == nil
          ? "resume this action or build a new one"
          : "resume this action, which reuses its idempotency key so Portal sends the leg at most once"
        throw transactionError(
          context,
          transaction,
          reason: .broadcastOutcomeUnknown,
          message: "Sending transaction \(transaction.id) failed and it may already have been broadcast. Check the chain for a mined or pending transaction before building a new action: if it was broadcast, resume with broadcastHashes; if not, \(ifNotBroadcast).",
          underlyingError: error
        )
      }
    }

    guard let returned else {
      throw transactionError(
        context,
        transaction,
        reason: .signatureRejected,
        message: "The signing request for transaction \(transaction.id) was rejected."
      )
    }
    guard YieldXyzEvmTransactionParams.isTransactionHash(returned) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignature,
        message: "The signer did not return a transaction hash for transaction \(transaction.id)."
      )
    }
    return returned
  }

  /// Ids Portal's MPC server raises before a leg reaches the chain (`mpc/errs/error_ids.go`): building
  /// the signing message or the transaction, a malformed request, a firewall or policy rule refusing
  /// it, or the node refusing it for lack of funds. `RPC_OP_FAILED` is not one: the send itself can
  /// fail after the node accepted the transaction.
  static let preBroadcastErrorIds: Set<String> = [
    "MSG_BUILD_FAILED",
    "TX_BUILD_FAILED",
    "BAD_REQUEST",
    "ADDRESS_BLOCKED",
    "POLICY_AMOUNT_LIMIT_EXCEEDED",
    "INSUFFICIENT_FUNDS"
  ]

  /// `true` for a send failure known to happen before the leg reaches the chain: the SDK's own checks
  /// (idempotency key, credential, signing approval), Portal rejecting the credential, or one of
  /// `preBroadcastErrorIds`.
  static func failedBeforeSending(_ error: Error) -> Bool {
    switch error {
    case is PortalIdempotencyError, is PortalCredentialError, is ProviderSigningError:
      return true
    case let error as PortalMpcError:
      return error.isAuthFailure || error.id.map(preBroadcastErrorIds.contains) == true
    default:
      return false
    }
  }

  /// Real chains arrive as CAIP-2 in `network`; otherwise fall back to the numeric `chainId`.
  func resolveEvmChainId(_ context: ExecutionContext, _ transaction: YieldXyzPerpsTransaction) throws -> String {
    if YieldXyzEvmTransactionParams.isEvmChainId(transaction.network) {
      return transaction.network
    }
    let fromChainId = "eip155:\(transaction.chainId)"
    if YieldXyzEvmTransactionParams.isEvmChainId(fromChainId) {
      return fromChainId
    }
    throw transactionError(
      context,
      transaction,
      reason: .invalidSignablePayload,
      message: "Transaction \(transaction.id) does not identify an EVM chain (network \"\(transaction.network)\", chainId \"\(transaction.chainId)\")."
    )
  }
}

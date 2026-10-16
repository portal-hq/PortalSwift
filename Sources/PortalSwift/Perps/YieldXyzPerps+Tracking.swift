//
//  YieldXyzPerps+Tracking.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// Submitting with reconciliation, and reading the action back until it settles.
extension YieldXyzPerps {
  /// Submits, retrying only when that is known to be safe: after a `429` (the request was not
  /// processed), or after an ambiguous failure once the action shows the transaction was not
  /// recorded and the submission is a transaction hash (recording a hash cannot execute anything
  /// twice). A signature is never resubmitted after an ambiguous failure.
  func submitWithReconciliation(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    body: SubmitBody
  ) async throws -> YieldXyzPerpsSubmitResult? {
    var params = YieldXyzPerpsSubmitTransactionParams(transactionId: transaction.id)
    var transactionHash: String?
    switch body {
    case let .signature(signature):
      params.signedPayload = signature
      params.actionId = context.actionId
    case let .transactionHash(hash):
      params.transactionHash = hash
      transactionHash = hash
    }

    var rateLimitRetries = 0
    var hashResubmitted = false

    while true {
      let failure: Error
      do {
        let result = try await api.submitTransaction(params: params).data
        if result.status == .failed {
          throw transactionError(
            context,
            transaction,
            reason: .submitFailed,
            message: "Yield.xyz reported transaction \(transaction.id) as FAILED\(result.error.map { ": \($0)" } ?? "").",
            broadcastHash: transactionHash
          )
        }
        return result
      } catch let error as YieldXyzPerpsExecutionError {
        throw error
      } catch let error where Self.isCancellation(error) {
        throw CancellationError()
      } catch {
        failure = error
      }

      if YieldXyzRequestFailure.status(of: failure) == 429, rateLimitRetries < retryPolicy.rateLimitDelays.count {
        try await Self.sleep(seconds: retryPolicy.rateLimitDelays[rateLimitRetries])
        rateLimitRetries += 1
        continue
      }

      if !YieldXyzRequestFailure.isAmbiguous(failure) {
        throw transactionError(
          context,
          transaction,
          reason: .submitRejected,
          message: YieldXyzRequestFailure.isRefusedBeforeSending(failure)
            ? "The submission of transaction \(transaction.id) could not be sent."
            : "Yield.xyz rejected the submission of transaction \(transaction.id).",
          broadcastHash: transactionHash,
          underlyingError: failure
        )
      }

      let outcome = try await reconcileSubmission(context, transaction, broadcastHash: transactionHash)
      if outcome == .recorded {
        return nil
      }
      if outcome == .notRecorded, transactionHash != nil, !hashResubmitted {
        hashResubmitted = true
        continue
      }

      throw transactionError(
        context,
        transaction,
        reason: .submitOutcomeUnknown,
        message: "The submission of transaction \(transaction.id) failed and its outcome could not be confirmed; check the action before retrying.",
        broadcastHash: transactionHash,
        underlyingError: failure
      )
    }
  }

  func reconcileSubmission(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    broadcastHash: String?
  ) async throws -> ReconciliationOutcome {
    let action: YieldXyzPerpsAction
    do {
      action = try await api.getAction(actionId: context.actionId).data
    } catch let error where Self.isCancellation(error) {
      throw CancellationError()
    } catch {
      logger.warn("YieldXyzPerps - Could not read action \(context.actionId) to reconcile a failed submission: \(error.localizedDescription)")
      return .unknown
    }

    guard let latest = action.transactions.first(where: { $0.id == transaction.id }) else {
      return .unknown
    }
    context.latestAction = action

    if Self.recordedTransactionStatuses.contains(latest.status) {
      return .recorded
    }
    if latest.status == .failed {
      throw transactionError(
        context,
        transaction,
        reason: .submitFailed,
        message: "Yield.xyz reported transaction \(transaction.id) as FAILED.",
        broadcastHash: broadcastHash,
        action: action
      )
    }
    // An ended action leaves its unsubmitted transactions CREATED: they are not awaiting a
    // submission any more.
    if Self.failedActionStatuses.contains(action.status) {
      throw transactionError(
        context,
        transaction,
        reason: .actionFailed,
        message: "Action \(context.actionId) ended with status \(action.status).",
        broadcastHash: broadcastHash,
        action: action
      )
    }
    return Self.signableTransactionStatuses.contains(latest.status) ? .notRecorded : .unknown
  }

  /// Polls until the action is final or has new pending transactions to sign.
  func pollForProgress(
    _ context: ExecutionContext,
    processed: Set<String>,
    pollOptions: YieldXyzPerpsPollOptions
  ) async throws -> YieldXyzPerpsAction {
    try await pollAction(
      context,
      schedule: pollOptions,
      check: { action in
        Self.finalActionStatuses.contains(action.status) || Self.hasTransactionsToSign(action, processed: processed) ? action : nil
      },
      timeoutMessage: { "Action \(context.actionId) did not reach a final status in time (last status \(context.latestAction.status))." }
    )
  }

  /// Reads the action back until `check` returns a value. Rate limits, 5xx, transport failures and
  /// undecodable bodies are retried up to `maxConsecutivePollErrors` times in a row; any other
  /// failure stops polling. The wait between reads grows by 1.5× up to `maxPollInterval`.
  func pollAction<T>(
    _ context: ExecutionContext,
    schedule: YieldXyzPerpsPollOptions,
    check: (YieldXyzPerpsAction) -> T?,
    timeoutMessage: () -> String
  ) async throws -> T {
    var consecutiveErrors = 0
    do {
      // The action is read at least once, even with a zero timeout.
      return try await YieldXyzPollLoop.run(
        intervalSeconds: schedule.intervalSeconds,
        timeoutSeconds: schedule.timeoutSeconds,
        minIntervalSeconds: retryPolicy.minPollInterval,
        maxIntervalSeconds: retryPolicy.maxPollInterval
      ) { () async throws -> YieldXyzPollStep<T> in
        var action: YieldXyzPerpsAction?
        var failure: Error?
        do {
          action = try await api.getAction(actionId: context.actionId).data
        } catch let error where Self.isCancellation(error) {
          throw CancellationError()
        } catch {
          failure = error
        }

        if let action {
          consecutiveErrors = 0
          context.latestAction = action
          emit(context, YieldXyzPerpsExecutionProgress(step: .polling, actionId: context.actionId, actionStatus: action.status))
          if let value = check(action) {
            return .stop(value)
          }
          return .continue
        }

        consecutiveErrors += 1
        let transient = failure.map(YieldXyzRequestFailure.isTransient) ?? true
        if !transient || consecutiveErrors >= retryPolicy.maxConsecutivePollErrors {
          throw YieldXyzPerpsExecutionError(
            reason: .pollingFailed,
            message: "Reading action \(context.actionId) failed.",
            actionId: context.actionId,
            action: context.latestAction,
            underlyingError: failure
          )
        }
        return .continue
      }
    } catch is YieldXyzPollLoopTimeout {
      throw YieldXyzPerpsExecutionError(
        reason: .timeout,
        message: timeoutMessage(),
        actionId: context.actionId,
        action: context.latestAction
      )
    }
  }

  static func sleep(seconds: TimeInterval) async throws {
    try await YieldXyzExecutionClock.sleep(seconds: seconds)
  }
}

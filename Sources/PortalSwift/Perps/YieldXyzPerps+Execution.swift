//
//  YieldXyzPerps+Execution.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// The execution runner: its state, the pass over an action's transactions, and the EIP-712 leg.
extension YieldXyzPerps {
  /// The mutable state of one execution.
  final class ExecutionContext {
    let actionId: String
    let walletAddress: String
    let options: YieldXyzPerpsExecuteOptions
    var latestAction: YieldXyzPerpsAction

    init(actionId: String, walletAddress: String, options: YieldXyzPerpsExecuteOptions, latestAction: YieldXyzPerpsAction) {
      self.actionId = actionId
      self.walletAddress = walletAddress
      self.options = options
      self.latestAction = latestAction
    }
  }

  enum SubmitBody {
    case signature(String)
    case transactionHash(String)
  }

  enum ReconciliationOutcome {
    case recorded
    case notRecorded
    case unknown
  }

  static func awaitsSignature(_ transaction: YieldXyzPerpsTransaction) -> Bool {
    signableTransactionStatuses.contains(transaction.status)
  }

  /// Whether `action` lists a transaction awaiting a signature that this execution has not
  /// processed yet.
  static func hasTransactionsToSign(_ action: YieldXyzPerpsAction, processed: Set<String>) -> Bool {
    action.transactions.contains { !processed.contains($0.id) && awaitsSignature($0) }
  }

  /// Whether `error` stops the execution as a cancellation. URLSession reports a cancelled task as
  /// `URLError(.cancelled)`, not `CancellationError`; that counts only while the surrounding task
  /// is cancelled, so a request cancelled for any other reason stays an ordinary failure.
  static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError {
      return true
    }
    return (error as? URLError)?.code == .cancelled && Task.isCancelled
  }

  func emit(_ context: ExecutionContext, _ progress: YieldXyzPerpsExecutionProgress) {
    context.options.onProgress?(progress)
  }

  func transactionError(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    reason: YieldXyzPerpsExecutionErrorReason,
    message: String,
    broadcastHash: String? = nil,
    action: YieldXyzPerpsAction? = nil,
    underlyingError: Error? = nil
  ) -> YieldXyzPerpsExecutionError {
    YieldXyzPerpsExecutionError(
      reason: reason,
      message: message,
      actionId: context.actionId,
      transactionId: transaction.id,
      broadcastHash: broadcastHash,
      transactionHash: broadcastHash,
      action: action ?? context.latestAction,
      underlyingError: underlyingError
    )
  }

  func resolveWalletAddressForSigning(_ action: YieldXyzPerpsAction) async throws -> String {
    var walletAddress: String?
    var cause: Error?
    do {
      walletAddress = try await dependencies.getWalletAddress?()
    } catch let error where Self.isCancellation(error) {
      throw CancellationError()
    } catch {
      cause = error
    }
    guard let walletAddress, !walletAddress.isEmpty else {
      throw YieldXyzPerpsExecutionError(
        reason: .missingWalletAddress,
        message: "No Portal EVM wallet address is available to sign with.",
        actionId: action.id,
        action: action,
        underlyingError: cause
      )
    }
    return walletAddress
  }

  /// Reads the action back before `listed` is signed: the action passed in, or one read before an
  /// earlier transaction was processed, may be stale. The transaction is signed only while it still
  /// awaits a signature, and with the payload Yield.xyz lists now.
  func readBeforeSigning(
    _ context: ExecutionContext,
    listed: YieldXyzPerpsTransaction
  ) async throws -> YieldXyzPerpsTransaction? {
    let current = try await pollAction(
      context,
      schedule: context.options.pollOptions,
      check: { $0 },
      timeoutMessage: { "Reading action \(context.actionId) before signing transaction \(listed.id) timed out (last status \(context.latestAction.status))." }
    )

    guard let latest = current.transactions.first(where: { $0.id == listed.id }) else {
      logger.warn("YieldXyzPerps - Transaction \(listed.id) is no longer listed for action \(context.actionId); it is not signed.")
      return nil
    }
    return Self.awaitsSignature(latest) ? latest : nil
  }

  func processTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let signingFormat = transaction.signingFormat
    guard signingFormat == .eip712TypedData || signingFormat == .evmTransaction else {
      throw transactionError(
        context,
        transaction,
        reason: .unsupportedSigningFormat,
        message: "Transaction \(transaction.id) uses signing format \"\(signingFormat?.rawValue ?? "none")\", which is not supported."
      )
    }

    guard transaction.address.lowercased() == context.walletAddress.lowercased() else {
      throw transactionError(
        context,
        transaction,
        reason: .signerAddressMismatch,
        message: "Transaction \(transaction.id) was built for \(transaction.address), not the Portal wallet \(context.walletAddress)."
      )
    }

    if signingFormat == .eip712TypedData {
      return try await processTypedDataTransaction(context, transaction: transaction, index: index)
    }
    return try await processEvmTransaction(context, transaction: transaction, index: index)
  }

  func processTypedDataTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let typedData: [String: Any]
    switch YieldXyzPerpsPayloads.prepareTypedData(transaction.signablePayload) {
    case let .success(prepared):
      typedData = prepared
    case let .failure(problem):
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) \(problem.description)."
      )
    }
    guard let typedDataJSON = YieldXyzPerpsPayloads.typedDataJSON(typedData) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) cannot be encoded as JSON."
      )
    }

    let chainId = context.options.signingChainId
    try await assertSigningChain(context, transaction, chainId: chainId)

    guard let signTypedData = context.options.signTypedData ?? dependencies.signTypedData else {
      throw transactionError(context, transaction, reason: .dependencyUnavailable, message: "No typed-data signer is configured.")
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .signing,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
    ))

    let returned: String?
    do {
      returned = try await signTypedData(YieldXyzPerpsSignTypedDataRequest(
        address: context.walletAddress,
        typedData: typedDataJSON,
        chainId: chainId
      ))
    } catch let error where Self.isCancellation(error) {
      throw CancellationError()
    } catch {
      throw transactionError(
        context,
        transaction,
        reason: .signingFailed,
        message: "Signing transaction \(transaction.id) failed.",
        underlyingError: error
      )
    }

    guard let returned else {
      throw transactionError(
        context,
        transaction,
        reason: .signatureRejected,
        message: "The signing request for transaction \(transaction.id) was rejected."
      )
    }
    // The signer returns the signature hex-encoded; accept it with or without the `0x` prefix.
    let digits = returned.hasPrefix("0x") || returned.hasPrefix("0X") ? String(returned.dropFirst(2)) : returned
    let signature = "0x" + digits
    guard YieldXyzPerpsPayloads.isSignature(signature) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignature,
        message: "The signer did not return a 65-byte hex signature for transaction \(transaction.id)."
      )
    }

    let submitResult = try await submitWithReconciliation(context, transaction, body: .signature(signature))

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .submitted,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
    ))

    return YieldXyzPerpsTransactionExecution(
      transactionId: transaction.id,
      type: transaction.type,
      signingFormat: .eip712TypedData,
      signedPayload: signature,
      submitResult: submitResult
    )
  }

  func assertSigningChain(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    chainId: String
  ) async throws {
    guard chainId.hasPrefix("eip155:") else {
      throw transactionError(
        context,
        transaction,
        reason: .signingChainNotConfigured,
        message: "Transaction \(transaction.id) must be signed through an EIP-155 chain, got \"\(chainId)\"."
      )
    }
    if let isChainConfigured = dependencies.isChainConfigured, !(await isChainConfigured(chainId)) {
      throw transactionError(
        context,
        transaction,
        reason: .signingChainNotConfigured,
        message: "No RPC endpoint is configured for \(chainId); add it to rpcConfig to sign transaction \(transaction.id)."
      )
    }
  }
}

//
//  YieldXyz.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Protocol defining the interface for YieldXyz provider functionality.
public protocol YieldXyzProtocol {
  /// Discovers yield opportunities based on the provided parameters.
  /// - Parameter request: Optional parameters for yield discovery. If nil, uses default parameters.
  /// - Returns: A `YieldXyzGetYieldsResponse` containing available yield opportunities.
  /// - Throws: An error if the operation fails.
  func discover(request: YieldXyzGetYieldsRequest?) async throws -> YieldXyzGetYieldsResponse

  /// Enters a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for entering a yield opportunity.
  /// - Returns: A `YieldXyzEnterYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  func enter(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse

  /// Tracks a transaction by submitting its hash to the Yield.xyz integration.
  /// - Parameters:
  ///   - transactionId: The ID of the transaction to track.
  ///   - txHash: The hash of the transaction to submit.
  /// - Returns: A `YieldXyzTrackTransactionResponse` containing the result.
  /// - Throws: An error if the operation fails.
  func track(transactionId: String, txHash: String) async throws -> YieldXyzTrackTransactionResponse

  /// Retrieves yield balances for specified addresses and networks.
  /// - Parameter request: The parameters for the yield balances request.
  /// - Returns: A `YieldXyzGetBalancesResponse` containing balance information.
  /// - Throws: An error if the operation fails.
  func getBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse

  /// Retrieves a single yield action transaction by its ID.
  /// - Parameter transactionId: The ID of the transaction to retrieve.
  /// - Returns: A `YieldXyzGetTransactionResponse` containing transaction details.
  /// - Throws: An error if the operation fails.
  func getTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse

  /// Retrieves historical yield actions with optional filtering.
  /// - Parameter request: The parameters for the historical yield actions request.
  /// - Returns: A `YieldXyzGetHistoricalActionsResponse` containing historical actions.
  /// - Throws: An error if the operation fails.
  func getHistoricalActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse

  /// Manages a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for managing a yield opportunity.
  /// - Returns: A `YieldXyzManageYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  func manage(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse

  /// Exits a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for exiting a yield opportunity.
  /// - Returns: A `YieldXyzExitResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  func exit(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse

  /// High-level deposit: resolves the yield, builds enter transactions, signs and submits each
  /// transaction sequentially, waits for confirmation, and tracks each hash.
  /// - Parameters:
  ///   - params: Either an explicit `yieldId` + `amount`, or `chain` (full CAIP-2) + `token` + `amount`.
  ///   - options: Optional progress callback and confirmation polling tuning.
  /// - Returns: A `YieldDepositResult` with the submitted hashes, yield id, status and action details.
  /// - Throws: `YieldXyzError` or network/signing errors.
  func deposit(params: YieldDepositParams, options: YieldSubmitOptions?) async throws -> YieldDepositResult

  /// High-level withdraw; same parameters and behavior as `deposit`.
  func withdraw(params: YieldWithdrawParams, options: YieldSubmitOptions?) async throws -> YieldWithdrawResult

  /// Returns the available validators for a native-staking yield.
  /// - Parameter yieldId: The yield identifier.
  /// - Returns: The validators for the yield.
  /// - Throws: `YieldXyzError.apiError` if the backend returns an error payload,
  ///   `YieldXyzError.noValidators` if the validators list is missing or empty, or network errors.
  func getValidators(yieldId: String) async throws -> [YieldXyzValidator]
}

public extension YieldXyzProtocol {
  /// Convenience overload of `deposit` without options.
  func deposit(params: YieldDepositParams) async throws -> YieldDepositResult {
    try await deposit(params: params, options: nil)
  }

  /// Convenience overload of `withdraw` without options.
  func withdraw(params: YieldWithdrawParams) async throws -> YieldWithdrawResult {
    try await withdraw(params: params, options: nil)
  }
}

/// YieldXyz provider implementation for discovering and managing yield opportunities.
public class YieldXyz: YieldXyzProtocol {
  private let api: PortalYieldXyzApiProtocol
  /// Portal dependency used by `deposit`/`withdraw` for signing, address resolution and confirmation.
  /// Held weakly to avoid a retain cycle with `Portal`.
  private weak var portal: YieldXyzPortalDependency?
  private let logger = PortalLogger.shared

  /// Create an instance of YieldXyz.
  /// - Parameters:
  ///   - api: The PortalYieldXyzApi instance to use for yield operations.
  ///   - portal: The portal (or mock) providing `request`, `getAddress` and `getTransactionDetails`.
  ///     Required for high-level `deposit`/`withdraw`; may be `nil` when only the low-level API is used.
  public init(api: PortalYieldXyzApiProtocol, portal: YieldXyzPortalDependency? = nil) {
    self.api = api
    self.portal = portal
  }

  /// Discovers yield opportunities based on the provided parameters.
  /// - Parameter request: Optional parameters for yield discovery. If nil, uses default parameters.
  /// - Returns: A `YieldXyzGetYieldsResponse` containing available yield opportunities.
  /// - Throws: An error if the operation fails.
  public func discover(request: YieldXyzGetYieldsRequest? = nil) async throws -> YieldXyzGetYieldsResponse {
    let discoveryRequest = request ?? YieldXyzGetYieldsRequest()
    return try await api.getYields(request: discoveryRequest)
  }

  /// Enters a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for entering a yield opportunity.
  /// - Returns: A `YieldXyzEnterYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func enter(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse {
    return try await api.enterYield(request: request)
  }

  /// Tracks a transaction by submitting its hash to the Yield.xyz integration.
  /// - Parameters:
  ///   - transactionId: The ID of the transaction to track.
  ///   - txHash: The hash of the transaction to submit.
  /// - Returns: `true` if the submission was successful.
  /// - Throws: An error if the operation fails.
  @discardableResult
  public func track(transactionId: String, txHash: String) async throws -> YieldXyzTrackTransactionResponse {
    let request = YieldXyzTrackTransactionRequest(transactionId: transactionId, hash: txHash)
    return try await api.submitTransactionHash(request: request)
  }

  /// Retrieves yield balances for specified addresses and networks.
  /// - Parameter request: The parameters for the yield balances request.
  /// - Returns: A `YieldXyzGetBalancesResponse` containing balance information.
  /// - Throws: An error if the operation fails.
  public func getBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse {
    return try await api.getYieldBalances(request: request)
  }

  /// Retrieves a single yield action transaction by its ID.
  /// - Parameter transactionId: The ID of the transaction to retrieve.
  /// - Returns: A `YieldXyzGetTransactionResponse` containing transaction details.
  /// - Throws: An error if the operation fails.
  public func getTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse {
    return try await api.getYieldTransaction(transactionId: transactionId)
  }

  /// Retrieves historical yield actions with optional filtering.
  /// - Parameter request: The parameters for the historical yield actions request.
  /// - Returns: A `YieldXyzGetHistoricalActionsResponse` containing historical actions.
  /// - Throws: An error if the operation fails.
  public func getHistoricalActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse {
    return try await api.getHistoricalYieldActions(request: request)
  }

  /// Manages a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for managing a yield opportunity.
  /// - Returns: A `YieldXyzManageYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func manage(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse {
    return try await api.manageYield(request: request)
  }

  /// Exits a yield opportunity with the specified parameters.
  /// - Parameter request: The parameters for exiting a yield opportunity.
  /// - Returns: A `YieldXyzExitResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func exit(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse {
    return try await api.exitYield(request: request)
  }

  // MARK: - High-level deposit / withdraw

  public func deposit(params: YieldDepositParams, options: YieldSubmitOptions? = nil) async throws -> YieldDepositResult {
    let resolved = try await resolveYieldIdAndChain(params: params)
    let address = try await resolveAddress(forCaip2: resolved.chainCaip2)
    let arguments = mergeAmount(params.amount, into: params.arguments)
    let request = YieldXyzEnterRequest(yieldId: resolved.yieldId, address: address, arguments: arguments)

    let response = try await api.enterYield(request: request)
    guard let raw = response.data?.rawResponse else {
      if let error = response.error { throw YieldXyzError.apiError(error) }
      throw YieldXyzError.noTransactions
    }

    let base = try await executeAndTrack(
      transactions: raw.transactions,
      yieldId: raw.yieldId,
      details: makeDetails(yieldId: raw.yieldId, intent: raw.intent, type: raw.type, executionPattern: raw.executionPattern, status: raw.status, amount: raw.amount, amountUsd: raw.amountUsd),
      fromAddress: address,
      options: options
    )

    return YieldDepositResult(
      hashes: base.hashes,
      yieldId: base.yieldId,
      status: base.status,
      chain: resolved.resolvedChain,
      token: resolved.resolvedToken,
      yieldOpportunityDetails: base.details
    )
  }

  public func withdraw(params: YieldWithdrawParams, options: YieldSubmitOptions? = nil) async throws -> YieldWithdrawResult {
    let resolved = try await resolveYieldIdAndChain(params: params)
    let address = try await resolveAddress(forCaip2: resolved.chainCaip2)
    let arguments = mergeAmount(params.amount, into: params.arguments)
    let request = YieldXyzExitRequest(yieldId: resolved.yieldId, address: address, arguments: arguments)

    let response = try await api.exitYield(request: request)
    guard let raw = response.data?.rawResponse else {
      if let error = response.error { throw YieldXyzError.apiError(error) }
      throw YieldXyzError.noTransactions
    }

    let base = try await executeAndTrack(
      transactions: raw.transactions,
      yieldId: raw.yieldId,
      details: makeDetails(yieldId: raw.yieldId, intent: raw.intent, type: raw.type, executionPattern: raw.executionPattern, status: raw.status, amount: raw.amount, amountUsd: raw.amountUsd),
      fromAddress: address,
      options: options
    )

    return YieldWithdrawResult(
      hashes: base.hashes,
      yieldId: base.yieldId,
      status: base.status,
      chain: resolved.resolvedChain,
      token: resolved.resolvedToken,
      yieldOpportunityDetails: base.details
    )
  }

  public func getValidators(yieldId: String) async throws -> [YieldXyzValidator] {
    let response = try await api.getYieldValidators(yieldId: yieldId)
    if let error = response.error, !error.isEmpty {
      throw YieldXyzError.apiError(error)
    }
    let validators = response.data?.validators ?? response.data?.rawResponse?.validators ?? response.data?.rawResponse?.items
    guard let validators = validators, !validators.isEmpty else {
      throw YieldXyzError.noValidators(yieldId)
    }
    return validators
  }

  // MARK: - High-level helpers

  private struct ResolvedYield {
    let yieldId: String
    /// CAIP-2 chain id used to resolve the wallet address.
    let chainCaip2: String?
    /// Only set when resolved via chain + token (echoed back in the result).
    let resolvedChain: String?
    let resolvedToken: String?
  }

  private func resolveYieldIdAndChain(params: YieldDepositParams) async throws -> ResolvedYield {
    switch params.target {
    case let .yieldId(raw):
      let yieldId = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !yieldId.isEmpty else { throw YieldXyzError.emptyYieldId }
      let chain = try await resolveChainFromYieldId(yieldId)
      return ResolvedYield(yieldId: yieldId, chainCaip2: chain, resolvedChain: nil, resolvedToken: nil)
    case let .chainAndToken(chain, token):
      let caip2 = try requireFullCaip2(chain)
      let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
      let yieldId = try await resolveYieldIdFromDefaults(chainCaip2: caip2, token: trimmedToken)
      return ResolvedYield(yieldId: yieldId, chainCaip2: caip2, resolvedChain: caip2, resolvedToken: trimmedToken)
    }
  }

  private func requireFullCaip2(_ chain: String) throws -> String {
    let trimmed = chain.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: ":")
    guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
      throw YieldXyzError.invalidChainId(chain)
    }
    return trimmed
  }

  private func resolveYieldIdFromDefaults(chainCaip2: String, token: String) async throws -> String {
    guard !token.isEmpty else { throw YieldXyzError.noYieldForChainToken("\(chainCaip2):") }
    let response = try await api.getYieldDefaults(includeOpportunities: false)
    if let error = response.error, !error.isEmpty {
      throw YieldXyzError.apiError(error)
    }
    let key = "\(chainCaip2):\(token)"
    guard let entry = response.data?[key], let yieldId = entry.yieldId, !yieldId.isEmpty else {
      throw YieldXyzError.noYieldForChainToken(key)
    }
    return yieldId
  }

  private func resolveChainFromYieldId(_ yieldId: String) async throws -> String {
    let response = try await api.getYields(request: YieldXyzGetYieldsRequest(yieldId: yieldId))
    if let error = response.error, !error.isEmpty {
      throw YieldXyzError.apiError(error)
    }
    guard let network = response.data?.rawResponse.items.first?.network, !network.isEmpty else {
      throw YieldXyzError.yieldNotFound(yieldId)
    }
    return YieldNetwork.resolveToCaip2(network) ?? network
  }

  private func resolveAddress(forCaip2 chainCaip2: String?) async throws -> String {
    guard let portal = portal else { throw YieldXyzError.portalNotInitialized }
    guard let chainCaip2 = chainCaip2 else { throw YieldXyzError.addressUnavailable("unknown") }
    guard let address = await portal.getAddress(chainCaip2), !address.isEmpty else {
      throw YieldXyzError.addressUnavailable(chainCaip2)
    }
    return address
  }

  private func mergeAmount(_ amount: String, into arguments: YieldXyzEnterArguments?) -> YieldXyzEnterArguments {
    (arguments ?? YieldXyzEnterArguments()).withAmount(amount)
  }

  private func makeDetails(
    yieldId: String,
    intent: YieldXyzActionIntent?,
    type: YieldXyzActionType?,
    executionPattern: YieldXyzActionExecutionPattern?,
    status: YieldXyzActionStatus?,
    amount: String?,
    amountUsd: String?
  ) -> YieldOpportunityDetails {
    YieldOpportunityDetails(
      yieldId: yieldId,
      intent: intent,
      type: type,
      executionPattern: executionPattern,
      status: status,
      amount: amount,
      amountUsd: amountUsd
    )
  }

  private struct ExecuteResult {
    let hashes: [String]
    let yieldId: String
    let status: YieldSubmitResultStatus
    let details: YieldOpportunityDetails
  }

  private enum ConfirmationResult {
    case confirmed
    case failed
    case uncertain
    case skipped
  }

  private func executeAndTrack(
    transactions: [YieldXyzActionTransaction],
    yieldId: String,
    details: YieldOpportunityDetails,
    fromAddress: String,
    options: YieldSubmitOptions?
  ) async throws -> ExecuteResult {
    guard let portal = portal else { throw YieldXyzError.portalNotInitialized }
    guard !transactions.isEmpty else { throw YieldXyzError.noTransactions }

    let sorted = transactions.sorted { $0.stepIndex < $1.stepIndex }
    let total = sorted.count
    let waiterAvailable = sorted.contains { YieldNetwork.isEvm($0.network) || YieldNetwork.isSolana($0.network) }
    let confirmationsRequired = waiterAvailable ? total : 0

    var hashes: [String] = []
    var confirmationsReached = 0
    var failedEarly = false

    loop: for (index, tx) in sorted.enumerated() {
      guard !tx.id.isEmpty else { throw YieldXyzError.missingTransactionField("id") }
      guard !tx.network.isEmpty else { throw YieldXyzError.missingTransactionField("network for \(tx.id)") }
      guard let unsigned = tx.unsignedTransaction else {
        throw YieldXyzError.missingTransactionField("unsignedTransaction for \(tx.id)")
      }

      let isEvm = YieldNetwork.isEvm(tx.network)
      let isSolana = YieldNetwork.isSolana(tx.network)
      let chainId = isEvm ? (YieldNetwork.resolveToCaip2(tx.network) ?? tx.network) : tx.network

      options?.onProgress?(YieldSubmitProgress(step: .signing, index: index, total: total))

      let hash: String
      if isEvm {
        hash = try await signAndSendEvm(unsigned: unsigned, chainId: chainId, fromAddress: fromAddress, portal: portal)
      } else if isSolana {
        hash = try await signAndSendSolana(unsigned: unsigned, chainId: chainId, portal: portal)
      } else {
        throw YieldXyzError.unsupportedNetwork(tx.network)
      }
      hashes.append(hash)

      options?.onProgress?(YieldSubmitProgress(step: .submitted, index: index, total: total, hash: hash))

      if isEvm || isSolana {
        options?.onProgress?(YieldSubmitProgress(step: .confirming, index: index, total: total, hash: hash))
        let confirmation = try await waitForConfirmation(hash: hash, chainId: chainId, isEvm: isEvm, isSolana: isSolana, options: options, portal: portal)
        switch confirmation {
        case .confirmed:
          confirmationsReached += 1
          options?.onProgress?(YieldSubmitProgress(step: .confirmed, index: index, total: total, hash: hash))
          await trackHashBestEffort(transactionId: tx.id, hash: hash)
        case .failed:
          failedEarly = true
          await trackHashBestEffort(transactionId: tx.id, hash: hash)
          break loop
        case .uncertain:
          await trackHashBestEffort(transactionId: tx.id, hash: hash)
          break loop
        case .skipped:
          await trackHashBestEffort(transactionId: tx.id, hash: hash)
        }
      } else {
        await trackHashBestEffort(transactionId: tx.id, hash: hash)
      }
    }

    let status: YieldSubmitResultStatus
    if failedEarly {
      status = .failed
    } else if confirmationsRequired == 0 || confirmationsReached == confirmationsRequired {
      status = .success
    } else {
      status = .partialSuccess
    }

    return ExecuteResult(hashes: hashes, yieldId: yieldId, status: status, details: details)
  }

  private func signAndSendEvm(unsigned: String, chainId: String, fromAddress: String, portal: YieldXyzPortalDependency) async throws -> String {
    let dict = parseUnsignedToDict(unsigned)
    guard let to = dict["to"] as? String else { throw YieldXyzError.missingTransactionField("to") }

    let from = (dict["from"] as? String) ?? fromAddress
    let value = (dict["value"] as? String) ?? "0x0"
    let data = (dict["data"] as? String) ?? ""

    // Preserve fee fields; intentionally omit nonce so the MPC signer auto-fetches the pending nonce.
    var param = ETHTransactionParam(from: from, to: to, value: value, data: data)
    if let gas = (dict["gasLimit"] as? String) ?? (dict["gas"] as? String) { param.gas = gas }
    if let maxFeePerGas = dict["maxFeePerGas"] as? String { param.maxFeePerGas = maxFeePerGas }
    if let maxPriorityFeePerGas = dict["maxPriorityFeePerGas"] as? String { param.maxPriorityFeePerGas = maxPriorityFeePerGas }
    if let gasPrice = dict["gasPrice"] as? String { param.gasPrice = gasPrice }

    let result = try await portal.request(chainId: chainId, method: .eth_sendTransaction, params: [param], options: nil)
    guard let hash = result.result as? String else { throw YieldXyzError.invalidSignResponse }
    return hash
  }

  private func signAndSendSolana(unsigned: String, chainId: String, portal: YieldXyzPortalDependency) async throws -> String {
    // The serialized Yield.xyz transaction string is passed through to the MPC signer (matches RN).
    let result = try await portal.request(chainId: chainId, method: .sol_signAndSendTransaction, params: [unsigned], options: nil)
    guard let hash = result.result as? String else { throw YieldXyzError.invalidSignResponse }
    return hash
  }

  private func parseUnsignedToDict(_ unsigned: String) -> [String: Any] {
    guard let data = unsigned.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    // Unwrap a single nested object (mirrors RN's normalizeEvmTransactionParams).
    if object.count == 1, let key = object.keys.first, let inner = object[key] as? [String: Any] {
      return inner
    }
    return object
  }

  private func waitForConfirmation(
    hash: String,
    chainId: String,
    isEvm: Bool,
    isSolana: Bool,
    options: YieldSubmitOptions?,
    portal: YieldXyzPortalDependency
  ) async throws -> ConfirmationResult {
    let pollInterval = max(1, options?.pollIntervalSeconds ?? 4)
    let timeout = max(pollInterval, options?.timeoutSeconds ?? 900)
    let maxAttempts = max(1, timeout / pollInterval)
    let sleepNanos = UInt64(pollInterval) * 1_000_000_000

    if isEvm {
      for attempt in 0 ..< maxAttempts {
        // Poll immediately on the first attempt; sleep only between subsequent polls.
        if attempt > 0 {
          try await Task.sleep(nanoseconds: sleepNanos)
        }
        do {
          let response = try await portal.request(chainId: chainId, method: .eth_getTransactionReceipt, params: [hash], options: nil)
          if let receipt = response.result as? EthTransactionResponse, let status = receipt.result?.status {
            return status == "0x1" ? .confirmed : .failed
          }
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          // keep polling
        }
      }
      return .uncertain
    }

    if isSolana {
      for attempt in 0 ..< maxAttempts {
        if attempt > 0 {
          try await Task.sleep(nanoseconds: sleepNanos)
        }
        do {
          let details = try await portal.getTransactionDetails(chain: chainId, signature: hash)
          if let sol = details.data.solanaTransaction {
            if sol.error != nil { return .failed }
            let status = sol.status.lowercased()
            if status == "confirmed" || status == "finalized" || status == "success" { return .confirmed }
            if status == "failed" { return .failed }
          }
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          // keep polling
        }
      }
      return .uncertain
    }

    return .skipped
  }

  private func trackHash(transactionId: String, hash: String) async throws {
    _ = try await api.submitTransactionHash(request: YieldXyzTrackTransactionRequest(transactionId: transactionId, hash: hash))
  }

  /// Best-effort hash tracking: failures are logged but do not fail the overall deposit/withdraw result.
  private func trackHashBestEffort(transactionId: String, hash: String) async {
    do {
      try await trackHash(transactionId: transactionId, hash: hash)
    } catch {
      logger.error(
        "YieldXyz.trackHashBestEffort() - Failed to submit transaction hash for transactionId=\(transactionId) hash=\(hash): \(error.localizedDescription)"
      )
    }
  }
}

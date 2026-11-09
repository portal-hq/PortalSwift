//
//  AggErrors.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Stable error identifiers the Portal API returns as `id` for Agg requests. Branch on these, never
/// on the message.
public enum AggErrorId {
  /// The client is not linked to Agg, or its Agg session expired: run `connect` again, then retry.
  public static let linkRequired = "AGG_LINK_REQUIRED"
  /// The client is account-abstracted. Linking and trading are unavailable; discovery and market
  /// data still work.
  public static let accountAbstractionUnsupported = "AGG_ACCOUNT_ABSTRACTION_UNSUPPORTED"
  /// Another request is renewing this client's Agg session. Retry shortly.
  public static let sessionRefreshInProgress = "AGG_SESSION_REFRESH_IN_PROGRESS"
  /// Agg changed a response shape; the feature is unavailable until Portal adapts. Not the caller's
  /// fault: treat it as a temporary outage, and do not retry in a tight loop.
  public static let integrationResponseSchemaDrift = "INTEGRATION_RESPONSE_SCHEMA_DRIFT"
}

/// A failed Agg request, with the `X-Portal-Trace-Id` it was sent with. Include `traceId` when you
/// report a failure to Portal: it finds the request in Portal's logs.
///
/// Every `PortalAggApi` request that was sent fails with this error; read the Portal error behind it
/// with `AggApiError.from(_:)`.
public struct AggRequestError: LocalizedError {
  public let traceId: String
  /// The transport's error (`PortalRequestsError`, `URLError`) or a `DecodingError`.
  public let underlyingError: Error

  public init(traceId: String, underlyingError: Error) {
    self.traceId = traceId
    self.underlyingError = underlyingError
  }

  public var errorDescription: String? {
    "\(underlyingError.localizedDescription) (trace id \(traceId))"
  }
}

/// Agg's reasons for declining a request, from the error's `details`.
public struct AggErrorDetails: Equatable {
  /// Agg's machine-readable code, when Agg sent one. Open-ended.
  public let code: String?
  /// The request fields Agg's validation rejected; empty when it named none.
  public let fields: [String]

  public init(code: String? = nil, fields: [String] = []) {
    self.code = code
    self.fields = fields
  }
}

/// A failed Agg request as the Portal API reported it. Two kinds reach a caller:
/// - Portal's own refusals carry an `id` (see `AggErrorId`).
/// - Agg's declines are passed through with Agg's status (400, 403, 404, 409, 422 or 429), no `id`, a
///   message starting `Agg rejected the request:`, and Agg's `details` when it sent them. A 403 on a
///   trading route usually means the user's location is blocked.
public struct AggApiError: Error, Equatable {
  /// The HTTP status, when the request reached the Portal API.
  public let status: Int?
  /// The stable error identifier, when the Portal API sent one.
  public let id: String?
  /// The response's `error` message, or its raw body when it is not a Portal error object.
  public let message: String?
  /// Agg's reasons for a decline, when the response carried `details`.
  public let details: AggErrorDetails?
  /// The `X-Portal-Trace-Id` the request was sent with.
  public let traceId: String?

  public init(
    status: Int?,
    id: String? = nil,
    message: String? = nil,
    details: AggErrorDetails? = nil,
    traceId: String? = nil
  ) {
    self.status = status
    self.id = id
    self.message = message
    self.details = details
    self.traceId = traceId
  }

  /// The Portal API error behind `error`, unwrapping an `AggRequestError`. `nil` when `error` is not
  /// an HTTP failure (for example a transport or decoding error, or an `AggError`).
  public static func from(_ error: Error?) -> AggApiError? {
    switch error {
    case let apiError as AggApiError:
      return apiError
    case let requestError as AggRequestError:
      return from(requestError.underlyingError).map {
        AggApiError(status: $0.status, id: $0.id, message: $0.message, details: $0.details, traceId: requestError.traceId)
      }
    case let requestsError as PortalRequestsError:
      return YieldXyzApiErrorBody.parse(requestsError).map {
        AggApiError(status: $0.status, id: $0.id, message: $0.message, details: details(from: $0))
      }
    default:
      return nil
    }
  }

  private static func details(from body: YieldXyzApiErrorBody) -> AggErrorDetails? {
    guard let details = body.details else {
      return nil
    }
    let fields = (details["fields"]?.value as? [Any])?.compactMap { $0 as? String } ?? []
    return AggErrorDetails(code: details["code"]?.value as? String, fields: fields)
  }

  /// `true` for `AGG_LINK_REQUIRED`: run `connect` again, then retry.
  public var isLinkRequired: Bool {
    id == AggErrorId.linkRequired
  }

  /// `true` for `AGG_ACCOUNT_ABSTRACTION_UNSUPPORTED`.
  public var isAccountAbstractionUnsupported: Bool {
    id == AggErrorId.accountAbstractionUnsupported
  }

  /// `true` for `AGG_SESSION_REFRESH_IN_PROGRESS`.
  public var isSessionRefreshInProgress: Bool {
    id == AggErrorId.sessionRefreshInProgress
  }

  /// `true` for `INTEGRATION_RESPONSE_SCHEMA_DRIFT`.
  public var isSchemaDrift: Bool {
    id == AggErrorId.integrationResponseSchemaDrift
  }

  /// `true` for a `429` rate limit.
  public var isRateLimit: Bool {
    status == 429
  }
}

/// A request the SDK refuses before sending it, or a helper's outcome.
public enum AggError: LocalizedError {
  /// No Portal EVM wallet address is available to link.
  case noAddress
  /// No RPC URL is configured for `chainId`: `connect` cannot sign the link on it, and `deposit`
  /// cannot send on it. Nothing was signed or sent.
  case missingRpcUrl(chainId: String)
  /// The link challenge names an address other than the Portal wallet's, so it is not signed.
  case addressMismatch(expected: String, actual: String?)
  /// A path id (`eventId`, `outcomeId`, `quoteId` or `withdrawalId`) is empty: the request would
  /// reach a different route.
  case emptyIdentifier(name: String)
  /// A helper amount is not a positive decimal, has more decimals than the API takes, or (for a
  /// limit price) is not between 0 and 1.
  case invalidAmount(name: String, value: String)
  /// A helper needs something `Portal` provides; a standalone `Agg` was built without it.
  case missingDependency(name: String)
  /// A call was refused with `AGG_LINK_REQUIRED`, and the `connect` that `autoReconnect` ran failed
  /// (`underlyingError`, for example a declined signature or a network error). The refused call did
  /// nothing and was not sent again. The helper does not retry the reconnect, which would ask the
  /// user to sign again: run `connect`, then call the helper again.
  case reconnectFailed(underlyingError: Error)
  /// Agg does not take deposits of `token` on `chainId`; nothing was sent.
  case unsupportedDepositToken(chainId: String, token: String)
  /// `token` names more than one token on `chainId`; nothing was sent. A token is its chain and
  /// address, and a symbol is not unique. `candidates` are every token it matched, as Agg lists them,
  /// sorted by address: they differ in address (pass the address of the one to deposit), or share
  /// one with conflicting decimals (do not deposit it until Agg fixes its listing).
  case ambiguousDepositToken(chainId: String, token: String, candidates: [AggSupportedChainToken])
  /// The quote cannot be filled: its `status` is not `ok`, a venue reported a warning, or Agg
  /// attached an `error` (for example an unfunded venue balance). Nothing was traded. Show
  /// `quote.warnings[].reason`, `quote.error` or the status to the user.
  case quoteNotTradable(quote: AggQuote)
  /// The fill finished without trading: `failed`, `cancelled`, `expired`, or a final state this SDK
  /// does not know. `status` holds the final read, with `errorReason`.
  case orderFailed(status: AggExecutionStatus)
  /// The withdrawal preview did not price the amount; nothing was sent. Show
  /// `preview.unviableReason` to the user.
  case withdrawalNotViable(preview: AggWithdrawalPreview)
  /// The withdrawal finished `failed`; `withdrawal` holds the final read, with `errorMessage`.
  case withdrawalFailed(withdrawal: AggWithdrawal)
  /// `deposit` stopped waiting for Agg to create the deposit addresses. Nothing was sent, so it is
  /// safe to call `deposit` again. `last` is the last read, `nil` when no read succeeded.
  case depositAddressesTimeout(last: AggDepositAddresses?)
  /// A helper stopped waiting for a fill to finish; it may still finish. `last` is the last read,
  /// `nil` when no read succeeded.
  case orderTimeout(quoteId: String, last: AggExecutionStatus?)
  /// A helper stopped waiting for a withdrawal to finish; it may still finish. `last` is the last
  /// read, `nil` when no read succeeded.
  case withdrawalTimeout(withdrawalId: String, last: AggWithdrawal?)
  /// The fill may have gone through, but `buy` or `sell` could not see how it ended: the fill's
  /// response was lost (`fill` is `nil`), or reading its progress failed or timed out
  /// (`underlyingError`, for example `orderTimeout`). Do not call `buy` or `sell` again, which would
  /// trade again: read `getOrder(quoteId: quote.quoteId)` until it is `terminal`. `last` is the
  /// last read, `nil` when none succeeded.
  case orderOutcomeUnknown(quote: AggQuote, fill: AggFill?, last: AggExecutionStatus?, underlyingError: Error)
  /// The withdrawal may have been created, but `withdraw` could not see how it ended: its response
  /// was lost (`withdrawal` is `nil`), or reading its status failed or timed out (`underlyingError`,
  /// for example `withdrawalTimeout`). Do not call `withdraw` again: its preview can refuse an amount
  /// that already left. Read `getWithdrawal(withdrawalId:)`, or, when `withdrawal` is `nil`, send
  /// `request` again with `createWithdrawal`: its `requestId` returns the original withdrawal
  /// instead of sending twice.
  case withdrawalOutcomeUnknown(
    request: AggWithdrawalRequest,
    withdrawal: AggWithdrawal?,
    last: AggWithdrawal?,
    underlyingError: Error
  )
  /// The deposit may have been sent, but `deposit` could not see how it ended: `sendAsset` failed
  /// after it could have broadcast the transfer (`underlyingError`, for example a lost connection,
  /// or Portal refusing a key whose send already went out or failed), or returned no transaction
  /// hash. Retry with `AggDepositParams(idempotencyKey:)` set to `idempotencyKey`, which Portal never
  /// broadcasts twice. Do not deposit with a new key until `getBalances(sync: true, mode: nil)` (or
  /// the chain) shows this one did not land: that could send it twice.
  case depositOutcomeUnknown(
    idempotencyKey: String,
    chainId: String,
    depositAddress: String,
    token: AggSupportedChainToken,
    amount: String,
    underlyingError: Error
  )

  public var errorDescription: String? {
    switch self {
    case .noAddress:
      return "[Agg] No Portal EVM wallet address is available."
    case let .missingRpcUrl(chainId):
      return "[Agg] No RPC URL is configured for \(chainId); add it to rpcConfig or use another chain."
    case let .addressMismatch(expected, actual):
      return "[Agg] The link challenge is for \(actual ?? "no address"), not the wallet address \(expected)."
    case let .emptyIdentifier(name):
      return "[Agg] \(name) must not be empty."
    case let .invalidAmount(name, value):
      return "[Agg] \(name) is not a valid amount: \"\(value)\"."
    case let .missingDependency(name):
      return "[Agg] This helper needs a \(name) dependency."
    case let .reconnectFailed(underlyingError):
      return "[Agg] A call was refused with AGG_LINK_REQUIRED and linking again failed, so it was not retried; run connect, then try again: \(underlyingError.localizedDescription)"
    case let .unsupportedDepositToken(chainId, token):
      return "[Agg] Agg does not take \(token) deposits on \(chainId); see the deposit addresses' supportedChains."
    case let .ambiguousDepositToken(chainId, token, candidates):
      if let first = candidates.first, candidates.allSatisfy({ Agg.isSameTokenAddress(chainId: chainId, $0.address, first.address) }) {
        return "[Agg] Agg lists \(token) on \(chainId) with conflicting decimals; nothing was sent."
      }
      let listed = candidates.map { "\($0.symbol) \($0.address)" }.joined(separator: ", ")
      return "[Agg] \(token) names \(candidates.count) tokens on \(chainId) (\(listed)); nothing was sent. Pass the address of the one to deposit."
    case let .quoteNotTradable(quote):
      let error = quote.error.flatMap { $0.isEmpty ? nil : "; \($0)" } ?? ""
      let warnings = (quote.warnings ?? []).map { "; \($0.venue): \($0.reason)" }.joined()
      return "[Agg] Quote \(quote.quoteId) is not tradable: status \(quote.status)\(error)\(warnings)"
    case let .orderFailed(status):
      return "[Agg] Order \(status.quoteId) ended \(status.overallState)\(status.errorReason.map { ": \($0)" } ?? "")."
    case let .withdrawalNotViable(preview):
      return "[Agg] The withdrawal is \(preview.pricingStatus)\(preview.unviableReason.map { ": \($0)" } ?? "")."
    case let .withdrawalFailed(withdrawal):
      return "[Agg] Withdrawal \(withdrawal.withdrawalId) failed\(withdrawal.errorMessage.map { ": \($0)" } ?? "")."
    case .depositAddressesTimeout:
      return "[Agg] Timed out waiting for the deposit addresses."
    case let .orderTimeout(quoteId, _):
      return "[Agg] Timed out waiting for order \(quoteId)."
    case let .withdrawalTimeout(withdrawalId, _):
      return "[Agg] Timed out waiting for withdrawal \(withdrawalId)."
    case let .orderOutcomeUnknown(quote, _, _, underlyingError):
      return "[Agg] Order \(quote.quoteId) may have been filled; read getOrder before trading again: \(underlyingError.localizedDescription)"
    case let .withdrawalOutcomeUnknown(request, withdrawal, _, underlyingError):
      let id = withdrawal?.withdrawalId ?? "with requestId \(request.requestId ?? "none")"
      return "[Agg] Withdrawal \(id) may have been sent; read it before withdrawing again: \(underlyingError.localizedDescription)"
    case let .depositOutcomeUnknown(idempotencyKey, chainId, depositAddress, token, amount, underlyingError):
      return "[Agg] The deposit of \(amount) \(token.symbol) on \(chainId) to \(depositAddress) may have been sent; retry it only with idempotencyKey \(idempotencyKey), which Portal never sends twice, or read getBalances(sync: true) before depositing again: \(underlyingError.localizedDescription)"
    }
  }
}

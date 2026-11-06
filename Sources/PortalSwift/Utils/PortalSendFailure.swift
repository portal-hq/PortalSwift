//
//  PortalSendFailure.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Whether a failed send could have reached the chain. A failure that is not known to come before
/// the broadcast must be treated as possibly broadcast: a call that times out after the node accepted
/// the transaction, or a connection that drops once it was broadcast, looks the same as one that
/// never reached the chain.
enum PortalSendFailure {
  /// Ids Portal's MPC server raises before a transaction reaches the chain (`mpc/errs/error_ids.go`):
  /// building the signing message or the transaction, a malformed request, a firewall or policy rule
  /// refusing it, or the node refusing it for lack of funds. `RPC_OP_FAILED` is not one: the send
  /// itself can fail after the node accepted the transaction.
  static let preBroadcastErrorIds: Set<String> = [
    "MSG_BUILD_FAILED",
    "TX_BUILD_FAILED",
    "BAD_REQUEST",
    "ADDRESS_BLOCKED",
    "POLICY_AMOUNT_LIMIT_EXCEEDED",
    "INSUFFICIENT_FUNDS"
  ]

  /// `true` for a send failure known to happen before the transaction reaches the chain: the SDK's
  /// own checks (idempotency key, credential, signing approval), Portal rejecting the credential, or
  /// one of `preBroadcastErrorIds`. Portal refusing a key it has already seen
  /// (`PortalMpcError.isIdempotencyRejection`) is not one: the earlier send under that key may have
  /// been broadcast.
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

  /// `true` for a `Portal.sendAsset` failure known to happen before anything was broadcast: its own
  /// checks of its parameters and chain, a failed request to build the transaction (nothing is
  /// signed until the build returns, so even a lost response sent nothing), or a failure
  /// `failedBeforeSending` knows. Anything else may come after the broadcast.
  static func sendAssetFailedBeforeSending(_ error: Error) -> Bool {
    if failedBeforeSending(error) || isBuildTransactionFailure(error) {
      return true
    }
    switch error as? PortalClassError {
    case .clientNotAvailable, .invalidParameters, .invalidChainId, .unsupportedChainId:
      return true
    // Thrown once the send returned, or not by `sendAsset`.
    case .invalidResponseTypeForRequest, .noWalletFoundForChain, .cannotCreateWallet, .cannotRecoverWallet, nil:
      return false
    }
  }

  /// Whether `error` is the failure of the request that builds a `sendAsset` transaction: an HTTP
  /// error or a network error that names its URL. A `401` names no URL, so it is not recognised.
  static func isBuildTransactionFailure(_ error: Error) -> Bool {
    let url: URL?
    switch error {
    case let error as PortalRequestsError:
      switch error {
      case let .clientError(_, failingUrl), let .internalServerError(_, failingUrl):
        url = URL(string: failingUrl)
      case .couldNotParseHttpResponse, .redirectError, .unauthorized:
        url = nil
      }
    case let error as URLError:
      url = error.failingURL
    default:
      url = nil
    }
    return url?.path.hasSuffix(PortalApi.buildTransactionPathSuffix) == true
  }
}

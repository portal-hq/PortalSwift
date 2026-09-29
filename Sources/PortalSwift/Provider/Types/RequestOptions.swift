//
//  RequestOptions.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 12/12/2025.
//

public struct RequestOptions: Codable {
  /// signatureApprovalMemo: Optional signature approval memo to use for the request.
  public var signatureApprovalMemo: String? = nil

  /// sponsorGas: Optional flag to `enable/disable` sponsor the gas,  to be used for the request.
  public var sponsorGas: Bool? = nil

  /// traceId: Optional trace ID for request correlation. Forwarded as the `X-Portal-Trace-Id`
  /// header on RPC requests and mapped to the MPC signing metadata `reqId`.
  public var traceId: String? = nil

  /// idempotencyKey: Optional key that makes a transaction broadcast safe to retry. Portal refuses
  /// to broadcast the same key twice, so a retry after a timeout cannot double-send. Generate one
  /// with `generateIdempotencyKey()` and reuse it only for an identical retry.
  ///
  /// Honoured for `eth_sendTransaction`, `sol_signAndSendTransaction` and
  /// `sol_signAndConfirmTransaction`; ignored with a warning for any other method, and when the
  /// chain relays the method to RPC instead of signing it (for example `eth_sendTransaction` on a
  /// `solana:` chain). Surrounding whitespace is trimmed, and the key must then be 1–255
  /// characters of `A-Z a-z 0-9 . _ ~ -`, otherwise the request throws
  /// `PortalIdempotencyError.invalidKey` before the approval prompt. A key on
  /// `eth_sendRawTransaction` or `sol_sendTransaction` throws
  /// `PortalIdempotencyError.unsupportedTarget` before anything is sent: those methods broadcast
  /// a transaction that is already signed through a plain RPC call, which Portal cannot
  /// deduplicate.
  ///
  /// Portal remembers a key for at least 24 hours after the request was last updated. A retry
  /// after that is treated as a new request, so check the chain before retrying an operation older
  /// than 24 hours, whatever key you use.
  ///
  /// Portal enforces the key when the transaction is signed through the MPC Enclave API
  /// (`useEnclaveMPCApi`), and when it is signed on the device by a bundled MPC binary that
  /// supports idempotency keys (see the CHANGELOG). Earlier binaries accept the key without
  /// enforcing it. Through the MPC Enclave API, a request with a key is signed without a
  /// presignature, even when `usePresignatures` is on. A custom `PortalSignerProtocol` signer
  /// receives the key only if it implements `sign(...idempotencyKey:token:)`; otherwise the key is
  /// dropped with a warning.
  public var idempotencyKey: String? = nil

  public init(
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    traceId: String? = nil,
    idempotencyKey: String? = nil
  ) {
    self.signatureApprovalMemo = signatureApprovalMemo
    self.sponsorGas = sponsorGas
    self.traceId = traceId
    self.idempotencyKey = idempotencyKey
  }
}

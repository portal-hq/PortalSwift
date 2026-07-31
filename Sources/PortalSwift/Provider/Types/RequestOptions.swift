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

  public init(
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    traceId: String? = nil
  ) {
    self.signatureApprovalMemo = signatureApprovalMemo
    self.sponsorGas = sponsorGas
    self.traceId = traceId
  }
}

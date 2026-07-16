//
//  PortalTracing.swift
//  PortalSwift
//
//  Utilities for request tracing via the `X-Portal-Trace-Id` header.
//

import Foundation

/// The trace ID header used by connect-api (client + custodian APIs).
public let PORTAL_TRACE_ID_HEADER = "X-Portal-Trace-Id"

/// Generates a UUID v4 trace ID for request correlation.
/// The value is lowercased to stay consistent with the other Portal SDKs.
public func generateTraceId() -> String {
  UUID().uuidString.lowercased()
}

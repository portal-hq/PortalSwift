//
//  PortalMpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalMpcError: LocalizedError, CustomStringConvertible, Equatable {
  @available(*, deprecated, message: "Use `id` instead.")
  public var code: Int?
  public var id: String?
  public var message: String?

  init(_ error: PortalError) {
    self.code = error.code
    self.id = error.id
    self.message = error.message
  }

  public var errorDescription: String {
    return "PortalMpcError -id: \(self.id ?? "unknown") -message: \(self.message ?? "unknown")"
  }

  public var description: String {
    return self.errorDescription
  }

  /// `true` when the MPC layer rejected the client's credential.
  ///
  /// The Go MPC binary reports a rejected bearer as `errs.ErrAuthFailed`, whose wire id is the
  /// literal `"AUTH_FAILED"` (`mpc/errs/error_ids.go`). The comparison is exact and case-sensitive
  /// because the id is a stable protocol constant, not free text. Callers use this to invalidate
  /// the session instead of retrying a dead credential (presignature refill, signing,
  /// generate/backup/recover).
  ///
  /// Enclave mode (`useEnclaveMPCApi`) does not produce this id yet. `EnclaveMobileWrapper` turns
  /// an HTTP 401 into `PortalRequestsError.unauthorized`, whose body is deliberately discarded, so
  /// the encoded result carries no error id and this reads `false`. The session is still
  /// invalidated on that path — the enclave transport carries the 401 hook installed by
  /// `Portal.init` — and the only cost is that a presignature sign falls back to a normal sign,
  /// which fails against the same dead credential. Synthesising `AUTH_FAILED` for the enclave 401
  /// lands in the follow-up PR.
  public var isAuthFailure: Bool {
    self.id == "AUTH_FAILED"
  }

  public static func == (lhs: PortalMpcError, rhs: PortalMpcError) -> Bool {
    return lhs.code == rhs.code && lhs.message == rhs.message && lhs.id == rhs.id
  }
}

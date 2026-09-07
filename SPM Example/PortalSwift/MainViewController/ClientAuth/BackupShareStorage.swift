//
//  BackupShareStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import PortalSwift

/// Where a client backup share's ciphertext is kept.
///
/// Two destinations, and a session can have neither. The demo custodian addresses backups by
/// the `exchangeUserId` *it* issued — a custodian login gets one at signup, a Client Auth
/// session only by registering — so a session whose registration failed has no custodian
/// destination. Portal keeps backups itself only when the environment enables it.
enum BackupShareStorage: Equatable {
  /// Portal keeps the ciphertext, because the environment has backup-with-Portal enabled.
  case portal
  /// The demo custodian keeps the ciphertext, addressed by the exchange user it issued.
  case custodian(exchangeUserId: String)
}

/// The one sentence a tester sees when a backup has nowhere to go. Names both halves of the
/// condition, because either one alone would have been enough to make the backup work.
let NO_BACKUP_STORAGE_ERROR =
  "Nowhere to store the client backup share: this session has no exchange user, and "
    + "backup-with-Portal is not enabled for its environment"

/// Thrown when there is no destination.
///
/// A named type rather than a bare `PortalExampleAppError` so a caller can tell it from an MPC
/// failure and *not* report a backup-share failure to Portal for a backup that never started.
struct NoBackupShareStorageError: LocalizedError, Equatable {
  var errorDescription: String? { NO_BACKUP_STORAGE_ERROR }
}

/// Decides where the ciphertext will go, and **must run before `backupWallet()`**.
///
/// MPC backup registers a backup share pair on the backend as it runs. Discovering afterwards
/// that there is nowhere to keep the ciphertext leaves that pair orphaned and the only copy of
/// the ciphertext unpersisted — a wallet that reports itself as backed up with no recoverable
/// backup behind it. Resolving first turns that into a refusal with a reason. The same call
/// guards `recoverWallet()`, where a blank exchange user would otherwise be interpolated into
/// `/mobile//cipher-text/fetch`.
///
/// Client Auth is what makes this reachable. Custodian signup always issues an
/// `exchangeUserId`, so before Client Auth the destination could not be missing. Adoption
/// deliberately continues when custodian registration fails — a demo-server outage must not
/// block a login — which leaves a signed-in session holding no exchange user and every backup
/// control live.
///
/// **The precedence deliberately differs from the React Native example**, which prefers a
/// custodian exchange user and consults the environment only as a fallback. Here the
/// environment flag is checked first, because that is the rule every existing call site already
/// implements (`client.environment?.backupWithPortalEnabled != true`) and because the example's
/// `BACKUP_WITH_PORTAL` build flag selects a custodian backend on that same flag. Reversing it
/// would route a backup-with-Portal environment's ciphertext at the custodian instead.
///
/// The order of the two refusals matters too: "nothing to store anywhere" outranks the config
/// complaint, because a blank exchange user makes the build flag irrelevant — there is no
/// custodian destination to have been built against the wrong PortalEx instance.
///
/// - Parameters:
///   - exchangeUserId: the custodian's id for this user, or `nil`/blank when there is none.
///   - isBackupWithPortalEnabled: the runtime `client.environment?.backupWithPortalEnabled`.
///   - isBuiltWithBackupWithPortal: the build-time `BACKUP_WITH_PORTAL` flag, which chose the
///     PortalEx instance and API key this build talks to.
/// - Throws: `NoBackupShareStorageError` when neither destination exists, or
///   `PortalExampleAppError.backupConfigMismatch` when a custodian destination is the answer
///   but this build is wired to the other PortalEx instance.
func resolveBackupShareStorage(
  exchangeUserId: String?,
  isBackupWithPortalEnabled: Bool,
  isBuiltWithBackupWithPortal: Bool
) throws -> BackupShareStorage {
  if isBackupWithPortalEnabled {
    // Only `.custodian` is refused under a mismatch: a Portal-managed backup never touches
    // PortalEx, so which instance this build was wired to cannot make it wrong.
    return .portal
  }

  guard let exchangeUserId, !exchangeUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    throw NoBackupShareStorageError()
  }

  guard !isBuiltWithBackupWithPortal else {
    throw PortalExampleAppError.backupConfigMismatch(
      backupConfigMismatchMessage(
        environmentFlag: false,
        isBuiltWithBackupWithPortal: true
      )
    )
  }

  return .custodian(exchangeUserId: exchangeUserId)
}

/// The custodian path a recover reads the ciphertext from, or `nil` for a Portal-managed share.
///
/// `nil` is the whole point of the return type: `recoverWallet` passes an empty ciphertext for a
/// `.portal` session, because Portal already holds the share and there is no custodian to ask.
/// Building the path here rather than at the call site is what keeps a blank exchange user out
/// of `/mobile//cipher-text/fetch` — the only way to get a `.custodian` is through
/// `resolveBackupShareStorage`, which refuses a blank id.
func custodianCipherTextFetchPath(for storage: BackupShareStorage, backupMethod: BackupMethods) -> String? {
  switch storage {
  case .portal:
    return nil
  case let .custodian(exchangeUserId):
    return "/mobile/\(exchangeUserId)/cipher-text/fetch?backupMethod=\(backupMethod.rawValue)"
  }
}

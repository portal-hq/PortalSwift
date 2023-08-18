# Changelog

All notable changes to this project will be documented in this file.
Possible Types of changes include:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security

## 1.1.7 2023-08-18

### Fixed

- Portal Connect typing issue for some dapps sending no optional namespaces.
- More errors delivered through the `portal_connectError` event.

### Changed

- Updated MPC binary.

## 1.1.6 2023-08-11

### Added

- Request using `portal.api.storedClientBackupShareKey` on `backup` and `recover` following successfully saving the client backup share encryption key to the user's backup method.
- Added unit tests for wallet safeguarding.
- Added e2e tests for the provider.

### Changed

- Updated MPC binary.

## 1.1.2 2023-06-11

### Fixed

- Multiple event listeners firing for a single `signingRequest`
  - Only firing event handlers for that specific request and removing handlers for events that have already been fired

## 1.0.1 2023-06-11

### Added

- Adds support for `connect.on('portal_dappSessionRequested', eventHandler)` event handlers to manage approval flows for Portal Connect sessions
- Adds support for `connect.on('portal_dappSessionRequestedV1', eventHandler)` event handlers to manage approval flows for Portal Connect sessions
- Adds support for `connect.emit('portal_dappSessionApproved', data)` event emitting to approve Portal Connect sessions
- Adds support for `connect.emit('portal_dappSessionRejected', data)` event emitting to reject Portal Connect sessions

### Fixed

- Improves support for delivery of signatures to dApps through Portal Connect
- Improves support for delivery of signing rejections to dApps through Portal Connect
- Improved stability support for WebSocket connections in Portal Connect, including automatic reconnection on timeouts and WebSocket failures

## 1.0.0 - 2023-06-09

### Added

- `portal.keychain.validateOperations`: Checks if you can write, read, and delete from keychain.
- validation checks for Keychain before running generate and recover.
- validation checks for the selected backup method before running backup and recover.
- `portal.api.storedClientBackupShare`.
- `portal.api.storedClientSigningShare`.
- wallet modification in-progress checks before running generate, backup, and recover.

### Changed

- Bump from v3 to v4 for default MPC version in classes.
- `portal.mpc.generate` & `portal.mpc.recover` use `portal.api.storedClientSigningShare` when keychain completes storage

### Removed

- `getAvailability` from icloud storage

## 0.2.4 - 2023-06-02

### Added

- Improved error messaging

### Security

- Internal mpc binary improvement

## 0.2.3 - 2023-05-26

### Added

- Extension to `portal.api`: `getNFT`, `getTransactions`, `getBalances`
- 0x Swap integration

### Fixed

- Missing error check

## 0.1.9 - 2023-04-21

### Added

- Progress callbacks for MPC operations
- Completion handler for keychain operations
- Webview signing on background thread
- Support for `signTypedData_v3` and `signTypedData_v4`

### Changed

- v3 of MPC server

### Fixed

- signing share being nil on backup MPC operation
- Blocking the webview UI when signing

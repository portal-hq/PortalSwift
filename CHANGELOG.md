# Changelog

All notable changes to this project will be documented in this file.
Possible Types of changes include:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security

## 1.0.0 - 2023-06-09
### Added
- `portal.keychain.validateOperations`: Checks if you can write, read, and delete from keychain.
- `portal.storage.validateOperations`: Checks if you can write, read, and delete from cloud storage.
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

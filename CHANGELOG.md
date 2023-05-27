# Changelog

All notable changes to this project will be documented in this file.
Possible Types of changes include:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security

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

# Changelog

All notable changes to this project will be documented in this file.
Possible Types of changes include:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security
- Improved
- Upgraded

## 6.6.0 - 2026-01-09
- Added 0x integration
    - Added `portal.trading.zeroX.getSources`
    - Added `portal.trading.zeroX.getQuote`
    - Added `portal.trading.zeroX.getPrice`
- Minor update to Yield.xyz type.
- Fixed an issue in `Portal.createWallet()` so it now throws a correct exception when using an unsupported version of MPC.

## 6.5.0 - 2025-12-18
- Added optional `sponsorGas` parameter to `portal.sendAsset` and `portal.request` to control gas sponsorship per transaction in Account Abstraction clients.
- Minor update to Yield.xyz type.

## 6.4.0 - 2025-11-28
- Added Li.Fi integration
    - Added `portal.trading.lifi.getQuote`
    - Added `portal.trading.lifi.getRoutes`
    - Added `portal.trading.lifi.getRouteStep`
    - Added `portal.trading.lifi.getStatus`

## 6.3.1 - 2025-11-11
- Fixed the `errSecDuplicateItem` error in keychain update.

## 6.3.0 - 2025-11-04
- Added `portal.yield`, `portal.yield.yieldxyz`, `portal.yield.yieldxyz.discover`, `portal.yield.yieldxyz.enter`, `portal.yield.yieldxyz.manage`, `portal.yield.yieldxyz.exit`, `portal.yield.yieldxyz.getBalances`, and `portal.yield.yieldxyz.getHistoricalActions`.
- Fixed an issue in the enclave sign and raw sign.

## 6.2.1 - 2025-09-04
- Minor updates to improve stability.

## 6.2.0 - 2025-09-02
- Added Bitcoin (p2wpkh) support to `portal.sendAsset`.

## 6.1.1 - 2025-08-19
- Added an optional `signatureApprovalMemo` parameter when signing to the functions `rawSign`, `sendAsset`, and `request`.

## 6.1.0 - 2025-06-05
- Added default web auth host to the function `setPasskeyConfiguration`.
- Added `PortalRequests.execute()` that receives a request object and decoding type, returning a concrete type.
- Deprecated `PortalSwaps.getQuote` with completion handler in favor of the async/await version `PortalSwaps.getQuote`.
- Deprecated `PortalSwaps.getSources` with completion handler in favor of the async/await version `PortalSwaps.getSources`.
- Fixed an issue in `Portal.isWalletOnDevice()` so it no longer throws an exception when there is no share stored in the keychain.

## 6.0.0 - 2025-04-25

- Fixed the build issue using Xcode 16.3
- Upgraded `googlesignin-ios` from version `7.1.0` to `8.0.0`
- Fixed `eject` solana wallet for portal managed backups.
- Deprecated `Portal.request(_:_:completion)` to use the `async/await` `Portal.request()` instead.
- Added `Portal.updateChainId()` that updates the currently active chain ID used by the provider.
- Deprecated ETH helper functions `ethEstimateGas`, `ethGasPrice`, `ethGetBalance`, `ethSendTransaction`, `ethSign`, `ethSignTransaction`, `ethSignTypedDataV3`, `ethSignTypedData`, and `personalSign` to use `Portal.request(_:withMethod:andParams:)` instead.

## 5.0.1 - 2025-03-19

- Added Raw Sign function `Portal.rawSign()`
- Deprecated `Portal.sendSol()` to use `Portal.sendAsset()` instead.
- Changed the `AssetsResponse` properties to be public.
- Improved the custom signature hook threading performance.
- Fixed Swift 6 threading warning.

## 5.0.0 - 2025-02-25

- Added MPC Enclave Sign Support.
- Added ReceiveTestnetAsset and sentAsset helper functions to `Portal` class.
- Added `PortalProtocol` to enable clients to mock our SDK for unit-testing.
- Changed `PortalWebView.WebViewControllerErrors` to `PortalWebView.PortalWebViewErrors` for a better naming convention.

## 4.2.1 - 2025-01-16

- Improved error codes throughout the sdk
- Deprecated `Portal.request()` with optional parameters and string method in favor of implementation with default parameters
- Added public properties to `BuildSolanaTransactionResponse` & `BuildEip115TransactionResponse` type
- Added Xcode documentation for Portal's public API functions

## 4.2.0 - 2024-12-05

- Add support for AppData folder backups with GDrive

## 4.1.0 - 2024-11-20

- Change `createWallet` to return non-optional eth and Solana addresses & recover wallet non-optional ETH address
- EIP-6963 Support in the Dapp Browser
- Add `wallet_getCapabilities` method to the provider
- Throw errors for `isWalletOnDevice` instead of returning false for errors

## 4.0.3 - 2024-11-1

- Add `portal.getRpcUrl(forChainId)`

## 4.0.2 - 2024-10-31

- Add `buildTransaction` methods for ETH & SOL
- Add `getNFTAssets` method to get NFT assets by `chainId`
- Add `getAssets` method to get assets by `chainId`
- Enhance the `errors` to have a proper `localizedDescription`
- Fix for the `GETTransactions` API response.

## 4.0.1 - 2024-10-16

- Fixes cross-SDK recovery

## 4.0.0 - 2024-09-16

- Breaking change to `PortalKeychain.metadata` to be instance member & thread-safe.
- Fixes the `Portal.isWalletBackedUp()` bug.
- Breaking change to handle the unauthorized session to throw `PortalRequestsError.unauthorized` instead of a generic error

## 3.2.3 - 2024-08-30

- PortalConnect Update
  - Adds `emitGetSessionRequest()` to Connect class.
  - Allows customers to retrieve previous session requests from dApps.
  - This is primarily meant to be used in conjunction with mobile deeplinking to properly respond to a session request.
  - Read more on [Swift](https://docs.portalhq.io/guides/native-ios/connect-with-walletconnect#retrieve-session-request) and [Kotlin](https://docs.portalhq.io/guides/native-android/connect-with-walletconnect#retrieve-session-request).
- Adds thread safe access to client
- Adds evaluate transaction function using evaluate endpoint
- Refer to the Portal API Documentation for more details
- Adds sol_getTransaction RPC request

## 3.2.2 - 2024-08-15

- Fix eject error handling
- Default rpc urls
- Webview made public

## 3.2.1 - 2024-08-05

- Hot-Fix: recovering bug after solana generate with no backup.

## 3.2.0 - 2024-07-31

- Solana migration support for pre-multi wallet sdk versions. (Android v3 and iOS v3.0.x) [docs](https://docs.portalhq.io/resources/multi-wallet-migration-guides)
- Solana Eject ([iOS docs](https://docs.portalhq.io/guides/ios/eject-a-wallet), [android docs](https://docs.portalhq.io/guides/android/eject-a-wallet))

## 3.1.12 - 2024-07-30

- Includes `chainId` on the payload provided to all `Provider.request()` approval hooks

## 3.1.11 - 2024-07-29

- Resolves issues with `featureFlag` propagation during backup and recovery

## 3.1.10 - 2024-07-26

- Resolves issues with `continuation.resume()` falling throught.

## 3.1.9 - 2024-07-26

- Resolves issues with feature flags being propagated in `PortalConnect` instances.

## 3.1.8 - 2024-07-22

- Resolves an issue with signing share lookup when upgrading from 3.0.x to 3.1.x

## 3.1.7 & 3.0.13 - 2024-07-11

- PortalConnect Update
  - Adds `emitGetSessionRequest()` to Connect class.
  - Allows customers to retrieve previous session requests from dApps.
  - This is primarily meant to be used in conjunction with mobile deeplinking to properly respond to a session request.
  - Read more on [Swift](https://docs.portalhq.io/guides/native-ios/connect-with-walletconnect#retrieve-session-request) and [Kotlin](https://docs.portalhq.io/guides/native-android/connect-with-walletconnect#retrieve-session-request).
- Tracking SDK version on requests to Portal

## 3.1.6 - 2024-06-18

- updated swiftformat rules
- Fixed crash while setting `self.events[event] = event`
- Added test case for PortalConnect.swift
- Created new class for EventBus unit test
- Removed apiKey constraint
- Added support for updating RPC URL on chain changed

## 3.1.5 & 3.0.12 - 2024-06-12 & 2024-06-18

- Resolves once listener bug
- Resolves disconnect event emit bug
- Adds check to params for requests
- apiKey is now a private variable
- Adds count check to params for requests

## 3.0.11 - 2024-06-12

- Resolves once listener bug
- Resolves disconnect event emit bug

## 3.1.4 - 2024-05-18

- Solana Support
  - Adds a helper sendSol function
  - Adds a createSolanaRequest function
  - Adds all of the Solana RPC methods to our Provider
  - Adds the following Solana signing methods
    - sol_signAndConfirmTransaction
    - sol_signAndSendTransaction
    - sol_signMessage
    - sol_signTransaction
  - Increase the min deployment version to iOS 15
  - Adds the solanaSwift library as a dependency

## 3.0.6 - 2024-04-11

- Adds support for development in Xcode 15.3

## 3.0.5 - 2024-03-08

- Removes portal.legacyRecover (deprecated).
- Removes WalletConnect v1 implementation (deprecated).

## 3.0.4 - 2024-03-07

- Fixes a bug that prompted users for permission to access the local network.

## 3.0.1 - 2024-02-17

- Added .getBackupShareMetadata() to get backup shares' details for a user.
- Added .getSigningShareMetadata() to get signing shares' details for a user.
- Configurable relying party for Passkeys
  - Set your own domain as the relying party for your passkeys!

## 3.0.0 - 2024-02-10

- Adds support for multi-backup.
- Updated staging domains for example app.

## 2.1.2 - 2024-02-02

- Support for client attestation when using the optimized: true feature flag
- Support for changing chains on a dApp in the WebView from the app Provider
  - This allows for the setChainId or updateChain functions in your app to also control the chain of a PortalWebView
- Addition of eject support to eject an MPC wallet's private key

## 2.1.1 - 2024-01-27

- Adds support for switching chains in the PortalWebView.
- Fixes a bug with transaction rejection.

## 2.1.0 - 2024-01-20

- Eject feature available via the portal.mpc.ejectPrivateKey function.
- Fixes bug with request approvals and rejections the PortalWebView .

## 2.0.18 - 2024-01-13

- Fixes auto-connect to Aave in the PortalWebView.
- Adds other PortalWebView improvements:
  - Adds support for opening new tabs in the same view.
  - Fixes a force unwrap bug.
  - Improves script inject point for more reliable auto-connect.
  - Removes session persistence between sessions by default, but can be configured to be enabled.

## 2.0.16 - 2024-01-04

- Passkey + Enclave Storage (Alpha)

## 2.0.15 - 2023-12-09

- Added convenience methods for ethGetBalance, ethEstimateGas, and ethGasPrice.
- Updated example apps to use the Sepolia chain instead of Goerli by default.

## 2.0.14 - 2023-12-01

- Support for page loading callbacks in WebView.

## 2.0.13 - 2023-11-18

- Adds support for setting a custom nonce to iOS.
- Makes the PortalWebView.webView and PortalWebView.webViewContentIsLoaded properties public in iOS.

## 2.0.12 - 2023-11-10

- Added auto-connect functionality for the following dApps in the mobile WebViews:
  - Aave (https://app.aave.com/)
  - Arbitrum Bridge (https://bridge.arbitrum.io/)
  - Compound Finance (https://app.compound.finance/?market=usdc-mainnet)
  - Convex Finance (https://www.convexfinance.com/stake)
  - MakerDAO (https://app.spark.fi/)
  - Optimism Gateway (https://app.optimism.io/bridge/deposit)
  - Rarible (https://rarible.com/)
  - RocketPool (https://stake.rocketpool.net/)
  - Uniswap (https://app.uniswap.org/#/swap)
  - summer.fi (https://summer.fi/)

## 2.0.11 - 2023-11-07

- Adds support for SPM directly in the PortalSwift repo
- Makes the PortalSwift repo public to work better with CI tools

## 2.0.10 - 2024-11-04

- Users can now create multiple signing shares across all of the Portal SDKs. For example, a user can create a wallet on an iOS device and continue using that wallet on your web app!
- Use portal.provisionWallet (or portal.recoverWallet) to enable your users to create multiple signing shares across all of the Portal SDKs. Read more here.
- Improved auto-connection for Native iOS WebView.

## 2.0.9 - 2023-10-27

- Enhanced portal.getTransactions to support optional arguments: limit, offset, order, and chainId.
  - Transactions from portal.getTransactions now include metadata.blockTimestamp and chainId. Read more here.
- Added support for allowanceTarget in Swap quotes.

## 2.0.8 - 2023-10-21

- Resolves issues with WalletConnect when dApps exclude requiredNamespaces fields in their session proposal.
- The alpha release of our Password/PIN Backups is now included.
- Improved memory management for WalletConnect WebSocket connections.

## 2.0.5 - 2023-09-30

- Optimization: Introduce an optional featureFlag into the Portal instance. Set optimized: true for a 10x speed boost for generate, backup, and recover!
- Correction: Changed eth_sendTransaction to eth_signTypedData.

## 2.0.4 - 2023-09-22

- Enhanced MPC & API call tracking.
- Refreshed binary.
- Created SPM package.

## 2.0.3 - 2023-09-15

- Added support for the following RPC methods:
  - eth_getBlockByNumber
  - eth_getBlockTransactionCountByHash
  - eth_getBlockTransactionCountByNumber
  - eth_getLogs
  - eth_getTransactionByBlockHashAndIndex
  - eth_getTransactionByBlockNumberAndIndex
  - eth_getBlockByHash
  - eth_getTransatctionByHash
  - eth_getUncleByBlockHashAndIndex
  - eth_newBlockFilter
  - eth_newFilter
  - eth_uninstallFilter
  - net_listening
  - web3_clientVersion
  - web3_sha3
- Fixed issue passing chainId from Portal Connect Server

## 1.1.10 - 2023-09-15

- Fixed issue passing chainId from Portal Connect Server.

## 2.0.2 - 2023-09-09

- Portal Connect
  - Adds a addChainsToProposal method. This will allow you to add all the chains in your gateway config to the proposal that you get from a dapp when you approve the connection. Docs for iOS and Android
  - Adds error codes. Docs

## 2.0.0 - 2023-09-02

- Recovery Update:
  - Breaking Change: The recover function now solely updates signing shares, returning the wallet address similar to generate.
  - Earlier versions updated both signing and backup shares, with potentially confusing error handling.
  - For those wanting the older method, use the new legacyRecover function.
- PortalConnect Enhancements:
  - Boosted reliability with a new ping interval and advanced reconnection logic.

## 1.1.8 - 2023-08-25

- Adds support for transaction simulation

## 1.1.7 - 2023-08-18

### Fixed

- Portal Connect typing issue for some dapps sending no optional namespaces.
- More errors delivered through the `portal_connectError` event.

### Changed

- Updated MPC binary.

## 1.1.6 - 2023-08-11

### Added

- Request using `portal.api.storedClientBackupShareKey` on `backup` and `recover` following successfully saving the client backup share encryption key to the user's backup method.
- Added unit tests for wallet safeguarding.
- Added e2e tests for the provider.

### Changed

- Updated MPC binary.

## 1.1.2 - 2023-06-11

### Fixed

- Multiple event listeners firing for a single `signingRequest`
  - Only firing event handlers for that specific request and removing handlers for events that have already been fired

## 1.0.1 - 2023-06-11

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

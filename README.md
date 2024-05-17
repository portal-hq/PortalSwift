# PortalSwift

Portal's SDK for iOS.

Full documentation and Guides are available in the [Portal Docs](https://docs.portalhq.io/sdk/native-ios).

# Install

`PortalSwift` supports both [Swift Package Manager](https://www.swift.org/package-manager/) and [Cocoapods](https://cocoapods.org/).

Depending on the needs of your project, you can follow the instructions below to install `portal-ios`.

## Swift Package Manager

To integrate `PortalSwift` into your Xcode project using Swift Package Manager, in XCode, select `File` -> `Swift Packages` -> `Add Package Dependency` and search for `PortalSwift` or enter the URL of this repository (https://github.com/portal-hq/PortalSwift).

This will add PortalSwift as a dependency in your project.

### Manually adding `PortalSwift` to your `Package.swift`

If you'd prefer, you can manually add `PortalSwift` to your project's `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/portal-hq/PortalSwift.git", .upToNextMajor(from: "2.0.9"))
]
```

## Cocoapods

To integrate `PortalSwift` into your Xcode project using Cocoapods, add the following to your `Podfile`:

```ruby
pod 'PortalSwift', :git => 'https://github.com/portal-hq/PortalSwift'
```

Then run `pod install`.

# Basic Usage

To create a new instance of `Portal` within your app, import `PortalSwift` and initialize a new instance of `Portal`.

```swift
import PortalSwift
let portal = try Portal(
  apiKey: "YOUR_PORTAL_CLIENT_API_KEY",
  withRpcConfig: [
    "eip155:1": "RPC_URL_FOR_ETHEREUM_MAINNET"
    "eip155:11155111": "RPC_URL_FOR_ETHEREUM_SEPOLIA",
    "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "RPC_URL_FOR_SOLANA_MAINNET",
    "solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z": "RPC_URL_FOR_SOLANA_TESTNET",
  ],
  autoApprove: true, // If you'd like to set up custom approval logic, you can leave this out
)
```

For more info on the basic usage of the `Portal` class and its initialization parameters, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios).

# Creating a wallet

To create a wallet using your new `Portal` instance, call the `createWallet` method. This function returns a tuple `(ethereum, solana)` containing the string literals for the addresses of your newly created wallets.

`createWallet()` also optionally accepts a progress handler which sends status updates on the wallet creation process.

```swift
let (ethereum, solana) = try await portal.createWallet() { createStatus in
  print("Wallet Creation Status: ", createStatus)
}

print("Ethereum Address: ", ethereum)
print("Solana Address: ", solana)
```

For more info on creating a wallet, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios/creating-a-wallet).

## Signing an Ethereum transaction

To send a transaction using your new `Portal` instance, call the `request(chainId, method, params)` method.

- `chainId` is the CAIP-2 Blockchain ID of the network you'd like to send the transaction on
- `withMethod` is the method you'd like to call on the network. This should be a member of the `PortalRequestMethods` enum
- `andParams` is an array of parameters required for the method you're calling
  - For transactions, this should be an array of dictionaries containing the transaction details

```swift
let transaction: [String: String] = [
  "from": ethereum,
  "to": "DESTINATION_ADDRESS",
  "value": "HEX_ENCODED_VALUE_IN_WEI",
]

let signature = try await portal.request("eip155:11155111", withMethod: .eth_signTransaction, andParams: [transaction])
```

For more info on signing a transaction, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios/signing-a-transaction).

## Sending an Ethereum transaction

To send a transaction using your new `Portal` instance, call the `request(method, params)` method.

```swift
let transaction: [String: String] = [
  "from": ethereum,
  "to": "DESTINATION_ADDRESS",
  "value": "HEX_ENCODED_VALUE_IN_WEI",
]

let transactionHash = try await portal.request("eip155:11155111", withMethod: .eth_sendTransaction, andParams: [transaction])
```

# Backing up your wallet

By default, `PortalSwift` will register backup methods for Google Drive, iCloud, Passkeys, and Passwords. Google Drive require additional configuration to successfully back up your wallet.

## Configuring Google Drive

To configure the Google Drive backup method, use the `setGoogleDriveConfiguration(clientId)`.

- `clientId` is the OAuth Client ID for your Google Drive app.

```swift
try portal.setGoogleDriveConfiguration(clientId: "YOUR_GOOGLE_DRIVE_CLIENT_ID")
```

## Executing a backup

To execute a backup, call the `backupWallet(method)` method.

- `method` is the backup method you'd like to use. This should be a member of the provided `BackupMethods` enum.

This function returns a tuple `(cipherText, storageCallback)` containing all necessary information required to complete the backup process on your end.

- `cipherText` this is the encrypted wallet data that you will need to store on your end for future wallet recovery
- `storageCallback` this is a callback function that you will need to call once you've completed the storage process on your end

`backupWallet()` also optionally accepts a progress handler which sends status updates on the wallet backup process.

```swift
let (cipherText, storageCallback) = try await portal.backupWallet(.iCloud) { backupStatus in
  print("Backup Status: ", backupStatus)
}

// Store the cipherText on your end
storeUserCipherText(cipherText) // This would be a function you define to store the cipherText

// Call the storageCallback once you've completed the storage process
try await storageCallback()
```

### Password-specific requirements

Before calling `backupWallet(.Password)`, you must set a password using the `portal.setPassword(password)` method.

```swift
try portal.setPassword(password: "YOUR_PASSWORD")
let (cipherText, storageCallback) = try await portal.backupWallet(.Password) { backupStatus in
  print("Backup Status: ", backupSatus)
}

// Store the cipherText on your end
storeUserCipherText(cipherText) // This would be a function you define to store the cipherText

// Call the storageCallback once you've completed the storage process
try await storageCallback()
```

### Passkey-specific requirements

Before calling `backupWallet(.Passkey)`, you must set a Authentication Anchor using the `portal.setPasskeyAuthenticationAnchor(anchor)` method.

- `anchor` is an instance conforming to the `ASPresentationAnchor` protocol. This will be used to present the passkey authentication view controller.

```swift
try portal.setPasskeyAuthenticationAnchor(anchor: self.view.window)
let (cipherText, storageCallback) = try await portal.backupWallet(.Passkey) { backupStatus in
  print("Backup Status: ", backupStatus)
}

// Store the cipherText on your end
storeUserCipherText(cipherText) // This would be a function you define to store the cipherText

// Call the storageCallback once you've completed the storage process
try await storageCallback()
```

# Recovering a wallet

To recover a wallet using your new `Portal` instance, call the `recoverWallet(method, withCipherText)` function.

- `method` is the backup method you used to backup your wallet
- `cipherText` is the encrypted wallet data you stored during the backup process

This function returns a tuple `(ethereum, solana)` containing the string literals for the addresses of your recovered wallets.

`recoverWallet()` also optionally accepts a progress handler which sends status updates on the wallet recovery process.

```swift
let (ethereum, solana) = try await portal.recoverWallet(.iCloud, withCipherText: cipherText) { recoveryStatus in
  print("Recovery Status: ", recoveryStatus)
}

print("Ethereum Address: ", ethereum)
print("Solana Address: ", solana)
```

# Learn more about Portal

Want to integrate Web3 into your app? Visit our site to [learn more](https://portalhq.io), or reach out to Portal to [get a demo](https://www.portalhq.io/book-demo).

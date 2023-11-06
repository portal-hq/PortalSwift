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
pod 'PortalSwift', '~> 2.0.11'
```

Then run `pod install`.

# Basic Usage

To create a new instance of `Portal` within your app, import `PortalSwift` and initialize a new instance of `Portal`.

```swift
import PortalSwift

// This example shows backing up with a Password/PIN code.
// We also support backing up with Google Drive and iCloud
let backup = BackupOptions(passwordStorage: PasswordStorage())

let portal = try Portal(
  apiKey: "YOUR_PORTAL_CLIENT_API_KEY",
  backup: backup,
  chainId: "YOUR_DESIRED_CHAIN_ID",
  keychain: keychain,
  gatewayConfig: [
    // This Gateway Config will dependent on the chains you want to support
    1: "NODE_URL_FOR_MAINNET",
    5: "NODE_URL_FOR_GOERLI",
    137: "NODE_URL_FOR_POLYGON_MAINNET",
    80001: "NODE_URL_FOR_POLYGON_MUMBAI",
  ],
  autoApprove: true, // If you'd like to set up custom approval logic, set this to false
)
```

For more info on the basic usage of the `Portal` class and its initialization parameters, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios).

## Creating a wallet

To create a wallet using your new `Portal` instance, call the `createWallet` method.

```swift
portal.createWallet() { (addressResult) -> Void in
  if (addressResult.error != nil) {
    // ❌ Handle errors creating the wallet.

    return
  }

  // ✅ We now have the address for your new wallet. 🙌
  self.address = addressResult.data ?? nil
} progress: { status in
  // Handle progress updates for the wallet creation process.
  print("Wallet Creation Status: ", status)
}
```

For more info on creating a wallet, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios/creating-a-wallet).

## Signing a transaction

To sign a transaction using your new `Portal` instance, call the `ethSignTransaction` method.

```swift
let transaction = EthTransactionParam(
  from: "",
  to: "",
  gas: "", // optional
  gasPrice: "", // optional
  maxPriorityFeePerGas: "", // optional
  maxFeePerGas: "", // optional
  value: "", // optional
  data: "", // optional
)

// This will sign the transaction without submitting to chain.
portal.ethSignTransaction(transaction) { (signatureResult) -> Void in
  guard signatureResult.error == nil else {
    // ❌ Handle errors signing the transaction.

    return
  }

  // ✅ We now have the signature for your transaction. 🙌
  let signature = signatureResult.data
}

// This will sign the transaction and submit it to chain.
portal.ethSendTransaction(transaction) { (signatureResult) -> Void in
  guard signatureResult.error == nil else {
    // ❌ Handle errors signing the transaction.

    return
  }

  // ✅ We now have the signature for your transaction. 🙌
  let signature = signatureResult.data
}
```

For more info on signing a transaction, see the [Portal Docs](https://docs.portalhq.io/sdk/native-ios/signing-a-transaction).

# Get a demo

Want to integrate Web3 into your app? Visit our site to [learn more](https://portalhq.io), or reach out to Portal to [get a demo](https://www.portalhq.io/book-demo).

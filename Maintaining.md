# PortalSwift

# Install

## Set up

Ensure you have the pre-commit hooks set up. Run the following command:

```
sh ./scripts/register-hooks.sh
```

Create an xcConfig file.

1. Add new file to PortalSwift by right clicking on PortalSwift and clicking add new file
2. Search for configuration file
3. Call the new configuration file "Secrets"
4. Add both example and test as targets
5. Add the following line to your `Secrets.xcconfig` file `#include "Pods/Target Support Files/Pods-Cocoapods Example/Pods-Cocoapods Example.debug.xcconfig"`
6. Add these variables:

```
ALCHEMY_API_KEY = ALCHEMY_API_KEY
REVERSE_URL = REVERSE_URL
GDRIVE_CLIENT_ID = GDRIVE_CLIENT_ID
ENV = prod // staging
```

> If you want to switch to point to staging. Change the ENV variable in your Secrets.xcconfig to be `staging`.

The info plist and main debug configuration file is already configured to import these values directly into the app.

## Running the Example App locally

To run the example project, clone the repo, and from the Example directory run `pod install`.

```
cd Example
pod install
```

## Next Steps

Follow our docs [here](https://docs.portalhq.io/swift-pod/portalswift) to get started!

# Release the SDK

## Trigger the Version Updating

- Go to Actions
- Input the most recent version we are updating to into the input for version
- Check slack for any release errors or the actions console

# Tests

## Unit Tests

The SDK's tests are XCTest unit tests in `Tests/PortalSwiftTests`, run through the `Unit Tests` scheme. In Xcode, select the `Unit Tests` scheme and press `Cmd+U`.

From the command line, this is the same invocation CI runs (`.github/workflows/unit-test.yml`):

```bash
xcodebuild -quiet \
  -workspace PortalSwift.xcworkspace \
  -scheme "Unit Tests" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.4' \
  test
```

Adjust `-destination` to a simulator you have installed. In Xcode, `Product -> Destination -> Manage Run Destinations...` lists them.

The SPM example app does not have a test target.

# Formatting rules

We use both `SwiftFormat` and `SwiftLint` to format our code.

The configuration for `SwiftFormat` can be found in the `.swiftformat` file.
A full list of rules can be found [here](https://github.com/nicklockwood/SwiftFormat/blob/main/Rules.md)

The configuration for `SwiftLint` can be found in the `.swiftlint.yml` file.
This linter is only used for prohibiting force unwrapping and force casting (SwiftFormat does not support throwing linting errors for these rules).

If you want to run the linters without utilizing the pre-commit hook, you can run the following command:

```
swiftformat .
```

```
swiftlint --config .swiftlint.yml
```

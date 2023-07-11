# PortalSwift

[![Run Swift Tests](https://github.com/portal-hq/PortalSwift/actions/workflows/test.yml/badge.svg)](https://github.com/portal-hq/PortalSwift/actions/workflows/test.yml)

# Install

## Set up

Ensure you have the Swift formatter CLI installed (`swiftformat`). If you're using brew, you can run:

```
brew install swiftformat
```

Create an xcConfig file.

1. Add new file to PortalSwift by right clicking on PortalSwift and clicking add new file
2. Search for configuration file
3. Call the new configuration file "Secrets"
4. Add both example and test as targets
5. Add `#include? "Secrets.xcconfig"` to the Pods directory within the `Pods-PortalSwift_Example.debug.xcconfig` file
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


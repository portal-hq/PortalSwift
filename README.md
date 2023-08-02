# PortalSwift

[![Run Swift Tests](https://github.com/portal-hq/PortalSwift/actions/workflows/test.yml/badge.svg)](https://github.com/portal-hq/PortalSwift/actions/workflows/test.yml)

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


# Tests

## E2E Tests

### Overview
We use [*XCTest*](https://developer.apple.com/documentation/xctest) for writing our E2E tests for our iOS SDK. The `Portal.swift` file houses most of the implementation a customer would do for portal. That file is then used by the `ViewController.swift` and the `WalletTests.swift`. The `ViewController.swift`  is for running the UI and the `Tests.swift` is for running the E2E tests. 

### Run It

#### Run the entire test class from xcode
1. Open the project in Xcode
2. Open the `PortalSwift/Tests/e2e/WalletTests.swift` file
3. Within the xcode file editor, where the line numbers are listed, there will be a diamond shape instead of the line number 
   - Hovering over the diamond will make a play button appear
   - Clicking on the play button will run the test
   - If you click play on the entire class it will run the entire test class

#### Run a specific test file 
> This is a bit tricky because there is some setup that will need to be done depending on the test you want to run.

##### Test sign, backup, recover repeatedly (without generating every time)
1. Run the generate test 1st, by hovering over the line number the generate test is on. (currently line 58)
2. Copy the username that is printed in the logs. Ex:
```
USERNAME:  JuHGp8CGFDi1LtO1690986159
```
3. Set the username in the setup function to that username 
```  swift
override class func setUp() {
    super.setUp()
    self.username = "JuHGp8CGFDi1LtO1690986159" // self.randomString(length: 15)
    print("USERNAME: ", self.username!)
    self.PortalWrap = PortalWrapper()
  }
```
4. To test recover just ensure that you have run backup successfully at least once. 

Now you can hover over the sign, backup, or recover tests to run them repeatedly without running generate every time. 
 
#### Run via command line
1. Here is the command you can run from the command line
> Ensure the -destination is a simulator that you have configured in xcode with the correct name and OS. You can verify this in xcode, from the top menu: `Product -> Destination -> Manage Run Destinations...` This will show you a list of your currently installed simulators. 
``` bash
xcodebuild \
  -workspace Example/PortalSwift.xcworkspace \
  -scheme PortalSwift-Example \
  -destination 'platform=iOS Simulator,name=iPhone 14 Pro,OS=16.4' \
  -only-testing:PortalSwift_Tests/WalletTests \
  -xcconfig Example/Secrets.xcconfig \
  build test | xcpretty 
  ```
2. Add `| grep -A9 'Test Suite'` to the end of the command to only print the results of the test and not all the compilation logs


 ### Write It
When writing e2e tests these should also be runnable from the UI. In order to achieve this we have abstracted most of the portal implementation into the `Portal.swift` file. This file is then used by both `ViewController.swift` and `WalletTest.swift`. 

#### Add Feature
Implement the new functionality for the feature in the `Portal.swift` class. 

#### Add Test
Call the function you implemented within the `WalletTest` file.
1. You will need to use the `testLogin` function to have your test register the portal object correctly as a first step.
2. Within the closure of the `testLogin` function, you can write the logic for your test using the functions you defined in `Portal.swift`. 
3. Call these functions using the class variable `WalletTest.PortalWrap`. 

### XCTesting Tidbits
#### Async Tests
When testing an async function use `expectations`.
  - Define an expectation at the beginning of the test 
    ``` swift
    let registerExpectation = XCTestExpectation(description: "Register")
    ```
  - Then where you want to wait for something to finish:
    ``` swift
    wait(for: [registerExpectation], timeout: 200)
    ```
  - Within a closure you will put the notification that the expectation has been fulfilled
    ``` swift
    registerExpectation.fulfill()
    ```
#### Break up code into chunks called activities 
The `testLogin` function is a special XCTest function that is called an activity.
They are used to breakup Test functions into smaller blocks that can be used repeatedly in other tests. 
[An Example from the apple docs](https://developer.apple.com/documentation/xctest/activities_and_attachments/grouping_tests_into_substeps_with_activities)

#### Order of test execution 
Tests are run synchronously in alphabetical order by name.
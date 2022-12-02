# PortalSwift

## Example

To run the example project, clone the repo, and from the Example directory run `pod install`.

## Requirements
- cocoapods 

For more information on cocoa pods, read [this](https://guides.cocoapods.org/using/using-cocoapods.html).

## Installation

To install PortalSwift, add the following line to your Podfile:

```ruby
...

pod 'PortalSwift', :git => 'https://github.com/portal-hq/PortalSwift.git'

...
```

run `pod install`


## Initializing Portal

With the PortalSwift pod now installed, we can now create an instance of the Portal class. Below is an example of how you can do this:

```swift
import PortalSwift

class ViewController: UIViewController {
  public var portal: Portal?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.registerPortal(apiKey: self.clientApiKey)
  }

  func registerPortal(apiKey: String) -> Void {
    do {
      // Create a Portal instance.
      portal = try Portal(
        apiKey: "CLIENT_API_KEY", // Request a Client Api Key from Portal's Rest API.
        backup: BackupOptions(icloud: ICloudStorage()),
        chainId: 5,
        keychain: PortalKeychain(),
        gatewayConfig: [
          5: "https://eth-goerli.g.alchemy.com/v2/[ALCHEMY_API_KEY]"
        ],
        // Optional
        autoApprove: true
      )
      
      // ✅ You successfully created a Portal instance! 🙌
      print("Client API Key: ", portal?.apiKey)

    } catch ProviderInvalidArgumentError.invalidGatewayUrl {
      // ❌ Handle Invalid Gateway URL errors.
    } catch PortalArgumentError.noGatewayConfigForChain(let chainId) {
      // ❌ Handle when the gateway config does not match the chainId you specified.
    } catch {
      // ❌ Handle errors creating an instance of Portal.
    }
  }
}
```

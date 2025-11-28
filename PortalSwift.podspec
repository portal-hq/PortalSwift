Pod::Spec.new do |s|
  s.name             = 'PortalSwift'
  s.version          = "6.4.0"
  s.summary          = "The Portal SDK enables a secure and seamless integration of Portal MPC wallets and Web3 functionalities into your applications."
  s.description      = "The Portal SDK provides an easy way to integrate Multi-Party Computation (MPC) wallets and Web3 capabilities into iOS applications. It enables secure wallet creation, transaction signing, and cross-device session management. The SDK supports multiple authentication and backup methods, ensuring a seamless user experience. Features include:
  • MPC-based wallet creation (no single point of failure)
  • Transaction signing 
  • Cloud-based backup options for account recovery
  • Support for multiple blockchain networks
  • Dozens of developer-centric methods to speed up integration

Designed for performance and security, Portal SDK is optimized for iOS apps requiring seamless blockchain integration."
  s.homepage         = 'https://portalhq.io'
  s.license          = { :type => 'MIT', :text => File.read('LICENSE') }
  s.author           = { 'Portal Labs, Inc.' => 'apple-developer@portalhq.io' }
  s.source           = { :git => 'https://github.com/portal-hq/PortalSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  
  s.vendored_frameworks = "Sources/Frameworks/Mpc.xcframework"
  s.source_files = 'Sources/PortalSwift/**/*'
  s.resources = ['Sources/PortalSwift/**/*.{xcprivacy}']
  s.module_name = 'PortalSwift'

  # Dependencies
  s.dependency "GoogleSignIn", "~> 7.1.0"
  s.dependency "Starscream", "~> 4.0.7"
  s.dependency "AnyCodable-FlightSchool", "~> 0.6.7"
  
  s.libraries = 'resolv'

  # Framework search paths for dependencies
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT) $(PODS_ROOT)/Sources/Frameworks'
  }

  s.test_spec 'Tests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'Tests/**/*.{h,m,swift}'
  end
end

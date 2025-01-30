Pod::Spec.new do |s|
  s.name             = 'PortalSwift'
  s.version          = "4.2.1"
  s.summary          = "Portal's native Swift implementation for iOS applications"
  s.description      = "PortalSwift is a comprehensive native Swift implementation for iOS applications,
                      providing seamless integration with Portal's services."
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

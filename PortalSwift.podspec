Pod::Spec.new do |s|
  s.name             = 'PortalSwift'
  s.version          = "1.1.5"
  s.summary          = "Portal's native Swift implementation"

  s.description      = "Portal's native Swift implementation"

  s.homepage         = 'https://portalhq.io'
  s.license          = { :type => 'MIT' }
  s.author           = 'Portal Labs, Inc.'
  s.source           = { :git => 'https://github.com/portal-hq/PortalSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.vendored_frameworks = "PortalSwift/Frameworks/mpc.xcframework"


  s.source_files = 'PortalSwift/Classes/**/*'

  s.dependency "GoogleSignIn", "~> 6.2"
  s.dependency "Starscream"

    s.test_spec 'UnitTests' do |test_spec|
      test_spec.requires_app_host = false
      test_spec.source_files = 'UnitTests/**/*.{h,m,swift}'
      test_spec.exclude_files = 'UnitTests/Core/PortalKeychainTests.swift'
      # If your tests have any resources like images, xibs, etc.
      # test_spec.resource_bundles = { 'MyLibTests' => ['PortalSwift/Tests/**/*.{xib,storyboard,xcassets,png,jpg}'] }

    end

    s.test_spec 'KeychainTests' do |test_spec|
      test_spec.requires_app_host = true
      test_spec.source_files = 'UnitTests/Core/PortalKeychainTests.swift'
      # If your tests have any resources like images, xibs, etc.
      # test_spec.resource_bundles = { 'MyLibTests' => ['PortalSwift/Tests/**/*.{xib,storyboard,xcassets,png,jpg}'] }

    end

end

Pod::Spec.new do |s|
  s.name             = 'PortalSwift'
  s.version          = '0.0.1'
  s.summary          = "Portal's native Swift implementation"

  s.description      = "Portal's native Swift implementation"

  s.homepage         = 'https://portalhq.io'
  s.license          = { :type => 'MIT' }
  s.author           = 'Portal Labs, Inc.'
  s.source           = { :git => 'https://github.com/portal-hq/PortalSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.vendored_frameworks = "PortalSwift/Frameworks/mpc.xcframework"


  s.source_files = 'PortalSwift/Classes/**/*'

  s.dependency "GoogleSignIn", "~> 6.2"
end

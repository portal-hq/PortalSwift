#
# Be sure to run `pod lib lint PortalSwift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PortalSwift'
  s.version          = '0.0.1'
  s.summary          = "Portal's native Swift implementation"

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/portal-hq/PortalSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Portal Labs, Inc.'
  s.source           = { :git => 'https://github.com/portal-hq/PortalSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'PortalSwift/Classes/**/*'
  
  # s.resource_bundles = {
  #   'PortalSwift' => ['PortalSwift/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end

Pod::Spec.new do |s|
  s.name             = 'GCHelper'
  s.version          = '0.4.4'
  s.summary          = 'A lightweight helper for GameKit, written in Swift'
  s.homepage         = 'https://github.com/jackcook/GCHelper'
  s.license          = 'MIT'
  s.author           = { 'Jack Cook' => 'hello@jackcook.nyc' }
  s.source           = { :git => 'https://github.com/jackcook/GCHelper.git', :tag => '0.4.4' }
  s.social_media_url = 'https://twitter.com/jackcook36'

  s.ios.deployment_target = '8.0'
  s.requires_arc     = true
  s.source_files     = 'Pod/Classes/*'
  s.framework        = 'GameKit'
end

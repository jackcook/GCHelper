Pod::Spec.new do |s|
  s.name         = "GCHelper"
  s.version      = "0.2"
  s.summary      = "A lightweight helper for GameKit, written in Swift"
  s.homepage     = "https://github.com/jackcook/GCHelper"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Jack Cook" => "hello@jackcook.nyc" }

  s.requires_arc = true
  s.platform = :ios, "8.0"
  s.source       = { :git => "https://github.com/jackcook/GCHelper.git", :tag => "0.2" }
  s.source_files = "Source/*.swift"
  s.framework = "GameKit"
end

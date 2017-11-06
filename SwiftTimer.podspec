Pod::Spec.new do |s|

  s.name         = "SwiftTimer"
  s.version      = "2.0"
  s.summary      = "Simple and Elegant Timer"
  s.homepage     = "https://github.com/anotheren/SwiftTimer"
  s.license      = { :type => "MIT" }
  s.author       = { "liudong" => "liudong.edward@qq.com" }
  s.requires_arc = true
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.11"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "10.0"
  s.source       = { :git => "https://github.com/anotheren/SwiftTimer.git",
                     :tag => s.version }
  s.source_files = "Sources/*.swift"

end

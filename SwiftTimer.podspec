Pod::Spec.new do |s|

  s.name         = "SwiftTimer"
  s.version      = "1.0.1"
  s.summary      = "Simple and Elegant Timer"
  s.homepage     = "https://github.com/anotheren/SwiftTimer"
  s.license      = { :type => "MIT" }
  s.author       = { "liudong" => "liudong.edward@qq.com" }
  s.requires_arc = true
  s.ios.deployment_target = "8.0"
  s.source       = { :git => "https://github.com/anotheren/SwiftTimer.git",
                     :tag => s.version }
  s.source_files = "Source/*.swift"

end

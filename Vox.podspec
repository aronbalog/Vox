Pod::Spec.new do |spec|
  spec.name         = 'Vox'
  spec.version      = '1.0.3'
  spec.license      = 'MIT'
  spec.summary      = 'A Swift JSONAPI framework'
  spec.author       = 'Aron Balog'
  spec.homepage     = 'http://undabot.com'
  spec.source       = { :git => 'https://github.com/aronbalog/Vox.git', :tag => spec.version }
  spec.source_files = 'Vox/**/*'
  spec.requires_arc = true
  spec.xcconfig = { 'SWIFT_VERSION' => '4.0' }
  spec.platform        = :ios, '8.0'
end
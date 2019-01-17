Pod::Spec.new do |spec|
	spec.name            = 'Vox'
	spec.version         = '1.2.3'
	spec.license         = 'MIT'
	spec.summary         = 'A Swift JSONAPI framework'
	spec.author          = 'Aron Balog'
	spec.homepage        = 'http://undabot.com'
	spec.source          = { :git => 'https://github.com/aronbalog/Vox.git', :tag => spec.version }
	spec.requires_arc    = true
	spec.xcconfig        = { 'SWIFT_VERSION' => '4.2' }
	spec.platform        = :ios, '8.0'
	spec.default_subspec = 'Core'

	spec.subspec 'Core' do |core|
		core.source_files = 'Vox/Core/**/*.{swift,m,h}'
	end

	spec.subspec 'Alamofire' do |alamofire|
		alamofire.source_files = 'Vox/Plugins/Alamofire/**/*.{swift}'
		alamofire.pod_target_xcconfig = {
		  'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'ALAMOFIRE',
		}
		alamofire.dependency 'Vox/Core'
		alamofire.dependency 'Alamofire', '~> 4.7'
	end
end
Pod::Spec.new do |spec|
	spec.name            = 'Vox'
	spec.version         = '1.2.3'
	spec.license         = { :type => 'MIT', :file => 'LICENSE.md' }
	spec.summary         = 'A Swift JSON:API framework'
	spec.author          = 'Aron Balog'
	spec.homepage        = 'https://github.com/aronbalog/Vox'
	spec.source          = { :git => 'https://github.com/aronbalog/Vox.git', :tag => spec.version }
	spec.swift_versions  = ['5.0']
	spec.default_subspec = 'Core'

	spec.ios.deployment_target     = '13.0'
	spec.osx.deployment_target     = '10.15'
	spec.tvos.deployment_target    = '13.0'
	spec.watchos.deployment_target = '6.0'

	spec.subspec 'Core' do |core|
		core.source_files = 'Sources/Vox/**/*.swift'
	end

	spec.subspec 'Alamofire' do |alamofire|
		alamofire.source_files = 'Sources/VoxAlamofire/**/*.swift'
		alamofire.pod_target_xcconfig = {
		  'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'ALAMOFIRE',
		}
		alamofire.dependency 'Vox/Core'
		alamofire.dependency 'Alamofire', '~> 4.7'
	end
end

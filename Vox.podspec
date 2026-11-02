Pod::Spec.new do |spec|
	spec.name            = 'Vox'
	spec.version         = '2.0.0'
	spec.license         = { :type => 'MIT', :file => 'LICENSE.md' }
	spec.summary         = 'A Swift JSON:API framework'
	spec.author          = 'Aron Balog'
	spec.homepage        = 'https://github.com/aronbalog/Vox'
	spec.source          = { :git => 'https://github.com/aronbalog/Vox.git', :tag => spec.version }
	spec.swift_versions  = ['6.0']
	spec.source_files    = 'Sources/Vox/**/*.swift'

	spec.ios.deployment_target     = '13.0'
	spec.osx.deployment_target     = '10.15'
	spec.tvos.deployment_target    = '13.0'
	spec.watchos.deployment_target = '6.0'
end

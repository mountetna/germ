Gem::Specification.new do |spec|
  spec.name = 'taylorlib'
  spec.version = '0.1'
  spec.summary = 'Collection of utilities for use in computational genomics, including hash_table.'
  spec.description = 'See summary'
  spec.email = 'Saurabh.Asthana@ucsf.edu'
  spec.homepage = ''
  spec.author = 'Saurabh Asthana'
  spec.files = Dir['lib/**/*.rb'] +  Dir['ext/**/*.c'] + Dir['ext/**/extconf.rb']
  spec.platform = Gem::Platform::RUBY # This is the default
  spec.require_paths = [ 'lib', 'ext' ]
  spec.extensions = Dir['ext/**/extconf.rb']
  spec.add_dependency 'extlib'
  spec.add_dependency 'net-http-persistent'
  spec.add_dependency 'sequel'
end

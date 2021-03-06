# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = 'fluent-plugin-nata'
  gem.version     = '0.0.1'
  gem.authors     = ['Satoshi SUZUKI']
  gem.email       = 'studio3104.com@gmail.com'
  gem.homepage    = 'https://github.com/studio3104/fluent-plugin-nata'
  gem.description = 'Fluentd output plugin to insert MySQL slowquery to Nata'
  gem.summary     = gem.description
  gem.licenses    = ['MIT']
  gem.has_rdoc    = false

  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency 'fluentd', '~> 0.10.17'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'myslog'
  gem.add_development_dependency 'webrick'
end

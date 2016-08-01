# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'listpager/version'

Gem::Specification.new do |spec|
  spec.name          = "listpager"
  spec.version       = Listpager::VERSION
  spec.authors       = ["Mike Owens"]
  spec.email         = ["mike@meter.md"]

  spec.summary       = "Interactive terminal pager for lists"
  spec.description   = "Ncurses list pager, controllable via stdin and stdout"
  spec.homepage      = "https://github.com/mieko/listpager"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org/"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Check out the hack in ext/mkrf_conf.rb, which is effectively:
  #
  # if RUBY_PLATFORM =~ /\bdarwin/
  #   spec.add_runtime_dependency 'ncurses-ruby'
  # else
  #   # Doesn't build on newer macOS...
  #   spec.add_runtime_dependency 'ncursesw'
  # end
  #
  # A PR has been submitted to ncursesw, so hopefully this can go away soon.

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
end

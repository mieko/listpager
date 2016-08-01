require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
  # We're good
end

inst = Gem::DependencyInstaller.new
begin
  if RUBY_PLATFORM =~ /\bdarwin/i
    inst.install "ruby-ncurses", "~> 1.2.4"
  else
    inst.install "ncursesw", "~> 1.4.9"
  end
rescue
  exit 1
end

# create dummy rakefile to indicate success
File.write(__dir__("Rakefile"), "task: default\n")

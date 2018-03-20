require 'date'

Gem::Specification.new do |s|
  s.name              = "dockershell"
  s.version           = '0.0.2'
  s.date              = Date.today.to_s
  s.summary           = "Provides a user shell backed by  a Docker container."
  s.homepage          = "https://github.com/binford2k/dockershell/"
  s.email             = "binford2k@gmail.com"
  s.authors           = ["Ben Ford"]
  s.license           = "Apache-2.0"
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( dockershell )
  s.files             = %w( README.md )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("resources/**/*")
  s.files            += Dir.glob("scripts/**/*")
  s.add_dependency      "facter"
  s.description       = <<-desc
    Dockershell can be used as a user login shell, or simply run on the CLI. It
    will stand up a Docker container and then drop the user into a bash shell
    on the container. It's highly configurable and supports multiple profiles.
  desc
end

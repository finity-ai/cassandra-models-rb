# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "paper-models/version"

Gem::Specification.new do |s|
  s.name        = "paper-models"
  s.version     = Paper::Models::VERSION
  s.authors     = ["Pierre-Yves Ritschard"]
  s.email       = ["pyr@spootnik.org"]
  s.homepage    = "https://github.com/pyr/paper-models"
  s.summary     = %q{very simple cassandra entity support}
  s.description = %q{ORM layer on top of cassandra, without relation support}

  s.rubyforge_project = "paper-models"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "cassandra-cql"
  s.add_runtime_dependency "json"
end

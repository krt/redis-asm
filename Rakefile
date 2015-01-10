require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc 'Run benchmark'
task :bench do
  sh 'bundle', 'exec', 'ruby', 'bench/bench.rb'
end

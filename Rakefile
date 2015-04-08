require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'yard'

# Testing with rspec
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = %w{--color --format documentation}
end

task :test => :spec

# Generate documentation with yard
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
end

desc "Generate gem documentation (same as running 'rake yard')"
task :doc => :yard

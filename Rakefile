require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'yard'
require 'rubocop/rake_task'

# Testing with rspec
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = %w{--color --format documentation}
end

task :test => :spec

# Generate documentation with yard
YARD::Rake::YardocTask.new do |t|
  t.files = %w(lib/*.rb lib/enscalator/*.rb lib/enscalator/plugins/*.rb)
  t.stats_options = %w{--list-undoc --compact}
end

desc 'Generate gem documentation (same as running "rake yard")'
task :doc => :yard

# Use RuboCop to check for code/style offenses
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|

  # include everything except templates and tests
  task.patterns = %w{lib/*.rb lib/enscalator/*.rb lib/enscalator/plugins/*.rb }

  # don't abort rake on failure
  task.fail_on_error = false
end

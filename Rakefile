require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'yard'
require 'rubocop/rake_task'

# Testing with rspec
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = %w(--color --format documentation)
end
task test: :spec

# Generate documentation with yard
YARD::Rake::YardocTask.new do |t|
  t.files = %w(lib/*.rb lib/enscalator/*.rb lib/enscalator/plugins/*.rb)
  t.stats_options = %w(--list-undoc --compact)
end
desc 'Generate gem documentation (same as running "rake yard")'
task doc: :yard

# Print all available plugins
namespace :enscalator do
  namespace :plugins do
    desc 'Show all available plugins'
    task :show do
      require 'enscalator'
      root_dir = Pathname.new('lib/enscalator')
      plugins = Enscalator::Plugins.constants
      # print pairs of plugin module name / filename
      root_dir.join('plugins').children.select { |p| p.to_s.end_with?('.rb') }.each do |plugin_file|
        plugin_module = plugins.find { |p| p.to_s.underscore == File.basename(plugin_file, '.rb').to_s }
        STDOUT.puts "Enscalator::Plugins::#{plugin_module} (#{plugin_file})"
      end
    end
  end
end

# Use RuboCop to check for code/style offenses
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  # don't abort rake on failure
  task.fail_on_error = false
end
task default: [:rubocop, :spec]

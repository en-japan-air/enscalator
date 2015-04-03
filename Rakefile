require 'bundler/gem_tasks'
require 'yard'

# Generate documentation with yard
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']   # optional
end

desc "Generate gem documentation (same as running 'rake yard')"
task :doc => :yard

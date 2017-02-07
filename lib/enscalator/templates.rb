require_relative 'templates/vpc_peering'

module Enscalator
  # Namespace for template collection
  module Templates
    # Get all loaded template classes
    # @return [Array]
    def self.all
      namespace = Enscalator::Templates
      templates = namespace.constants
      templates.map { |t| (namespace.to_s.split('::') << t.to_s).join('::').constantize }
    end

    # Verify if all loaded templates have required tpl method
    # @return [Boolean]
    def self.all_valid?
      all.map { |t| t.instance_methods.include?(:tpl) }.all?
    end
  end
end

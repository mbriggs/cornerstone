# Declarative access to Rails config.x.* settings.
# The config analog to Credentials::Accessor — provides DRY, named accessors
# for arbitrary config paths.
#
# Direct read:
#   Configuration.read(:x, :logging)  # => Rails.application.config.x.logging
#
# Accessor macro:
#   class MyService
#     include Configuration::Accessor
#     config :logging, [:x, :logging]
#   end
#
#   MyService.new.logging  # => Rails.application.config.x.logging
#
module Configuration
  def self.read(*path)
    path = Array(path).map(&:to_sym)
    current = Rails.application.config

    path.each do |key|
      return nil unless current.respond_to?(key)

      current = current.public_send(key)
    end

    # config.x auto-vivifies: config.x.nonexistent returns an empty
    # OrderedOptions (truthy). Treat that as "not configured".
    return nil if current.is_a?(ActiveSupport::OrderedOptions) && current.blank?

    current
  end

  module Accessor
    extend ActiveSupport::Concern

    class_methods do
      # Macro to create a method `name`, which is an accessor to configuration located at `path`
      def config(name, path)
        name = name.to_sym

        if path.empty?
          raise ArgumentError, "include a path to dig rails configuration"
        end

        if instance_methods.include?(name)
          raise NameError, "#{name} cannot be a config, it is already defined as a method"
        end

        define_method name do
          Configuration.read(*path)
        end
      end
    end
  end
end

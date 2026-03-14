# Concern that provides convenient access to credentials stored in Rails.application.credentials
# Credentials are searched for in the following locations, returning the first value found:
#  - path as specified
#  - path under a key named after the current environment
#  - path under a key named 'development' when in test mode
#
# If the credentials are not found in the credentials file, it will raise a MissingCredentialsError.
#
# Usage:
#
#   Credentials.read(:aws, :access_key)
#
# or
#
#   class MyService
#     include Credentials::Accessor
#
#     credentials :aws_key, [ :aws, :access_key ]
#     credentials :aws_secret, [ :aws, :secret_key ]
#
#     def initialize
#       puts aws_key     # Access to Rails.application.credentials.dig(:aws, :access_key)
#       puts aws_secret  # Access to Rails.application.credentials.dig(:aws, :secret_key)
#     end
#   end
#
#   service = MyService.new
#   # => Prints the AWS access key and secret key from credentials file
#
module Credentials
  def self.read(*path)
    path = path.map(&:to_sym)
    credentials = Rails.application.credentials

    # default: search for path as specified
    value = credentials.config.dig(*path)

    # if not found, search for path in the current environment
    if !value
      value = credentials.config.dig(Rails.env.to_sym, *path)
    end

    # if not found, search for path in development environment when in test mode
    if !value && Rails.env.test?
      value = credentials.config.dig(:development, *path)
    end

    # still not found, raise an error
    if !value
      raise MissingCredentialsError, path
    end

    value
  end

  class MissingCredentialsError < StandardError
    # Initializes the error with a message indicating the missing credentials path.
    def initialize(path)
      super("Credentials missing: #{path}. These should be present in the credentials file")
    end
  end

  module Accessor
    extend ActiveSupport::Concern

    class_methods do
      # Macro to create a method `name`, which is an accessor to credentials located at `path`.
      def credential(name, path)
        name = name.to_sym
        path = path.dup

        if path.blank?
          raise ArgumentError, "include a path to dig through rails credentials"
        end

        if instance_methods.include?(name)
          # This is specifically to handle a class reloading scenario, it should never happen in
          # prod, and don't want to mask bugs
          if Rails.env.development? && instance_method(name).source_location&.first&.include?("credentials.rb")
            remove_method(name)
          else
            raise NameError, "#{name} cannot be a credential, it is already defined as a method"
          end
        end

        define_method name do
          if instance_variable_defined?(:"@#{name}")
            instance_variable_get(:"@#{name}")
          else
            instance_variable_set(:"@#{name}", Credentials.read(*path))
          end
        end
      end
    end
  end
end

# Sanitizes user-supplied text attributes through InputSanitizer before validation.
# Guarantees that all persisted text has been cleaned regardless of entry point
# (controller, console, background job). AnthropicClient verifies at the API
# boundary with InputSanitizer.sanitize!.
#
# Usage:
#   class Problem < ApplicationRecord
#     include Sanitizable
#     sanitizes :title, :summary, :raw_input
#   end
#
# Handles strings, arrays of strings, and JSONB hashes with string values.
# Nil values are skipped. Sanitization is idempotent.
module Sanitizable
  extend ActiveSupport::Concern

  included do
    class_attribute :_sanitized_attributes, default: []
    before_validation :sanitize_inputs
  end

  class_methods do
    def sanitizes(*attributes)
      self._sanitized_attributes = attributes.map(&:to_sym)
    end
  end

  private

    def sanitize_inputs
      self.class._sanitized_attributes.each do |attr|
        value = public_send(attr)
        next if value.nil?

        public_send(:"#{attr}=", sanitize_value(value))
      end
    end

    def sanitize_value(value)
      case value
      when String then InputSanitizer.sanitize(value)
      when Array then value.map { |v| sanitize_value(v) }
      when Hash then value.transform_values { |v| sanitize_value(v) }
      else value
      end
    end
end

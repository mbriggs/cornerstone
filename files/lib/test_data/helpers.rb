# Test helpers for accessing fixtures
#
# Include in test_helper.rb to get accessor methods like:
#   users(:alice)
#   problems(:onboarding)


module TestData
  module Helpers
    extend ActiveSupport::Concern

    class_methods do
      # Define an accessor method for a model
      #
      # @param method_name [Symbol] The helper method name
      # @param model [Class] The ActiveRecord model class
      def accessor(method_name, model)
        define_method(method_name) do |name|
          TestData.find(model, name)
        end
      end
    end

    included do
      accessor :users, User
    end
  end
end

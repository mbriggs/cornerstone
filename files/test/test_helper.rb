ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require_relative "../lib/test_data"
require_relative "../lib/test_data/fixture"
require_relative "../lib/test_data/fixtures/users"
require_relative "../lib/test_data/helpers"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/anthropic_test_helper"
require_relative "test_helpers/api_test_helper"
require_relative "support/html_test_helper"

# Configure logging from TEST_LOGGING environment variable
# This overrides any memoized config from early class loading
if ENV["TEST_LOGGING"].present?
  config = ENV["TEST_LOGGING"] == "1" ? "_all->DEBUG" : ENV["TEST_LOGGING"]
  Logging.config = config
else
  Logging.config = ""  # Empty string = no logging
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      TestData.load
    end

    include TestData::Helpers
    include HtmlTestHelper
    include AnthropicTestHelper

    # Single-process fallback (parallelize_setup doesn't fire with workers=1)
    def before_setup
      TestData.load
      super
    end
  end
end

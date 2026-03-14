# HtmlTestHelper is a concern for test helpers related to HTML assertions and utilities.
# It uses nested modules (HtmlTestHelper::System, HtmlTestHelper::Controller)
# to provide different method implementations depending on the test type it is included into.
# Each nested module MUST implement:
#   - test_id(*parts, tag: nil, starts_with: false, pseudo: nil)
#   - assert_flash(type, text = nil)
#   - assert_no_flash(type)
# This pattern ensures test-type-specific logic is isolated, while shared helpers remain DRY.
#
# Usage:
#   include HtmlTestHelper
#   (the appropriate nested module will be included automatically)
module HtmlTestHelper
  extend ActiveSupport::Concern

  included do
    if defined?(Capybara) && self < ActionDispatch::SystemTestCase
      include HtmlTestHelper::System
    elsif self < ActionDispatch::IntegrationTest
      include HtmlTestHelper::Controller
    end
  end

  protected

  # Returns a selector for an element with the given data-test-id.
  #
  # Arguments:
  #   *parts       - Parts to join and dasherize as the data-test-id value
  #   tag:         - Optional tag name (symbol or string)
  #   starts_with: - If true, matches data-test-id values that start with the given value
  #   pseudo:      - Optional pseudo-class (e.g., :checked)
  #
  # Implementations must return a selector string appropriate for the test type.
  protected def test_id(*parts, tag: nil, starts_with: false, pseudo: nil)
    raise NotImplementedError, "Implement #test_id in the nested test-type module (System or Controller)"
  end

  # Asserts the presence of a flash message of the given type, optionally matching text.
  #
  # Arguments:
  #   type - Symbol or string flash type (e.g., :success, :error)
  #   text - Optional string to match within the flash message
  #
  # Implementations must assert presence using the appropriate mechanism for the test type.
  protected def assert_flash(type, text = nil)
    raise NotImplementedError, "Implement #assert_flash in the nested test-type module (System or Controller)"
  end

  # Asserts the absence of a flash message of the given type.
  #
  # Arguments:
  #   type - Symbol or string flash type (e.g., :success, :error)
  #
  # Implementations must assert absence using the appropriate mechanism for the test type.
  protected def assert_no_flash(type)
    raise NotImplementedError, "Implement #assert_no_flash in the nested test-type module (System or Controller)"
  end

  # Shared test type predicates
  protected def system_test?
    defined?(Capybara) && self.class < ActionDispatch::SystemTestCase
  end

  protected def controller_test?
    self.class < ActionDispatch::IntegrationTest
  end

  module System
    protected def test_id(*parts, tag: nil, starts_with: false, pseudo: nil)
      value = parts.map(&:to_s).join("-").dasherize
      attr = starts_with ? "^=" : "="
      selector = "[data-test-id#{attr}'#{value}']"
      selector = "#{tag}#{selector}" if tag
      selector = "#{selector}:#{pseudo}" if pseudo
      selector
    end

    protected def assert_flash(type, text = nil)
      selector = test_id("flash-#{type}")
      if text
        assert_selector selector, text: text
      else
        assert_selector selector
      end
    end

    protected def assert_no_flash(type)
      selector = test_id("flash-#{type}")

      assert_no_selector selector
    end
  end

  module Controller
    protected def test_id(*parts, tag: nil, starts_with: false, pseudo: nil)
      value = parts.map(&:to_s).join("-").dasherize
      tag_name = tag || "*"
      attr_expr = starts_with ? "starts-with(@data-test-id, '#{value}')" : "@data-test-id='#{value}'"
      pseudo_expr = pseudo == "checked" ? " and @checked" : ""
      "#{tag_name}[#{attr_expr}#{pseudo_expr}]"
    end

    protected def assert_flash(type, text = nil)
      value = flash[type.to_sym] || flash[type.to_s]

      assert value.present?, "Expected flash[:#{type}] to be present"
      assert_includes value, text if text
    end

    protected def assert_no_flash(type)
      value = flash[type.to_sym] || flash[type.to_s]

      assert value.blank?, "Expected flash[:#{type}] to be blank"
    end
  end
end

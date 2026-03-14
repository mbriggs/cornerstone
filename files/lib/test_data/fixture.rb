# Base class for defining test fixtures
#
# Usage:
#   class TestData::Fixtures::Users < TestData::Fixture
#     def load
#       create User, :alice, email_address: "alice@example.com", ...
#     end
#   end

module TestData
  class Fixture
    include Logging

    class << self
      def load
        new.load
      end
    end

    # Create a fixture with a deterministic ID
    #
    # @param model [Class] The ActiveRecord model class
    # @param name [Symbol] The fixture name (used for lookup)
    # @param attrs [Hash] Attributes to set on the model
    # @return [ActiveRecord::Base] The created record
    def create(model, name, **attrs)
      table_name = model.table_name
      id = TestData.fixture_id(table_name, name)

      TestData.defined.add([ table_name, name.to_sym ])

      record = model.new(attrs)
      record.id = id
      record.save!(validate: false)

      logger.debug { "Created #{model.name}(:#{name}) id=#{id}" }

      record
    end

    # Get a previously created fixture
    #
    # @param model [Class] The ActiveRecord model class
    # @param name [Symbol] The fixture name
    # @return [ActiveRecord::Base] The found record
    def find(model, name)
      TestData.find(model, name)
    end

    # Subclasses implement this to define fixtures
    def load
      raise NotImplementedError, "Subclasses must implement #load"
    end
  end
end

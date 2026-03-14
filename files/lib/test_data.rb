# TestData - Simple test fixture management
#
# Replaces Rails YAML fixtures with a simpler, more predictable approach:
# - Always truncate + load (no stale detection)
# - Deterministic IDs via Zlib.crc32 hash
# - Simple @loaded flag for per-process idempotency
#
# Usage:
#   TestData.load           # Truncates tables and loads all fixtures
#   TestData.find(User, :alice)  # Finds a fixture by name
#   TestData.fixture_id("users", :alice)  # Returns deterministic ID

require "zlib"

module TestData
  include Logging

  module Fixtures; end

  # Offset ensures fixture IDs never collide with auto-increment IDs
  # 2^28 = 268,435,456 - far beyond typical auto-increment ranges
  FIXTURE_ID_OFFSET = 2**28

  class << self
    # Track which fixtures have been defined (for error messages and diagnostics)
    # Set of [table_name, name] pairs
    def defined
      @defined ||= Set.new
    end

    # Compute a deterministic ID for a fixture
    # Uses CRC32 hash of "table_name:name" plus offset to avoid collisions
    def fixture_id(table_name, name)
      hash = Zlib.crc32("#{table_name}:#{name}")
      FIXTURE_ID_OFFSET + (hash % FIXTURE_ID_OFFSET)
    end

    # Find a fixture by model and name
    # Computes the ID on-the-fly and does find_by
    def find(model, name)
      table_name = model.table_name
      id = fixture_id(table_name, name)
      record = model.find_by(id: id)

      unless record
        available = defined_for(table_name)
        hint = available.any? ? "Available: #{available.join(', ')}" : "None defined"
        raise "Fixture not found: #{model.name}(:#{name}). #{hint}"
      end

      record
    end

    # List fixture names defined for a table
    def defined_for(table_name)
      defined
        .select { |t, _| t == table_name }
        .map { |_, name| ":#{name}" }
        .sort
    end

    # Load all fixtures (truncate + create)
    # Uses @loaded flag for per-process idempotency (handles parallel tests)
    def load
      return if @loaded
      @loaded = true

      logger.debug { "Loading test data..." }

      truncate_tables
      load_fixtures

      logger.debug { "Test data loaded: #{defined.size} fixtures" }
    end

    # Reset loaded state (useful for testing TestData itself)
    def reset!
      @loaded = false
      @defined = nil
    end

    private

    # Truncate all application tables in a single statement.
    # A single TRUNCATE acquires all locks atomically, avoiding the deadlock
    # window that per-table truncation creates under parallel test workers.
    def truncate_tables
      conn = ActiveRecord::Base.connection
      skip = %w[schema_migrations ar_internal_metadata]
      tables = conn.tables - skip
      return if tables.empty?

      conn.truncate_tables(*tables)
    end

    def load_fixtures
      # Load fixtures in dependency order
      TestData::Fixtures::Users.load
    end
  end
end

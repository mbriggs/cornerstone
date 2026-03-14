# Seed users for tests.
#
# Usage in tests: users(:alice), users(:bob)

class TestData::Fixtures::Users < TestData::Fixture
  def load
    create User, :alice,
      email_address: "alice@example.com",
      password: "password123",
      name: "Alice"

    create User, :bob,
      email_address: "bob@example.com",
      password: "password123",
      name: "Bob"
  end
end

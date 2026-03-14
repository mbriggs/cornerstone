require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  # -- deactivated? --

  test "deactivated? returns true when deactivated_at is set" do
    user = users(:alice)
    user.deactivated_at = Time.current
    assert user.deactivated?
  end

  test "deactivated? returns false when deactivated_at is nil" do
    user = users(:alice)
    user.deactivated_at = nil
    refute user.deactivated?
  end

  # -- initial --

  test "initial returns first letter of name uppercased" do
    user = User.new(name: "alice", email_address: "a@example.com")
    assert_equal "A", user.initial
  end

  test "initial falls back to email when name is nil" do
    user = User.new(name: nil, email_address: "bob@example.com")
    assert_equal "B", user.initial
  end

  # -- generate_api_token --

  test "generate_api_token returns a 48-char hex string" do
    plaintext = users(:alice).generate_api_token

    assert_equal 48, plaintext.length
    assert_match(/\A[0-9a-f]{48}\z/, plaintext)
  end

  test "generate_api_token creates an APIToken record" do
    user = users(:alice)

    assert_difference -> { user.api_tokens.count }, 1 do
      user.generate_api_token
    end
  end

  test "generate_api_token stores correct SHA-256 digest" do
    user = users(:alice)
    plaintext = user.generate_api_token
    token = user.api_tokens.last

    assert_equal Digest::SHA256.hexdigest(plaintext), token.token_digest
  end

  test "generate_api_token stores prefix as first 8 chars" do
    user = users(:alice)
    plaintext = user.generate_api_token
    token = user.api_tokens.last

    assert_equal plaintext.first(8), token.token_prefix
  end

  test "generate_api_token accepts label keyword" do
    user = users(:alice)
    user.generate_api_token(label: "ci-bot")
    token = user.api_tokens.last

    assert_equal "ci-bot", token.label
  end

  # -- revoke_api_tokens --

  test "revoke_api_tokens deletes tokens matching label" do
    user = users(:alice)
    user.generate_api_token(label: "ephemeral")
    user.generate_api_token(label: "ephemeral")

    assert_difference -> { user.api_tokens.count }, -2 do
      user.revoke_api_tokens(label: "ephemeral")
    end
  end

  test "revoke_api_tokens leaves tokens with different labels untouched" do
    user = users(:alice)
    user.generate_api_token(label: "keep")
    user.generate_api_token(label: "remove")

    user.revoke_api_tokens(label: "remove")

    assert_equal 1, user.api_tokens.count
    assert_equal "keep", user.api_tokens.first.label
  end

  test "revoke_api_tokens leaves unlabeled tokens untouched" do
    user = users(:alice)
    user.generate_api_token
    user.generate_api_token(label: "remove")

    user.revoke_api_tokens(label: "remove")

    assert_equal 1, user.api_tokens.count
    assert_nil user.api_tokens.first.label
  end
end

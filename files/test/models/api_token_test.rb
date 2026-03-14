require "test_helper"

class APITokenTest < ActiveSupport::TestCase
  # -- authenticate --

  test "authenticate returns user for valid plaintext" do
    user = users(:alice)
    plaintext = user.generate_api_token

    assert_equal user, APIToken.authenticate(plaintext)
  end

  test "authenticate returns nil for invalid plaintext" do
    assert_nil APIToken.authenticate("not_a_real_token")
  end

  test "authenticate returns nil for blank" do
    assert_nil APIToken.authenticate("")
    assert_nil APIToken.authenticate(nil)
  end

  # -- masked --

  test "masked returns prefix followed by dots" do
    user = users(:alice)
    plaintext = user.generate_api_token
    token = user.api_tokens.last

    assert_equal "#{plaintext.first(8)}••••••••", token.masked
  end
end

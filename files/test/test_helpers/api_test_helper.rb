module ApiTestHelper
  # Returns headers for authenticated API requests.
  # Generates a token on first call per user, reuses it on subsequent calls.
  def api_headers(user)
    @api_tokens ||= {}
    @api_tokens[user.id] ||= user.generate_api_token(label: "test")
    {
      "Authorization" => "Bearer #{@api_tokens[user.id]}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  # Parsed JSON response body.
  def json_response
    JSON.parse(response.body)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ApiTestHelper
end

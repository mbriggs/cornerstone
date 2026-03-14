# Rate limiting via Rack::Attack.
#
# Uses Rails.cache (Solid Cache in production) as the backing store.
# Throttles are keyed by session cookie or IP to avoid DB lookups in the
# Rack layer. Limits are conservative — loosen based on real usage.

class Rack::Attack
  # -- Throttles --

  # OAuth callback abuse prevention
  throttle("auth/callbacks", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/") && req.get?
  end

  # API general — 300 requests/minute per token
  throttle("api/general", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      token = req.env["HTTP_AUTHORIZATION"]&.delete_prefix("Bearer ")&.strip
      Digest::SHA256.hexdigest(token) if token.present?
    end
  end

  # API writes — 60 requests/minute per token
  throttle("api/writes", limit: 60, period: 1.minute) do |req|
    if req.post? && req.path.start_with?("/api/")
      token = req.env["HTTP_AUTHORIZATION"]&.delete_prefix("Bearer ")&.strip
      Digest::SHA256.hexdigest(token) if token.present?
    end
  end

  # -- Custom response --

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    period = match_data[:period]
    retry_after = period - (now % period)

    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Rate limit exceeded. Try again in #{retry_after.to_i} seconds.\n" ]
    ]
  end
end

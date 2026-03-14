# A hashed Bearer token for API and MCP access.
#
# Tokens are SHA-256 digested at rest — the plaintext is only available at
# creation time. Each token carries a human-readable label (e.g. "localhost:3020")
# and an 8-char prefix for masked display in the admin UI.
#
#   plaintext = user.generate_api_token(label: "localhost:3020")
#   APIToken.authenticate(plaintext) # => User or nil
#
class APIToken < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true

  # Finds the user for a plaintext token. Returns nil if no match.
  def self.authenticate(plaintext)
    return nil if plaintext.blank?

    token = find_by(token_digest: Digest::SHA256.hexdigest(plaintext))
    token&.user
  end

  # Displayed as "ab12cd34••••••••" in the admin UI.
  def masked
    "#{token_prefix}••••••••"
  end
end

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :active, -> { where(deactivated_at: nil) }

  validates :email_address, presence: true, uniqueness: true

  # Whether the user's access has been revoked.
  def deactivated?
    deactivated_at.present?
  end

  # First letter of the user's name, uppercased. Falls back to email.
  def initial
    (name || email_address).first.upcase
  end

  # Creates a new API token with an optional label. Returns the plaintext.
  # The plaintext is only available at creation time — it is not persisted.
  def generate_api_token(label: nil)
    plaintext = SecureRandom.hex(24)
    api_tokens.create!(
      token_digest: Digest::SHA256.hexdigest(plaintext),
      token_prefix: plaintext.first(8),
      label: label
    )
    plaintext
  end

  # Revokes all tokens matching the given label.
  def revoke_api_tokens(label:)
    api_tokens.where(label: label).delete_all
  end
end

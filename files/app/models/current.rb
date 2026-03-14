class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user

  # Cookie auth sets Current.session (user comes via delegation).
  # API auth sets Current.user directly.
  # Code reading Current.user works in both cases.
  def user
    super || session&.user
  end
end

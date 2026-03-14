# A user's login session, tied to a browser cookie.
#
# Sessions expire after SESSION_DURATION (2 weeks). The +active+ scope filters
# out expired sessions, and +find_session_by_cookie+ in Authentication uses it
# so expired cookies are silently ignored.
class Session < ApplicationRecord
  SESSION_DURATION = 2.weeks

  belongs_to :user

  before_create { self.expires_at = SESSION_DURATION.from_now }

  scope :active, -> { where("expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end
end

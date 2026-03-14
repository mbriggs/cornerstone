require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "before_create sets expires_at" do
    session = users(:alice).sessions.create!
    assert_not_nil session.expires_at
    assert_in_delta Session::SESSION_DURATION.from_now, session.expires_at, 5.seconds
  end

  test "expired? returns true for past expires_at" do
    session = users(:alice).sessions.create!
    session.update_column(:expires_at, 1.minute.ago)
    assert session.expired?
  end

  test "expired? returns false for future expires_at" do
    session = users(:alice).sessions.create!
    refute session.expired?
  end

  test "active scope excludes expired sessions" do
    active_session = users(:alice).sessions.create!
    expired_session = users(:alice).sessions.create!
    expired_session.update_column(:expires_at, 1.minute.ago)

    assert_includes Session.active, active_session
    refute_includes Session.active, expired_session
  end
end

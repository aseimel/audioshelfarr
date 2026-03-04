# frozen_string_literal: true

require "test_helper"

class ActivityLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "requires action" do
    log = ActivityLog.new(user: @user)
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "track creates log entry" do
    assert_difference "ActivityLog.count", 1 do
      ActivityLog.track(action: "user.login", user: @user)
    end

    log = ActivityLog.last
    assert_equal "user.login", log.action
    assert_equal @user, log.user
  end

  test "track handles exceptions gracefully" do
    assert_nothing_raised do
      ActivityLog.track(action: nil, user: @user)
    end
  end

  test "recent scope orders by created_at desc" do
    old_log = ActivityLog.create!(action: "user.login", user: @user, created_at: 2.hours.ago)
    new_log = ActivityLog.create!(action: "user.logout", user: @user, created_at: 1.hour.ago)

    assert_equal new_log, ActivityLog.recent.first
  end

  test "for_action scope filters by action" do
    ActivityLog.create!(action: "user.login", user: @user)
    ActivityLog.create!(action: "user.logout", user: @user)

    assert_equal 1, ActivityLog.for_action("user.login").count
  end

  test "by_user scope filters by user" do
    other_user = users(:two)
    ActivityLog.create!(action: "user.login", user: @user)
    ActivityLog.create!(action: "user.login", user: other_user)

    assert_equal 1, ActivityLog.by_user(@user).count
  end

  test "for_trackable scope filters by trackable" do
    request = requests(:pending_request)
    ActivityLog.create!(action: "request.created", user: @user, trackable: request)
    ActivityLog.create!(action: "user.login", user: @user)

    assert_equal 1, ActivityLog.for_trackable(request).count
  end
end

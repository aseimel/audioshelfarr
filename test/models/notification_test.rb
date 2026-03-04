# frozen_string_literal: true

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "requires notification_type" do
    notification = Notification.new(user: @user, title: "Test")
    assert_not notification.valid?
    assert_includes notification.errors[:notification_type], "can't be blank"
  end

  test "requires title" do
    notification = Notification.new(user: @user, notification_type: "request_completed")
    assert_not notification.valid?
    assert_includes notification.errors[:title], "can't be blank"
  end

  test "validates notification_type inclusion" do
    notification = Notification.new(
      user: @user,
      title: "Test",
      notification_type: "invalid_type"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:notification_type], "is not included in the list"
  end

  test "unread scope returns unread notifications" do
    @user.notifications.create!(notification_type: "request_completed", title: "Unread")
    @user.notifications.create!(notification_type: "request_failed", title: "Read", read_at: Time.current)

    assert_equal 1, @user.notifications.unread.count
    assert_equal "Unread", @user.notifications.unread.first.title
  end

  test "recent scope orders by created_at desc and limits to 20" do
    25.times do |i|
      @user.notifications.create!(notification_type: "request_completed", title: "Notification #{i}")
    end

    recent = @user.notifications.recent
    assert_equal 20, recent.count
    assert_equal "Notification 24", recent.first.title
  end

  test "read? returns true when read_at is present" do
    notification = @user.notifications.create!(
      notification_type: "request_completed",
      title: "Test"
    )
    assert_not notification.read?

    notification.update!(read_at: Time.current)
    assert notification.read?
  end

  test "mark_as_read! sets read_at" do
    notification = @user.notifications.create!(
      notification_type: "request_completed",
      title: "Test"
    )
    assert_nil notification.read_at

    notification.mark_as_read!
    assert_not_nil notification.read_at
  end

  test "mark_as_read! does nothing if already read" do
    original_time = 1.hour.ago
    notification = @user.notifications.create!(
      notification_type: "request_completed",
      title: "Test",
      read_at: original_time
    )

    notification.mark_as_read!
    assert_in_delta original_time, notification.read_at, 1.second
  end

  test "mark_all_read! marks all user notifications as read" do
    3.times do
      @user.notifications.create!(notification_type: "request_completed", title: "Test")
    end

    assert_equal 3, @user.notifications.unread.count

    Notification.mark_all_read!(@user)

    assert_equal 0, @user.notifications.unread.count
  end
end

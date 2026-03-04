# frozen_string_literal: true

require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get notifications_path
    assert_response :redirect
  end

  test "index shows notifications" do
    notification = @user.notifications.create!(
      notification_type: "request_completed",
      title: "Book Ready",
      message: "Test book is ready"
    )

    get notifications_path
    assert_response :success
    assert_select "h1", "Notifications"
    assert_select "h3", "Book Ready"
  end

  test "index shows empty state" do
    @user.notifications.destroy_all

    get notifications_path
    assert_response :success
    assert_select "h3", "No notifications"
  end

  test "mark_read marks notification as read" do
    notification = @user.notifications.create!(
      notification_type: "request_completed",
      title: "Book Ready",
      message: "Test book is ready"
    )

    assert_nil notification.read_at

    post mark_read_notification_path(notification)
    assert_response :redirect

    assert_not_nil notification.reload.read_at
  end

  test "mark_all_read marks all notifications as read" do
    3.times do |i|
      @user.notifications.create!(
        notification_type: "request_completed",
        title: "Notification #{i}",
        message: "Test message"
      )
    end

    assert_equal 3, @user.notifications.unread.count

    post mark_all_read_notifications_path
    assert_redirected_to notifications_path

    assert_equal 0, @user.notifications.unread.count
  end

  test "cannot mark other user's notification as read" do
    other_user = users(:two)
    notification = other_user.notifications.create!(
      notification_type: "request_completed",
      title: "Other User's Notification",
      message: "Test message"
    )

    post mark_read_notification_path(notification)
    assert_response :not_found
  end
end

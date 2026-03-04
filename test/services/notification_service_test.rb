# frozen_string_literal: true

require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @request = requests(:pending_request)
  end

  test "request_completed creates notification" do
    assert_difference "Notification.count", 1 do
      NotificationService.request_completed(@request)
    end

    notification = Notification.last
    assert_equal @user, notification.user
    assert_equal @request, notification.notifiable
    assert_equal "request_completed", notification.notification_type
    assert_equal "Book Ready", notification.title
    assert_includes notification.message, @request.book.title
  end

  test "request_failed creates notification" do
    assert_difference "Notification.count", 1 do
      NotificationService.request_failed(@request)
    end

    notification = Notification.last
    assert_equal "request_failed", notification.notification_type
    assert_equal "Request Failed", notification.title
  end

  test "request_attention creates notification" do
    assert_difference "Notification.count", 1 do
      NotificationService.request_attention(@request)
    end

    notification = Notification.last
    assert_equal "request_attention", notification.notification_type
    assert_equal "Attention Needed", notification.title
  end
end

# frozen_string_literal: true

class NotificationService
  class << self
    def request_completed(request)
      create_for_user(
        user: request.user,
        notifiable: request,
        type: "request_completed",
        title: "Book Ready",
        message: "\"#{request.book.title}\" is now available for download."
      )
    end

    def request_failed(request)
      create_for_user(
        user: request.user,
        notifiable: request,
        type: "request_failed",
        title: "Request Failed",
        message: "\"#{request.book.title}\" could not be downloaded."
      )
    end

    def request_attention(request)
      create_for_user(
        user: request.user,
        notifiable: request,
        type: "request_attention",
        title: "Attention Needed",
        message: "\"#{request.book.title}\" needs your attention."
      )
    end

    private

    def create_for_user(user:, notifiable:, type:, title:, message:)
      user.notifications.create!(
        notifiable: notifiable,
        notification_type: type,
        title: title,
        message: message
      )
    rescue => e
      Rails.logger.error "[NotificationService] Failed to create notification: #{e.message}"
      nil
    end
  end
end

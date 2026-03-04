# frozen_string_literal: true

class ActivityTracker
  class << self
    def track(action, trackable: nil, user: Current.user, details: {})
      ActivityLog.track(
        action: action,
        user: user,
        trackable: trackable,
        details: details,
        ip_address: Current.session&.ip_address
      )
    end
  end
end

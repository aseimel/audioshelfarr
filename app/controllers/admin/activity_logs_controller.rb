# frozen_string_literal: true

module Admin
  class ActivityLogsController < BaseController
    def index
      @logs = ActivityLog.recent.includes(:user, :trackable)
      @logs = @logs.by_user(params[:user_id]) if params[:user_id].present?
      @logs = @logs.for_action(params[:action_filter]) if params[:action_filter].present?
      @logs = @logs.where("created_at >= ?", params[:from]) if params[:from].present?
      @logs = @logs.limit(100)

      @users = User.order(:name)
      @actions = ActivityLog.distinct.pluck(:action).sort
    end
  end
end

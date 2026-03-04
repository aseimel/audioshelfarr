# frozen_string_literal: true

module UploadsHelper
  def render_upload_status(upload)
    case upload.status
    when "pending"
      content_tag(:span, "Pending",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800")
    when "processing"
      content_tag(:span, "Processing...",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800")
    when "completed"
      content_tag(:span, "Completed",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800")
    when "failed"
      content_tag(:span, "Failed",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800")
    end
  end
end

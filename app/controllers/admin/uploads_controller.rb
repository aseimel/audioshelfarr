# frozen_string_literal: true

module Admin
  class UploadsController < BaseController
    before_action :set_upload, only: [:show, :destroy, :retry]

    def index
      @uploads = Upload.includes(:user, :book).recent
    end

    def new
      @upload = Upload.new
    end

    def create
      uploaded_file = params[:file]

      unless uploaded_file
        redirect_to new_admin_upload_path, alert: "Please select a file to upload"
        return
      end

      # Validate file extension
      extension = File.extname(uploaded_file.original_filename).delete(".").downcase
      unless Upload::SUPPORTED_EXTENSIONS.include?(extension)
        redirect_to new_admin_upload_path,
          alert: "Unsupported file type. Supported: #{Upload::SUPPORTED_EXTENSIONS.join(', ')}"
        return
      end

      # Save uploaded file to temp location
      temp_path = save_uploaded_file(uploaded_file)

      # Create upload record
      @upload = Upload.new(
        user: Current.user,
        original_filename: uploaded_file.original_filename,
        file_path: temp_path,
        file_size: uploaded_file.size,
        content_type: uploaded_file.content_type,
        status: :pending
      )

      if @upload.save
        # Queue processing job
        UploadProcessingJob.perform_later(@upload.id)
        redirect_to admin_uploads_path, notice: "File uploaded successfully. Processing started."
      else
        FileUtils.rm_f(temp_path) # Clean up
        redirect_to new_admin_upload_path, alert: @upload.errors.full_messages.join(", ")
      end
    end

    def show
    end

    def destroy
      # Clean up file if still exists and not completed
      if @upload.file_path.present? && File.exist?(@upload.file_path) && !@upload.completed?
        FileUtils.rm_f(@upload.file_path)
      end

      @upload.destroy
      redirect_to admin_uploads_path, notice: "Upload deleted."
    end

    def retry
      unless @upload.failed?
        redirect_to admin_uploads_path, alert: "Can only retry failed uploads"
        return
      end

      @upload.update!(status: :pending, error_message: nil)
      UploadProcessingJob.perform_later(@upload.id)

      redirect_to admin_uploads_path, notice: "Upload queued for retry."
    end

    private

    def set_upload
      @upload = Upload.find(params[:id])
    end

    def save_uploaded_file(uploaded_file)
      upload_dir = Rails.root.join("tmp", "uploads")
      FileUtils.mkdir_p(upload_dir)

      # Generate unique filename
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      random = SecureRandom.hex(4)
      extension = File.extname(uploaded_file.original_filename)
      filename = "#{timestamp}_#{random}#{extension}"

      path = upload_dir.join(filename)

      File.open(path, "wb") do |file|
        file.write(uploaded_file.read)
      end

      path.to_s
    end
  end
end

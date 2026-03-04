# frozen_string_literal: true

class DownloadJob < ApplicationJob
  queue_as :default

  def perform(download_id)
    download = Download.find_by(id: download_id)
    return unless download
    return unless download.queued?

    Rails.logger.info "[DownloadJob] Starting download ##{download.id} for request ##{download.request.id}"

    search_result = download.request.search_results.selected.first

    unless search_result
      Rails.logger.error "[DownloadJob] No selected search result for download ##{download.id}"
      download.update!(status: :failed)
      download.request.mark_for_attention!("No search result selected for download")
      return
    end

    begin
      handle_standard_download(download, search_result)
    rescue DownloadClientSelector::NoClientAvailableError => e
      Rails.logger.error "[DownloadJob] No download client available: #{e.message}"
      download.update!(status: :failed)
      download.request.mark_for_attention!(e.message)
    rescue DownloadClients::Base::AuthenticationError => e
      Rails.logger.error "[DownloadJob] Download client authentication failed: #{e.message}"
      download.update!(status: :failed)
      download.request.mark_for_attention!("Download client authentication failed. Please check credentials.")
    rescue DownloadClients::Base::ConnectionError => e
      Rails.logger.error "[DownloadJob] Download client connection error: #{e.message}"
      download.update!(status: :failed)
      download.request.mark_for_attention!("Failed to connect to download client: #{e.message}")
    rescue DownloadClients::Base::Error => e
      Rails.logger.error "[DownloadJob] Download client error for download ##{download.id}: #{e.message}"
      download.update!(status: :failed)
      download.request.mark_for_attention!("Download client error: #{e.message}")
    end
  end

  private

  def handle_standard_download(download, search_result)
    unless search_result.downloadable?
      Rails.logger.error "[DownloadJob] Search result has no download link for download ##{download.id}"
      download.update!(status: :failed)
      download.request.mark_for_attention!("Selected result has no download link")
      return
    end

    # Select best available client based on download type and priority
    client_record = DownloadClientSelector.for_download(search_result)
    client = client_record.adapter
    is_usenet = search_result.usenet?

    Rails.logger.info "[DownloadJob] Using client '#{client_record.name}' for download ##{download.id}"

    download_link = search_result.download_link
    Rails.logger.info "[DownloadJob] Download link type: #{is_usenet ? 'usenet' : 'torrent'}, length: #{download_link.to_s.length} chars"
    Rails.logger.debug "[DownloadJob] Full download URL: #{download_link}"

    if is_usenet
      # SABnzbd returns a hash with nzo_ids
      result = client.add_torrent(download_link)
      external_id = result.is_a?(Hash) ? result["nzo_ids"]&.first : nil
      success = external_id.present?
    else
      # qBittorrent now returns the torrent hash directly
      external_id = client.add_torrent(download_link)
      success = external_id.present?
    end

    if success
      # Defensive check: warn if another download already has this external_id
      # This should not happen with the race condition fix, but log it if it does
      check_for_duplicate_external_id(external_id, download.id)

      download.update!(
        status: :downloading,
        download_client: client_record,
        external_id: external_id,
        download_type: is_usenet ? "usenet" : "torrent"
      )
      Rails.logger.info "[DownloadJob] Successfully added #{download.download_type} for download ##{download.id}, external_id: #{external_id}"
    else
      download.update!(status: :failed)
      download.request.mark_for_attention!("Failed to add to #{client_record.name}")
      Rails.logger.error "[DownloadJob] Failed to add download ##{download.id}"
    end
  end

  def check_for_duplicate_external_id(external_id, current_download_id)
    return if external_id.blank?

    existing = Download.where(external_id: external_id)
                       .where.not(id: current_download_id)
                       .where.not(status: :failed)
                       .first

    if existing
      Rails.logger.error "[DownloadJob] DUPLICATE EXTERNAL_ID DETECTED! " \
                         "Download ##{current_download_id} is being assigned external_id #{external_id}, " \
                         "but Download ##{existing.id} (request ##{existing.request_id}) already has this ID. " \
                         "This indicates a potential race condition that should be investigated."
    end
  end

end

require "csv"

module Admin
  class RsvpController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_rsvp, only: %i[destroy]

    def index
      @rsvps = Rsvp.includes(:user).order(created_at: :desc)
      @trusted_statuses = fetch_trusted_statuses(@rsvps)
    end

    def import
      csv_file = params[:csv_file]
      return redirect_to(admin_rsvp_path, alert: "Please choose a CSV file to import.") if csv_file.blank?

      created_count, failed_rows = import_rsvps_from_csv(csv_file)

      if failed_rows.empty?
        flash[:notice] = "Imported #{created_count} RSVP(s)."
      elsif created_count.positive?
        flash[:alert] = "Imported #{created_count} RSVP(s), but #{failed_rows.count} row(s) failed: #{failed_rows.first(5).join('; ')}"
      else
        flash[:alert] = "No RSVPs were imported. #{failed_rows.count} row(s) failed: #{failed_rows.first(5).join('; ')}"
      end

      redirect_to admin_rsvp_path
    rescue CSV::MalformedCSVError
      redirect_to admin_rsvp_path, alert: "Could not parse CSV file. Please check the format and try again."
    rescue ArgumentError => error
      redirect_to admin_rsvp_path, alert: error.message
    end

    def destroy
      @rsvp.destroy!

      flash[:notice] = "RSVP deleted"
      redirect_to admin_rsvp_path
    rescue ActiveRecord::RecordNotDestroyed => error
      flash[:alert] = "Could not delete RSVP: #{error.message}"
      redirect_to admin_rsvp_path
    end

    private

    def set_rsvp
      @rsvp = Rsvp.find(params[:id])
    end

    def import_rsvps_from_csv(csv_file)
      csv_file.rewind if csv_file.respond_to?(:rewind)
      csv = CSV.parse(csv_file.read, headers: true)
      validate_csv_headers!(csv.headers)

      created_count = 0
      failed_rows = []

      csv.each_with_index do |row, index|
        row_data = row.to_h.transform_keys { |header| normalize_csv_header(header) }
        slack_id = row_data["slack_id"].to_s.strip
        name = row_data["name"].to_s.strip
        next if slack_id.blank? && name.blank?

        rsvp = Rsvp.new(slack_id: slack_id, name: name, user: User.find_by(slack_id: slack_id))

        if rsvp.save
          created_count += 1
        else
          failed_rows << "row #{index + 2}: #{rsvp.errors.full_messages.to_sentence}"
        end
      end

      [ created_count, failed_rows ]
    end

    def validate_csv_headers!(headers)
      required_headers = %w[slack_id name]
      normalized_headers = Array(headers).map { |header| normalize_csv_header(header) }
      missing_headers = required_headers - normalized_headers
      return if missing_headers.empty?

      raise ArgumentError, "CSV must include headers: slack_id, name."
    end

    def normalize_csv_header(header)
      header.to_s.strip.downcase.delete_prefix("\uFEFF")
    end

    def fetch_trusted_statuses(rsvps)
      slack_ids = rsvps.filter_map { |rsvp| rsvp.slack_id.presence || rsvp.user&.slack_id }.uniq
      return {} if slack_ids.empty?

      slack_ids.index_with do |slack_id|
        helpers.get_trusted_status(slack_id: slack_id)
      end
    end
  end
end

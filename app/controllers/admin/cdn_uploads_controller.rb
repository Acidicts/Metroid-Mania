module Admin
  class CdnUploadsController < Admin::ApplicationController
    before_action :require_admin

    # POST /admin/cdn_upload
    # Expects multipart form-data with a file field named `file`.
    # Returns the JSON response from CdnService (e.g. { "url": "https://cdn..." }).
    def create
      if params[:file].present?
        result = CdnService.upload(params[:file])
        if result && result["url"].present?
          render json: result
        else
          render json: { error: "upload_failed" }, status: :unprocessable_entity
        end
      else
        render json: { error: "no_file" }, status: :bad_request
      end
    end
  end
end

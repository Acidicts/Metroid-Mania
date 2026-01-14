module Admin
  class AuditsController < ApplicationController
    before_action :require_admin

    def index
      @audits = Audit.order(created_at: :desc).limit(200)
    end
  end
end

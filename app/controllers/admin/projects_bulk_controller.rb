module Admin
  class ProjectsBulkController < Admin::ApplicationController
    before_action :require_admin

    # POST /admin/projects/bulk_update
    def create
      project_ids = Array(params[:project_ids]).map(&:to_i)
      new_status = params[:bulk_status].presence
      credits = params[:bulk_credits].presence

      projects = Project.where(id: project_ids)

      projects.each do |p|
        previous_status = p.status
        previous_credits = p.credits_per_hour

        # Per-project override fields from the form
        per_status = params["status_for_#{p.id}"].presence || new_status
        per_credits = params["credits_for_#{p.id}"].presence || credits

        if per_status.present?
          if per_status == 'approved'
            p.update!(status: 'approved', approved_at: Time.current, shipped: false, credits_per_hour: per_credits)

            # award credits if provided — record them on a Ship so awarded credits are bound to the ship snapshot
            if per_credits.present?
              p.ship_and_award_credits!(admin_user: current_user, rate: per_credits, devlogged_seconds: p.total_seconds.to_i, shipped_at: Time.current)
            end
          else
            p.update!(status: per_status, approved_at: nil, shipped: false, credits_per_hour: per_credits)
          end

          Audit.create!(user: current_user, project: p, action: 'bulk_set_status', details: { previous_status: previous_status, new_status: per_status, previous_credits: previous_credits, credits_per_hour: per_credits })
        elsif per_credits.present?
          p.update!(credits_per_hour: per_credits)
          # award immediately if project is already approved (record on a Ship)
          if p.status == 'approved'
            p.ship_and_award_credits!(admin_user: current_user, rate: per_credits, devlogged_seconds: p.total_seconds.to_i, shipped_at: Time.current)
          end
          Audit.create!(user: current_user, project: p, action: 'bulk_set_credits', details: { previous_credits: previous_credits, credits_per_hour: per_credits })
        end
      end

      redirect_back fallback_location: admin_projects_path, notice: "Bulk update applied to #{projects.size} projects."
    end
  end
end

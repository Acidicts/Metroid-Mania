class GoalsController < ApplicationController
  before_action :require_admin, only: %i[award force_award]

  def index
    @week_start  = WeeklyGoalService.week_start
    @week_end    = WeeklyGoalService.week_end
    @week_total  = Devlog.total_duration_seconds(@week_start..Time.current)
    @threshold   = WeeklyGoalService.threshold
    @percentage  = if @threshold > 0
                     [ (@week_total.to_f / @threshold * 100).round, 100 ].min
    else
                     0
    end
    @last_awarded_at = WeeklyGoalService.last_awarded_at
  end

  # POST /goals/award
  def award
    order = WeeklyGoalService.check_and_award!
    if order
      flash_pass("Weekly goal prize issued (order ##{order.id}).")
    else
      flash_info("No prize was created.")
    end
    redirect_to goals_path
  end

  # POST /goals/force_award
  # forcibly pick a random eligible contributor, ignoring thresholds and
  # prior awards.  Useful for admins when the automated process fails.
  def force_award
    order = WeeklyGoalService.force_award!
    if order
      flash_pass("Weekly goal prize forcibly issued (order ##{order.id}).")
    else
      flash_warn("No eligible contributor to receive a prize.")
    end
    redirect_to goals_path
  end

  def edit; end
  def new; end

  def issue
    @goal = Goal.find(params[:id])
  end
end

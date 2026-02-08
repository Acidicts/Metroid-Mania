module Admin
  class DashboardController < Admin::ApplicationController
    before_action :require_admin

    def index
      @projects_count = Project.active.count
      @projects_pending_count = Project.where(status: 'pending').where(deleted_at: nil).count
      @orders_count = Order.count
      @users_count = User.where.not(name: "Deleted User").count
      @ships_count = Ship.where.not(user: User.where(name: "Deleted User")).count
      @orders_pending_count = Order.where(status: '0').count
      @orders_denied_count = Order.where(status: '1').count
      @orders_fulfilled_count = Order.where(status: '2').count

      # pending ship requests for quick admin access (exclude those for deleted projects)
      @ship_requests_pending_count = ShipRequest.joins(:project).where(status: 'pending').where(projects: { deleted_at: nil }).count
    end
  end
end

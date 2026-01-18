module Admin
  class DashboardController < ApplicationController
    before_action :require_admin

    def index
      @projects_count = Project.count
      @projects_pending_count = Project.where(status: 'pending').count
      @orders_count = Order.count
      @users_count = User.count
      @ships_count = Project.where(status: ['pending', 'shipped']).count
      @orders_pending_count = Order.where(status: '0').count
      @orders_denied_count = Order.where(status: '1').count
      @orders_fulfilled_count = Order.where(status: '2').count
    end
  end
end

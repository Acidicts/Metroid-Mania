module Admin
  class DashboardController < ApplicationController
    before_action :require_admin

    def index
      @pending_projects = Project.where(status: 'pending')
      @orders_count = Order.count
      @users_count = User.count
      @shippable_projects = Project.where(status: ['unshipped', 'shipped'])
    end
  end
end

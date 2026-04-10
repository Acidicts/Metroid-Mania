class GalleryController < ApplicationController
  def index
    @projects = Project.where.not(name: "Deleted Project").order_by_total_devlogged_seconds.limit(12)
  end
end

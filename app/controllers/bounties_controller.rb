class BountiesController < ApplicationController
  def index
    @bounties = Bounty.includes(:type, :project).order(created_at: :desc)
  end

  def show
    @bounty = Bounty.find(params[:id])
  end

  def new
    @bounty = Bounty.new
  end

  def edit
    @bounty = Bounty.find(params[:id])
  end
end

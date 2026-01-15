class SharedController < ApplicationController
  # Render shared/demo partials for local previewing (development & test only)
  before_action :restrict_to_dev_and_test

  def _retro_sample
    render template: 'shared/retro_sample', layout: 'application'
  end

  private

  def restrict_to_dev_and_test
    head :not_found unless Rails.env.development? || Rails.env.test?
  end
end

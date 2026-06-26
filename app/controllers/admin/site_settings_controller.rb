module Admin
  class SiteSettingsController < Admin::ApplicationController
    before_action :require_admin

    def index
      # load the individual settings so the form helpers can infer the
      # current values. They are not persisted unless the admin clicks save
      # (SiteSetting.enabled? will fall back to a sensible default otherwise).
      @shop = SiteSetting.find_or_initialize_by(key: "shop")
      @running = SiteSetting.find_or_initialize_by(key: "running")
      @disable_non_admin_logins = SiteSetting.find_or_initialize_by(key: "disable_non_admin_logins")
      @disable_asset_project   = SiteSetting.find_or_initialize_by(key: "disable_asset_project")
      @disable_community_goals = SiteSetting.find_or_initialize_by(key: "disable_community_goals")
      @not_running_message = SiteSetting.find_by(key: "not_running_message")&.value

      # configuration for the weekly devlog goal giveaway
      @weekly_threshold = SiteSetting.find_or_initialize_by(key: "weekly_goal_threshold_seconds")
    end

    def update
      # The form sends checkbox values as "1" when checked and omits them
      # otherwise. Iterate the keys we care about to keep the controller
      # easy to extend in future.
      # boolean toggles are still handled the same way
      %w[shop running disable_non_admin_logins disable_asset_project disable_community_goals].each do |key|
        enabled = params.dig(:site_setting, key) == "1"
        SiteSetting.set(key, enabled ? "true" : "false")
      end

      # allow arbitrary values for our new settings (text fields)
      %w[weekly_goal_threshold_seconds not_running_message].each do |key|
        if params.dig(:site_setting, key)
          SiteSetting.set(key, params.dig(:site_setting, key))
        end
      end

      flash_pass("Site settings updated")
      redirect_to admin_site_settings_path
    end
  end
end

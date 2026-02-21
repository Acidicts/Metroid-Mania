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
    end

    def update
      # The form sends checkbox values as "1" when checked and omits them
      # otherwise. Iterate the keys we care about to keep the controller
      # easy to extend in future.
      %w[shop running disable_non_admin_logins].each do |key|
        enabled = params.dig(:site_setting, key) == "1"
        SiteSetting.set(key, enabled ? "true" : "false")
      end

      flash_pass("Site settings updated")
      redirect_to admin_site_settings_path
    end
  end
end

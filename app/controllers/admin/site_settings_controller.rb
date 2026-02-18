module Admin
  class SiteSettingsController < Admin::ApplicationController
    before_action :require_admin

    def index
      @shop = SiteSetting.find_or_initialize_by(key: "shop")
    end

    def update
      @shop = SiteSetting.find_or_initialize_by(key: "shop")
      enabled = params.dig(:site_setting, :enabled) == "1"
      @shop.update!(value: enabled ? "true" : "false")
      flash_pass("Site settings updated")
      redirect_to admin_site_settings_path
    end
  end
end

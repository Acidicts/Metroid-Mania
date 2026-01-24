class HomeController < ApplicationController
  def index
    # Load orgs from Slack IDs configured in config/initializers/orgs.rb (ENV: ORG_SLACK_IDS)
    if defined?(ORG_SLACK_IDS) && ORG_SLACK_IDS.any?
      @orgs = SlackService.new.users_info(ORG_SLACK_IDS)

      # If ORG_TITLES is provided in the env, map each title to the corresponding org by index
      if defined?(ORG_TITLES) && ORG_TITLES.any?
        @orgs.each_with_index do |org, idx|
          title = ORG_TITLES[idx]
          org[:title] = title if title.present?
        end
      end
    else
      @orgs = []
    end
  end
end

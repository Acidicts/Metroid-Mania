# org Slack IDs used on the home page for "organizers" or organizations.
# Provide via ENV to avoid committing IDs. Example:
#   ORG_SLACK_IDS=U12345,U67890
# Default to the two IDs you provided if ENV isn't set
ORG_SLACK_IDS = ENV.fetch('ORG_SLACK_IDS', '').split(',').map(&:strip).reject(&:empty?)
# Keep positions for titles so mapping by index works; empty entries are allowed
ORG_TITLES = ENV.fetch('ORG_TITLES', '').split(',').map { |s| s.strip.presence }

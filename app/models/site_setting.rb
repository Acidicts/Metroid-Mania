# == Schema Information
#
# Table name: site_settings
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  key        :string           not null
#  updated_at :datetime         not null
#  value      :string
#
# Indexes
#  index_site_settings_on_key  (key) UNIQUE
#
class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  after_commit :expire_cache

  def self.get(key, default = nil)
    Rails.cache.fetch([ "site_setting", key.to_s ]) { find_by(key: key)&.value || default }
  end

  def self.enabled?(key, default: true)
    v = get(key)
    return default if v.nil?
    %w[1 true yes on].include?(v.to_s.downcase)
  end

  def self.set(key, value)
    r = find_or_initialize_by(key: key.to_s)
    r.value = value.to_s
    r.save!
    Rails.cache.delete([ "site_setting", key.to_s ])
    r
  end

  private

  def expire_cache
    Rails.cache.delete([ "site_setting", key.to_s ])
  end
end

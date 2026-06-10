# == Schema Information
#
# Table name: assets_projects
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  description     :text
#  hackatime_ids   :text
#  image_url       :string
#  media_type      :string
#  readme_url      :string
#  repository_url  :string
#  shipped         :boolean
#  title           :string
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#
# Indexes
#  index_assets_projects_on_user_id  (user_id)
#
class AssetsProject < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :description, presence: true
  validates :media_type, presence: true

  validates :image_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # association uses the current column name; explicit foreign_key is no
  # longer required but left here for clarity.
  has_many :assets_items, dependent: :destroy, foreign_key: :assets_project_id

  # Predicate for image presence (CDN-based)
  def image_url?
    image_url.present?
  end

  # Store multiple Hackatime project names as YAML (mirrors Project#hackatime_ids).
  def hackatime_ids
    raw = read_attribute(:hackatime_ids)
    return [] if raw.blank?
    parsed = YAML.safe_load(raw)
    parsed.is_a?(Array) ? parsed.map(&:to_s) : []
  rescue
    []
  end

  def hackatime_ids=(vals)
    write_attribute(:hackatime_ids, vals.present? ? vals.to_yaml : nil)
  end

  # --- GitHub / repository helpers (subset copied from Project) -----------

  # Parse GitHub owner/repo (and optional branch) from repository_url.
  # Returns a hash { owner:, repo:, branch: } or nil when the URL doesn't look like GitHub.
  def github_repo_parts
    return nil if repository_url.blank?
    m = repository_url.match(/(?:github\.com[:\/])([^\/\s@]+)\/([^\/\s@]+)(?:\.git)?(?:[\/\#?].*)?/i)
    return nil unless m
    owner = m[1]
    repo_name = m[2].gsub(/\.git$/i, "")
    branch_match = repository_url.match(/\/(?:tree|blob)\/([^\/\s\/]+)/i)
    { owner: owner, repo: repo_name, branch: (branch_match ? branch_match[1] : nil) }
  end

  # Return true when a README.md is reachable either via explicit readme_url or
  # by checking the repository's README on GitHub (tries branch if present,
  # otherwise main/master). Results are cached briefly.
  def github_readme_present?
    return true if readme_url.present?
    parts = github_repo_parts
    return false unless parts

    branches = parts[:branch] ? [ parts[:branch] ] : [ "main", "master" ]

    branches.any? do |br|
      Rails.cache.fetch("assets_project:#{id}:github_readme:#{br}", expires_in: 10.minutes) do
        uri = URI.parse("https://raw.githubusercontent.com/#{parts[:owner]}/#{parts[:repo]}/#{CGI.escape(br)}/README.md")
        begin
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3) do |http|
            req = Net::HTTP::Head.new(uri.request_uri)
            res = http.request(req) rescue nil
            res && res.is_a?(Net::HTTPSuccess)
          end
        rescue StandardError
          false
        end
      end
    end
  end

  # Heuristic: determine whether the GitHub repository is publicly reachable.
  def github_repo_public?
    parts = github_repo_parts
    return false unless parts

    Rails.cache.fetch("assets_project:#{id}:github_public", expires_in: 10.minutes) do
      uri = URI.parse("https://github.com/#{parts[:owner]}/#{parts[:repo]}")
      begin
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3) do |http|
          req = Net::HTTP::Head.new(uri.request_uri)
          res = http.request(req) rescue nil
          res && res.is_a?(Net::HTTPSuccess)
        end
      rescue StandardError
        false
      end
    end
  end

  # Determine whether the repository URL looks clonable.
  def clonable?
    return false if repository_url.blank?

    if github_repo_parts
      github_repo_public?
    else
      return true if repository_url =~ /\Agit@[^:]+:[^\/]+\/.+\.git\z/i
      return true if repository_url =~ /\Ahttps?:\/\/.+\.git\z/i
      uri = URI.parse(repository_url) rescue nil
      uri && (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS))
    end
  end
end

class AssetsItem < ApplicationRecord
  # The underlying table column is `assets_project_id`.  Earlier versions of the
  # app used `project_id`, so we retain a tiny compatibility shim in case any
  # code still references that method directly (fixtures and controller tests
  # were both written against the old column).
  belongs_to :assets_project, class_name: "AssetsProject"
  belongs_to :user

  # compatibility helpers --------------------------------------------------
  def project_id
    assets_project_id
  end

  def project_id=(val)
    self.assets_project_id = val
  end

  def project
    assets_project
  end

  def project=(val)
    self.assets_project = val
  end

  # Multiple spritesheets for different animations/frames
  has_many :spritesheets, dependent: :destroy

  # Active Storage attachment for audio files
  has_one_attached :audio

  # Validation for legacy single spritesheet URL (kept for backwards compatibility)
  validates :spritesheet_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Predicate for spritesheet presence (CDN-based)
  def spritesheet_url?
    spritesheet_url.present?
  end

  # Check if has any spritesheets (multiple or legacy)
  def has_spritesheets?
    spritesheet_url.present? || spritesheets.any?
  end
end

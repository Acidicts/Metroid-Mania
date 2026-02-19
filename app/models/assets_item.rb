class AssetsItem < ApplicationRecord
  # DB column is `project_id` (legacy scaffold). Map it to `assets_project` association.
  belongs_to :assets_project, class_name: "AssetsProject", foreign_key: :project_id
  belongs_to :user

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

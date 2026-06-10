# == Schema Information
#
# Table name: project_tags
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  project_id :integer
#  tag_string :string
#  updated_at :datetime         not null
#
# Indexes
#  index_project_tags_on_project_id  (project_id)
#
class ProjectTag < ApplicationRecord
  # A tag may optionally be scoped to a particular project; nil indicates a
  # global tag.  the `project_id` column was originally non-nullable but the
  # admin UI already hints that it is optional, so future migrations will
  # probably loosen the constraint.
  belongs_to :project, optional: true

  # Ensure tags are present and avoid duplicate entries for the same scope.
  validates :tag_string, presence: true
  validates :tag_string, uniqueness: { scope: :project_id, case_sensitive: false }

  # projects that have selected this tag via the `project_tag_id` foreign key
  has_many :tagged_projects, class_name: "Project", foreign_key: "project_tag_id"

  # the database column is `tag_string` but the UI wants to treat it as
  # a simple "tag" attribute.  expose a nicer alias so views/controllers
  # can just call `tag`/`tag=` and avoid a confusing column name.
  #
  # `alias_attribute :tag, :tag_string` creates both the reader and writer,
  # so there's no need to alias the setter separately (which actually triggers
  # an ArgumentError during initialization).  the previous second call was
  # responsible for the crash seen when rendering `new`.
  alias_attribute :tag, :tag_string

  def update_tag(tag)
    # `alias_attribute` already defines `tag=` so this helper is mostly
    # here for historical callers; it simply delegates to the writer.
    self.tag = tag
    save
  end
end

class Bounty < ApplicationRecord
  belongs_to :type
  belongs_to :project
end

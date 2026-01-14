class User < ApplicationRecord
  has_many :projects
  has_many :orders

  enum :role, { user: 0, admin: 1 }

  # Allow optional password for OAuth users. Use has_secure_password without validations
  # and manage presence checks if needed elsewhere.
  has_secure_password validations: false

  has_many :audits, dependent: :nullify

  validates :uid, presence: true, uniqueness: true
  validates :provider, presence: true

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.name = auth.info.name
      user.email = auth.info.email
      user.slack_id = auth.info.slack_id
      user.verification_status = auth.info.verification_status
      # Set admin role if the auth provider says so (and we trust it)
      # user.role = :admin if auth.info.admin
      user.role ||= :user # Default role
    end
  end

  # Is this user the superadmin defined by environment?
  def superadmin?
    env_uid = ENV['SUPERADMIN_UID']
    env_email = ENV['SUPERADMIN_EMAIL']&.downcase
    (env_uid.present? && uid == env_uid) || (env_email.present? && email&.downcase == env_email)
  end
end

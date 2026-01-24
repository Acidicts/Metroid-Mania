class User < ApplicationRecord
  # When a user is deleted we nullify references and reassign them to the system user
  has_many :projects, dependent: :nullify
  has_many :orders, dependent: :nullify
  has_many :ships, dependent: :nullify
  has_many :ship_requests, dependent: :nullify

  enum :role, { user: 0, admin: 1 }

  # Scope to exclude the system placeholder user
  scope :not_system, -> { where.not(provider: 'system', uid: 'deleted_user') }

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

  # Display name for the user (falls back to email or name)
  def display_name
    name.presence || email.presence || "User #{id}"
  end

  # System placeholder user used to own records of deleted users. Created lazily.
  def self.system_user
    find_or_create_by!(provider: 'system', uid: 'deleted_user') do |u|
      u.email = 'deleted@example.com'
      u.name = 'Deleted User'
      u.password = SecureRandom.hex(16)
      u.role = :user
    end
  end

  def system_user?
    provider == 'system' && uid == 'deleted_user'
  end

  before_destroy do
    if system_user?
      # Prevent accidental removal of the placeholder
      throw(:abort)
    end
  end

  # Reassign direct children to the system user before destruction so they are not destroyed
  # by dependent callbacks or left NULL. This ensures records always have an owner.
  def destroy
    return false if system_user?

    sys = User.system_user
    Project.where(user_id: id).update_all(user_id: sys.id)
    Order.where(user_id: id).update_all(user_id: sys.id)
    Ship.where(user_id: id).update_all(user_id: sys.id)
    ShipRequest.where(user_id: id).update_all(user_id: sys.id)
    ShipRequest.where(processed_by_id: id).update_all(processed_by_id: sys.id)
    Audit.where(user_id: id).update_all(user_id: sys.id)

    super
  end

  private
end

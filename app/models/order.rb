class Order < ApplicationRecord
  belongs_to :user
  belongs_to :product
  
  before_create :set_cost_and_deduct_balance
  
  validate :user_has_enough_currency, on: :create
  # Prevent duplicate pending orders at model level (best-effort; DB unique index is authoritative)
  validates :product_id, uniqueness: { scope: :user_id, message: 'already has a pending order' }, if: -> { status == 'pending' } 
  
  enum :status, { pending: 'pending', unshipped: 'unshipped', shipped: 'shipped', denied: 'denied' }

  private
  
  def set_cost_and_deduct_balance
    self.cost = product.price_currency
    self.status = 'pending'
    user.update!(currency: user.currency - self.cost)
  end
  
  def user_has_enough_currency
    if user.currency < product.price_currency
      errors.add(:base, "Insufficient funds")
    end
  end
end

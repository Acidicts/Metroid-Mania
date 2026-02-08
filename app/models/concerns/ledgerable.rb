module Ledgerable
  extend ActiveSupport::Concern

  included do
    # Subclasses should define their own ledger entry associations if needed
    # e.g., has_many :ledger_entries, as: :ledgerable
  end

  def payout_eligible?
    return false unless respond_to?(:certification_status) && certification_status == "approved"
    return false if payout.present? && payout > 0
    return false if respond_to?(:votes_count) && votes_count < Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT
    true
  end
end

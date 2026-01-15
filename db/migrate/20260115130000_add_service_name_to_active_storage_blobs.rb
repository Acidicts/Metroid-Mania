class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def change
    # Active Storage expects a `service_name` column on blobs in modern Rails versions
    unless column_exists?(:active_storage_blobs, :service_name)
      add_column :active_storage_blobs, :service_name, :string
    end
  end
end

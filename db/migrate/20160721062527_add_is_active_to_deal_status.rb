class AddIsActiveToDealStatus < ActiveRecord::Migration
  def change
    add_column :deal_statuses, :is_active, :boolean, :default => true, :null => false
  end
end

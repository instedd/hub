class AddUserIdToEventHandler < ActiveRecord::Migration
  def change
    add_column :event_handlers, :user_id, :integer
  end
end

class AddNameToEventHandlers < ActiveRecord::Migration
  def change
    add_column :event_handlers, :name, :string
  end
end

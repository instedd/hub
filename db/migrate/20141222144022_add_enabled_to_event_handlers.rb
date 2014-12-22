class AddEnabledToEventHandlers < ActiveRecord::Migration
  def change
    add_column :event_handlers, :enabled, :boolean, default: true
  end
end

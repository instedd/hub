class AddTargetActionToEventHandlers < ActiveRecord::Migration
  def change
    add_reference :event_handlers, :target_connector, index: true
    add_column :event_handlers, :action, :string
    add_column :event_handlers, :binding, :text
  end
end

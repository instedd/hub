class RenameEventSubscriptionToEventHandler < ActiveRecord::Migration
  def change
    rename_table :event_subscriptions, :event_handlers
  end
end

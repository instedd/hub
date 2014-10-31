class CreateEventSubscriptions < ActiveRecord::Migration
  def change
    create_table :event_subscriptions do |t|
      t.references :connector, index: true
      t.string :event
      t.boolean :poll

      t.timestamps
    end
  end
end

class EventSubscription < ActiveRecord::Base
  belongs_to :connector

  def self.run_poll_subscriptions
    subscriptions = EventSubscription.where(poll: true).includes(:connector).all
    subscriptions.group_by {|s| [s.connector, s.event]}.each do |(connector, event), subscription|
      connector.lookup_path(event).poll
    end
  end
end

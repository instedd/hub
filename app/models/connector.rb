class Connector < ActiveRecord::Base
  belongs_to :user
  has_many :event_subscriptions

  validates_presence_of :name

  def connector
    self
  end

  def lookup_path(path)
    lookup path.to_s.split('/')
  end

  module PollJob
    def self.perform(connector_id)
      connector = Connector.find(connector_id)
      subscriptions = connector.event_subscriptions.where(poll: true).group_by(&:event)

      subscriptions.each do |event_path, subs|
        event_data = connector.lookup_path(event_path).poll
        # TODO: trigger events with event data
      end
    end
  end
end

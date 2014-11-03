class Connector < ActiveRecord::Base
  belongs_to :user
  has_many :event_handlers

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
      handlers_by_event = connector.event_handlers.where(poll: true).group_by(&:event)

      handlers_by_event.each do |event_path, handlers|
        event_data = connector.lookup_path(event_path).poll
        # TODO: trigger events with event data
      end
    end
  end
end

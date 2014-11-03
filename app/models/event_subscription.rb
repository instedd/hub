class EventSubscription < ActiveRecord::Base
  belongs_to :connector

  module QueuePollJob
    def self.perform
      connector_ids = EventSubscription.where(poll: true).distinct.pluck(:connector_id)
      connector_ids.each do |connector_id|
        Resque.enqueue_to(:hub, Connector::PollJob, connector_id)
      end
    end
  end
end

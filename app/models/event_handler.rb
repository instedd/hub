class EventHandler < ActiveRecord::Base
  belongs_to :connector
  belongs_to :user
  belongs_to :target_connector, class_name: 'Connector', foreign_key: 'target_connector_id'
  serialize :binding

  module QueuePollJob
    def self.perform
      connector_ids = EventHandler.where(poll: true).distinct.pluck(:connector_id)
      connector_ids.each do |connector_id|
        Resque.enqueue_to(:hub, Connector::PollJob, connector_id)
      end
    end
  end

  def trigger(data)
    target_action = target_connector.lookup_path(action, user)
    target_action.invoke bind_event_data(data), user
  end

  private

  def bind_event_data(data)
    @mapper ||= JsonMapper.new(binding || [])
    @mapper.map data
  end
end

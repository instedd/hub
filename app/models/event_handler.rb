class EventHandler < ActiveRecord::Base
  belongs_to :connector
  belongs_to :user
  belongs_to :target_connector, class_name: 'Connector', foreign_key: 'target_connector_id'
  serialize :binding

  after_create :notify_action_created
  after_update :notify_action_updated
  after_destroy :notify_event_unsubscribe

  module QueuePollJob
    def self.perform
      connector_ids = EventHandler.where(poll: true).distinct.pluck(:connector_id)
      connector_ids.each do |connector_id|
        Resque.enqueue_to(:hub, Connector::PollJob, connector_id)
      end
    end
  end

  def trigger(data)
    begin
      context = RequestContext.new(user)
      target_action = target_connector.lookup_path(action, context)
      PoirotRails::Activity.start("Action invoked", target_action: target_action.path, data: data) do
        target_action.invoke bind_event_data(data), context
      end
    rescue Exception => e
      logger.error "Error triggering event handler: #{e}"
    end
  end

  private

  def bind_event_data(data)
    @mapper ||= JsonMapper.new(binding || [])
    @mapper.map data
  end

  def notify_action_created
    target_action = target_connector.lookup_path(action, RequestContext.new(user))
    if target_action.respond_to?(:after_create)
      target_action.after_create(self.binding)
    end
  end

  def notify_action_updated
    target_action = target_connector.lookup_path(action, RequestContext.new(user))
    if target_action.respond_to?(:after_update)
      target_action.after_update(self.binding)
    end
  end

  def notify_event_unsubscribe
    context = RequestContext.new(user)
    source_event = connector.lookup_path(event, context)
    source_event.unsubscribe(context)
  end
end

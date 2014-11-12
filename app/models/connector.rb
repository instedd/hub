class Connector < ActiveRecord::Base
  belongs_to :user
  has_many :event_handlers

  validates_presence_of :name
  validates_presence_of :guid

  before_validation :generate_guid

  def generate_guid
    self.guid ||= Guid.new.to_s
  end

  def connector
    self
  end

  def lookup_path(path, current_user)
    lookup path.to_s.split('/'), current_user
  end

  def self.with_optional_user(user)
    where('user_id = ? OR user_id is null', user.id)
  end

  def shared?
    user.nil?
  end

  module PollJob
    def self.perform(connector_id)
      connector = Connector.find(connector_id)
      handlers_by_event = connector.event_handlers.where(poll: true).group_by do |handler|
        [handler.event, handler.user]
      end

      handlers_by_event.each do |event_user_pair, handlers|
        events = connector.lookup_path(event_user_pair.first, event_user_pair.last).poll
        events.each do |event|
          handlers.each do |handler|
            handler.trigger event
          end
        end
      end
    end
  end
end

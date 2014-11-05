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

  def lookup_path(path)
    lookup path.to_s.split('/')
  end

  def self.with_optional_user(user)
    where('user_id = ? OR user_id is null', user.id)
  end

  module PollJob
    def self.perform(connector_id)
      connector = Connector.find(connector_id)
      handlers_by_event = connector.event_handlers.where(poll: true).group_by(&:event)

      handlers_by_event.each do |event_path, handlers|
        event_data = connector.lookup_path(event_path).poll
        handlers.product(event_data) do |handler, data|
          handler.trigger data
        end
      end
    end
  end
end

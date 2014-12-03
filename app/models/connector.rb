class Connector < ActiveRecord::Base
  belongs_to :user
  has_many :event_handlers

  validates_presence_of :name
  validates_presence_of :guid

  def label
    name
  end

  before_validation :generate_guid

  default_scope { order('user_id desc, name') } # order first shared connectors and then by name

  abstract :url

  abstract def lookup(path, user)
  end

  store :settings

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

  def self.shared
    where('user_id is null')
  end

  def shared?
    user.nil?
  end

  def pollable?
    !self.event_handlers.where(poll: true).empty?
  end

  def needs_authorization?
    false
  end

  def has_notifiable_events?
    false
  end

  def generate_secret_token!
    token = Guid.new.to_s
    self.secret_token = BCrypt::Password.create(token)

    save!

    token
  end

  def authenticate_with_secret_token(token)
    BCrypt::Password.new(self.secret_token) == token
  end

  module PollJob
    def self.perform(connector_id)
      PoirotRails::Activity.start("Poll", connector_id: connector_id) do
        connector = Connector.find(connector_id)
        handlers_by_event = connector.event_handlers.where(poll: true).group_by do |handler|
          [handler.event, handler.user]
        end

        handlers_by_event.each do |event_user_pair, handlers|
          events = connector.lookup_path(event_user_pair.first, event_user_pair.last).poll
          events.each do |event|
            handlers.each do |handler|
              PoirotRails::Activity.start("polling_event", event: event, handler_id: handler.id, user_id: handler.user_id, connector_id: connector_id, handled_event: handler.event, url: connector.url) do
                handler.trigger event
              end
            end
          end
        end
      end
    end
  end
end

class Connector < ActiveRecord::Base
  belongs_to :user
  has_many :event_handlers

  validates_presence_of :name
  validates_presence_of :guid

  def human_type
    type.to_s[0 .. -10].underscore.humanize.titleize
  end

  def label
    name
  end

  def has_events?
    true
  end

  def has_actions?
    true
  end

  before_validation :generate_guid

  default_scope { order('user_id desc, name') } # order first shared connectors and then by name

  abstract :url

  abstract def lookup(path, context)
  end

  abstract def callback(context, path, request)
  end

  store :settings

  def generate_guid
    self.guid ||= Guid.new.to_s
  end

  def connector
    self
  end

  def lookup_path(path, context)
    lookup path.to_s.split('/'), context
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

  module NotifyJob
    def self.perform(connector_id, path, body)
      connector = Connector.find(connector_id)
      body = JSON.parse body
      subscribed_events = connector.event_handlers.where(event: path, enabled: true)
      subscribed_events.each do |event_handler|
        event_handler.trigger(body)
      end
    end
  end

  module PollJob
    def self.perform(connector_id)
      PoirotRails::Activity.start("Poll", connector_id: connector_id) do
        connector = Connector.find(connector_id)
        handlers_by_event = connector.event_handlers.where(poll: true, enabled: true).group_by do |handler|
          [handler.event, handler.user]
        end

        handlers_by_event.each do |(event_path, user), handlers|
          events = connector.lookup_path(event_path, RequestContext.new(user)).poll
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

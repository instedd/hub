class RemindemConnector < Connector

  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties(context)
    {"schedules" => Schedules.new(self)}
  end

  def has_notifiable_events?
    false
  end

  private

  def initialize_defaults
    self.url = "http://remindem.instedd.org" unless self.url
  end

  class Schedules
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "schedules"
    end

    def label
      "Schedules"
    end

    def query(filters, context, options)
      { items: schedules(context.user).map{|schedule| entity(schedule)} }
    end

    def find_entity(id, context)
      Schedule.new(self, id, nil, context.user)
    end

    def entity(schedule)
      Schedule.new(self, schedule["id"], schedule["title"])
    end

    def schedules(user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/reminders.json")
    end

    def schedule(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/reminders/#{id}.json")
    end

  end

  class Schedule
    include Entity

    attr_reader :parent, :id, :user

    def initialize(parent, id, label = nil, user = nil)
      @parent = parent
      @id = id
      @label = label
      @user = user
    end

    def sub_path
      id
    end

    def label(user=nil)
      @label ||= schedule(user || self.user)["title"]
    end

    def properties(context)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name(label(context.user)),
        "subscribers" => Subscribers.new(self)
      }
    end

    def schedule(user)
      @schedule ||= parent.schedule(id, user)
    end
  end

  class Subscribers
    include EntitySet

    protocol :insert

    ENTITIY_PROPERTIES = {
      id: SimpleProperty.id,
      phone_number: SimpleProperty.string("Phone number"),
      offset: SimpleProperty.integer("Offset"),
      subscribed_at: SimpleProperty.datetime("Subscribed at")
    }.freeze

    def initialize(parent)
      @parent = parent
    end

    def label
      "Subscribers"
    end

    def path
      "#{@parent.path}/subscribers"
    end

    def entity_properties(context)
      ENTITIY_PROPERTIES
    end

    def query(filters, context, options)
      subscribers = if filters[:phone_number]
        Array.wrap(find_subscriber(filters[:phone_number], context.user))
      else
        fetch_subscribers(context.user)
      end

      {items: subscribers.map{|subscriber| Subscriber.new(self, subscriber)}}
    end

    def insert(properties, context)
      # IMPLEMENT!
      # GuissoRestClient.new(connector, context.user).
      #   post("#{connector.url}/api/projects/#{@parent.id}/contacts.json",
      #        properties_as_contact_json(properties).to_query)
    end

    def find_entity(id, context)
      Subscriber.new(self, fetch_subscriber(id, context.user))
    end

    def fetch_subscribers(user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/reminders/#{@parent.id}/subscribers.json")
    end

    def fetch_subscriber(id, user)
      begin
        GuissoRestClient.new(connector, user).get("#{connector.url}/api/reminders/#{@parent.id}/subscribers/#{id}.json")
      rescue => e
        return nil if e.http_code == 404
        raise
      end
    end

    def find_subscriber(phone_number, user)
      begin
        GuissoRestClient.new(connector, user).get("#{connector.url}/api/reminders/#{@parent.id}/subscribers/find.json?phone_number=#{phone_number}")
      rescue => e
        return nil if e.http_code == 404
        raise
      end
    end

  end

  class Subscriber
    include Entity

    attr_reader :id

    def initialize(parent, subscriber)
      @parent = parent
      @subscriber = subscriber
      @id = subscriber['id']
    end

    def label
      @subscriber['phone_number']
    end

    def sub_path
      id
    end

    def properties(context)
      properties = {
        id: SimpleProperty.id(@subscriber["id"]),
        phone_number: SimpleProperty.string("Phone number", @subscriber['phone_number']),
        offset: SimpleProperty.integer("Offset", @subscriber['offset']),
        subscribed_at: SimpleProperty.datetime("Subscribed at", @subscriber['subscribed_at'])
      }
    end
  end

end

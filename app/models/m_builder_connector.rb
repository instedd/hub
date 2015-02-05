class MBuilderConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def human_type
    "mBuilder"
  end

  def properties(context)
    {"applications" => Applications.new(self)}
  end

  def has_events?
    false
  end

  private

  def initialize_defaults
    self.url ||= "https://mbuilder.instedd.org"
  end

  class Applications
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "applications"
    end

    def label
      "Applications"
    end

    def query(filters, context, options)
      apps = GuissoRestClient.new(connector, context.user).get("#{connector.url}/api/applications")
      apps = apps.map { |app| Application.new(self, app["id"], app) }
      {items: apps}
    end

    def find_entity(id, context)
      Application.new(self, id)
    end
  end

  class Application
    include Entity
    attr_reader :id

    def initialize(parent, id, application={})
      @parent = parent
      @id = id
      @application = application
    end

    def label
      @application['name']
    end

    def sub_path
      id
    end

    def properties(context)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name('')
      }
    end

    def actions(context)
      triggers = GuissoRestClient.new(connector, context.user).get("#{connector.url}/api/applications/#{@id}/actions")
      trigger_hash = {}
      triggers.each do |trigger|
        trigger_hash["trigger_#{trigger["id"]}"]= TriggerAction.new(self, trigger["id"], trigger)
      end
      trigger_hash
    end
  end

  class TriggerAction
    include Action

    def initialize(parent, id, trigger)
      @parent = parent
      @id = id
      @trigger = trigger
    end

    def label
      "Trigger #{@trigger['action']}"
    end

    def sub_path
      "trigger_#{@id}"
    end

    def args(context)
      @trigger["parameters"]
    end

    def invoke(options, context)
      uri = URI(@trigger['url'])
      uri.query= args(context).keys.map do |arg|
          "#{arg}=#{options[arg]}"
        end.join '&'

      GuissoRestClient.new(connector, context.user).post(uri.to_s)
    end
  end
end

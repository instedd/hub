class MBuilderConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties
    {"applications" => Applications.new(self)}
  end

  def connector
    self
  end

  private

  def initialize_defaults
    self.url ||= "http://mbuilder.instedd.org"
  end

  class Applications
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "applications"
    end

    def label
      "Applications"
    end

    def entities
      @entities ||= begin
        resource = RestClient::Resource.new("#{connector.url}/api/applications", connector.username, connector.password)
        applications ||= JSON.parse(resource.get())

        applications.map { |application| Application.new(self, application["id"], application) }
      end
    end

    def reflect_entities
      entities
    end

    def find_entity(id)
      Application.new(self, id)
    end
  end

  class Application
    include Entity
    attr_reader :id
    delegate :connector, to: :@parent

    def initialize(parent, id, application=nil)
      @parent = parent
      @id = id
      @application = application
    end

    def label
      @application['name']
    end

    def properties
      {
        "id" => SimpleProperty.new("Id", :integer, @id),
        "name" => SimpleProperty.new("Name", :string, '')
      }
    end
    def path
      "#{@parent.path}/#{@id}"
    end

    def actions
      @triggers ||= begin
        resource = RestClient::Resource.new("#{connector.url}/api/applications/#{@id}/actions", connector.username, connector.password)
        triggers ||= JSON.parse(resource.get())
        trigger_hash = Hash.new
        triggers.each do |trigger|
          trigger_hash["trigger_#{trigger["id"]}"]= TriggerAction.new(self, trigger["id"], trigger)
        end
        trigger_hash
      end
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

    def args
      @trigger["parameters"]
    end

    def invoke(options)
      uri = URI("#{connector.url}/external/application/#{parent.id}/trigger/asd")
      uri.query= args.keys.map do |arg|
          "#{arg}=#{options[arg]}"
        end.join '&'

      resource = RestClient::Resource.new(uri.to_s, connector.username, connector.password)
      resource.post("") {|response, request, result| response }
    end
  end
end

class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties
    {"projects" => Projects.new(self)}
  end

  def connector
    self
  end

  private

  def initialize_defaults
    self.url = "http://verboice.instedd.org" unless self.url
  end

  class Projects
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "projects"
    end

    def label
      "Projects"
    end

    def type
      {
        kind: :entity_set,
        entity_type: {
          kind: :struct,
          members: []
        }
      }
    end

    def entities
      @entities ||= begin
        resource = RestClient::Resource.new("#{connector.url}/api/projects.json", connector.username, connector.password)
        projects ||= JSON.parse(resource.get())

        projects.map { |project| Project.new(self, project["id"], project["name"]) }
      end
    end

    def reflect_entities
      entities
    end

    def find_entity(id)
      Project.new(connector, id)
    end
  end

  class Project
    include Entity

    attr_reader :id
    delegate :connector, to: :@parent

    def initialize(connector, id, name = nil)
      @parent = connector
      @id = id
      @label = name
    end

    def label
      @label
    end

    def path
      "projects/#{@id}"
    end

    def actions
      {
        "call" => CallAction.new(self)
      }
    end

  end

  class CallAction
    delegate :connector, to: :@parent

    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Call"
    end

    def path
      "#{@parent.path}/$actions/call"
    end

    def args
      {channel: {type: "string", label: "Channel"}, number: {type: "string", label: "Number"}}
    end

    def invoke(args)
      resource = RestClient::Resource.new("#{connector.url}/api/call?channel=#{args["channel"]}&address=#{args["number"]}", connector.username, connector.password)
      resource.get() {|response, request, result| response }
    end

  end

end

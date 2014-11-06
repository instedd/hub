class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password, :shared
  after_initialize :initialize_defaults, :if => :new_record?

  def properties
    {"projects" => Projects.new(self)}
  end

  private

  def initialize_defaults
    self.url = "https://verboice.instedd.org" unless self.url
    self.shared = false unless self.shared
  end

  class Projects
    include EntitySet

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

    def entities(user)
      @entities ||= begin
        get_projects(connector, user).map { |project| Project.new(self, project["id"], project["name"]) }
      end
    end

    def reflect_entities
      entities
    end

    def find_entity(id)
      Project.new(self, id)
    end

    private

    def get_projects(connector, user)
      if connector.shared and Guisso.enabled?
        resource = Guisso.trusted_resource(connector.url, user.email)
        JSON.parse(resource.get("#{connector.url}/api/projects.json").body)
      else
        resource = RestClient::Resource.new("#{connector.url}/api/projects.json", connector.username, connector.password)
        JSON.parse(resource.get())
      end
    end
  end

  class Project
    include Entity

    attr_reader :id
    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @label = name
    end

    def label
      @label
    end

    def sub_path
      id
    end

    def actions
      {
        "call" => CallAction.new(self)
      }
    end

  end

  class CallAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Call"
    end

    def sub_path
      "call"
    end

    def args
      {channel: {type: "string", label: "Channel"}, number: {type: "string", label: "Number"}}
    end

    def invoke(args, user)
      resource = RestClient::Resource.new("#{connector.url}/api/call?channel=#{args["channel"]}&address=#{args["number"]}", connector.username, connector.password)
      resource.get() {|response, request, result| response }
    end
  end
end

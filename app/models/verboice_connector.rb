class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties
    {"projects" => Projects.new(self)}
  end

  def enqueue_event(task_type, *args)
    task_class = "VerboiceConnector::#{"#{task_type}_task".classify}".constantize
    Resque.enqueue_to(:hub, task_class, args)
  end

  class CallTask

    def self.perform(body)
      data = JSON.parse body
      data["project_id"]
    end
  end

  private

  def initialize_defaults
    self.url = "https://verboice.instedd.org" unless self.url
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

    def entities(user)
      get_projects(connector, user).map { |project| Project.new(self, project["id"], project["name"]) }
    end

    def reflect_entities
      entities
    end

    def find_entity(id)
      Project.new(self, id)
    end

    private

    def get_projects(connector, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects.json")
    end
  end

  class Project
    include Entity
    attr_reader :id, :label

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @label = name
    end

    def sub_path
      id
    end

    def properties
      {
        "id" => SimpleProperty.new("Id", :integer, @id),
        "name" => SimpleProperty.new("Name", :string, @label),
        "call_flows" => CallFlows.new(self),
      }
    end

    def actions(user)
      {
        "call" => CallAction.new(self)
      }
    end
  end

  class CallFlows
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def label
      "Call flows"
    end

    def path
      "#{@parent.path}/call_flows"
    end

    def entities(user)
      project = GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}.json")
      project["call_flows"].map { |cf| CallFlow.new(self, cf["id"], cf["name"]) }
    end

    def find_entity(id)
      CallFlow.new(self, id)
    end
  end

  class CallFlow
    include Entity

    attr_reader :id

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @name = name
    end

    def label
      @name
    end

    def sub_path
      @id
    end

    def events
      {
        "call_finished" => CallFinishedEvent.new(self),
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

    def args(user)
      {
        channel: {
          type: "string",
          label: "Channel"
        }, number: {
          type: "string",
          label: "Number"
        }
      }
    end

    def invoke(args, user)
      encoded_channel_name = args.include?("channel") ? URI::encode(args["channel"]) : ""
      encoded_number = args.include?("number") ? URI::encode(args["number"]) : ""
      call_url = "#{connector.url}/api/call?channel=#{encoded_channel_name}&address=#{encoded_number}"
      GuissoRestClient.new(connector, user).get(call_url)
    end
  end

  class CallFinishedEvent
    include Event

    def initialize(parent)
      @parent = parent
    end

    def label
      "Call finished"
    end

    def sub_path
      "call_finished"
    end

    def args(user)
      project = GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}.json")
      Hash[project["contact_vars"].map { |arg| [arg, :string] }]
    end
  end
end

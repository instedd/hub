class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties(user)
    {"projects" => Projects.new(self)}
  end

  def has_notifiable_events?
    true
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

    def query(filters, user, options)
      projects(user).map { |project| entity(project) }
    end

    def find_entity(id, user)
      Project.new(self, id, nil, user)
    end

    def projects(user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects.json")
    end

    def project(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{id}.json")
    end

    def entity(project)
      Project.new(self, project["id"], project["name"])
    end
  end

  class Project
    include Entity
    attr_reader :id

    def initialize(parent, id, name = nil, user = nil)
      @parent = parent
      @id = id
      @label = name
      @user = user
    end

    def sub_path
      id
    end

    def label(user = nil)
      @label ||= verboice_project(user || @user)["name"]
    end

    def properties(user)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name(label(user)),
        "call_flows" => CallFlows.new(self),
        "phone_book" => PhoneBook.new(self)
      }
    end

    def actions(user)
      {
        "call" => CallAction.new(self)
      }
    end

    def project_id
      @id
    end

    def verboice_project(user)
      @verboice_project ||= GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{id}.json")
    end
  end

  class PhoneBook
    include EntitySet
    protocol :insert, :update, :delete

    def initialize(parent)
      @parent = parent
    end

    def label
      "Phone Book"
    end

    def path
      "#{@parent.path}/phone_book"
    end

    def entity_properties(user)
      vars = GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}/project_variables.json")
      properties = {
        id: SimpleProperty.id,
        address: SimpleProperty.integer("Address")
      }
      vars.each do |variable|
        properties[variable["name"].to_sym] = SimpleProperty.string(variable["name"])
      end
      properties
    end

    def query(filters, user, options)
      contacts = if filters[:address]
        [contact(filters[:address], user)]
      else
        GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}/contacts.json")
      end
      contacts.inject Array.new do |contacts, contact|
        contact["addresses"].inject contacts do |contacts, address|
          contacts.push Contact.new(self, address, contact)
        end
      end
    end

    def reflect_entities(user)
    end

    def find_entity(address, user)
      Contact.new(self, address, contact(address, user))
    end

    def contact(address, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}/contacts/by_address/#{address}.json")
    end
  end

  class Contact
    include Entity

    attr_reader :address
    alias_method :id, :address

    def initialize(parent, address, contact)
      @parent = parent
      @address = address
      @contact = contact
    end

    def label
      address
    end

    def sub_path
      id
    end

    def properties(user)
      {
        id: SimpleProperty.id(@contact["id"]),
        address: SimpleProperty.integer("Address", address)
      }
    end
  end

  class CallFlows
    include EntitySet
    delegate :project_id, to: :@parent
    delegate :verboice_project, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Call flows"
    end

    def path
      "#{@parent.path}/call_flows"
    end

    def query(filters, user, options)
      verboice_project(user)["call_flows"].map { |cf| CallFlow.new(self, cf["id"], cf["name"]) }
    end

    def find_entity(id, user)
      CallFlow.new(self, id, call_flow(id, user)["name"])
    end

    def call_flow(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/projects/#{@parent.id}/call_flows/#{id}.json")
    end
  end

  class CallFlow
    include Entity

    attr_reader :id
    delegate :project_id, to: :@parent
    delegate :verboice_project, to: :@parent

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @name = name
    end

    def label
      @name
    end

    def sub_path
      id
    end

    def properties(user)
      {
        id: SimpleProperty.id(id),
        name: SimpleProperty.name(@name)
      }
    end

    def events
      {
        "call_finished" => CallFinishedEvent.new(self),
      }
    end
  end

  class CallAction
    include Action

    delegate :verboice_project, to: :@parent

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
        },
        number: {
          type: "string",
          label: "Number"
        },
        vars: {
          type: {
            kind: :struct,
            members: Hash[verboice_project(user)["contact_vars"].map { |arg| [arg, {type: :string}] }],
            open: true,
          }
        },
      }
    end

    def invoke(args, user)
      params = {channel: args["channel"], address: args["number"]}
      params[:vars] = args["vars"] if args["vars"].present?
      call_url = "#{connector.url}/api/call?#{params.to_query}"
      GuissoRestClient.new(connector, user).get(call_url)
    end
  end

  class CallFinishedEvent
    include Event

    delegate :project_id, to: :@parent
    delegate :verboice_project, to: :@parent

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
      args = Hash[verboice_project(user)["contact_vars"].map { |arg| [arg, {type: :string}] }]
      args["address"] = {type: :string}
      args
    end
  end
end

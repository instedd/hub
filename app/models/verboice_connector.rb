class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties(context)
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

    def query(filters, context, options)
      items = projects(context.user)
      items = items.map { |project| entity(project) }
      {items: items}
    end

    def find_entity(id, context)
      Project.new(self, id, nil, context.user)
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

    def properties(context)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name(label(context.user)),
        "call_flows" => CallFlows.new(self),
        "phone_book" => PhoneBook.new(self)
      }
    end

    def actions(context)
      {
        "call" => CallAction.new(self)
      }
    end

    def project_id
      @id
    end

    def verboice_project(user)
      @verboice_project ||= parent.project(id, user)
    end
  end

  class PhoneBook
    include EntitySet

    # Only query is supported for now
    # protocol :insert, :update, :delete

    def initialize(parent)
      @parent = parent
    end

    def label
      "Phone Book"
    end

    def path
      "#{@parent.path}/phone_book"
    end

    def entity_properties(context)
      vars = GuissoRestClient.new(connector, context.user).get("#{connector.url}/api/projects/#{@parent.id}/project_variables.json")
      properties = {
        id: SimpleProperty.id,
        address: SimpleProperty.integer("Address")
      }
      vars.each do |variable|
        properties[variable["name"].to_sym] = SimpleProperty.string(variable["name"])
      end
      properties
    end

    def query(filters, context, options)
      if filters[:address]
        contacts = [contact(filters[:address], context.user)]
      else
        contacts = GuissoRestClient.new(connector, context.user).
                     get("#{connector.url}/api/projects/#{@parent.id}/contacts.json")
      end

      items = []
      contacts.each do |contact|
        contact["addresses"].each do |address|
          items << Contact.new(self, address, contact)
        end
      end

      {items: items}
    end

    def reflect_entities(context)
    end

    def find_entity(address, context)
      Contact.new(self, address, contact(address, context.user))
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

    def properties(context)
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

    def query(filters, context, options)
      call_flows = verboice_project(context.user)["call_flows"].map { |cf| CallFlow.new(self, cf["id"], cf["name"]) }
      {items: call_flows}
    end

    def find_entity(id, context)
      CallFlow.new(self, id, call_flow(id, context.user)["name"])
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

    def properties(context)
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

    def args(context)
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
            members: Hash[verboice_project(context.user)["contact_vars"].map { |arg| [arg, {type: :string}] }],
            open: true,
          }
        },
      }
    end

    def invoke(args, context)
      params = {channel: args["channel"], address: args["number"]}
      params[:vars] = args["vars"] if args["vars"].present?
      call_url = "#{connector.url}/api/call?#{params.to_query}"
      GuissoRestClient.new(connector, context.user).get(call_url)
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

    def args(context)
      {
        address: {type: :string},
        vars: {
          type: {
            kind: :struct,
            members: Hash[verboice_project(context.user)["contact_vars"].map { |arg| [arg, {type: :string}] }],
          }
        }
      }
    end
  end
end

class ACTConnector < Connector
  include Entity
  store_accessor :settings, :url

  validates_presence_of :url

  def properties
    {"cases" => Cases.new(self)}
  end

  private

  class Cases
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "cases"
    end

    def label
      "Cases"
    end

    def entities
      []
    end

    def find_entity(id)
      raise "Individual cases cannot be accessed through the connector"
    end

    def events
      {
        "new_case" => NewCaseEvent.new(self)
      }
    end

  end

  class NewCaseEvent
    include Event

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "New case"
    end

    def path
      "#{@parent.path}/$events/new_case"
    end

    def subscribe
      EventHandler.create(connector: connector, event: path, poll: true)
    end

    def args
      {
        name: { type: :string },
        phone_number: { type: :string },
        age: { type: :string },
        gender: { type: {kind: :enum, value_type: :string, members: [
          {value: "M", label: "Male" },
          {value: "F", label: "Male" }
        ]}},
        dialect_code: { type: :string },
        symptoms: {type: {kind: :array, item_type: :string}},
      }
    end

    def poll
      since_date = load_state
      url = "#{connector.url}/api/v1/cases/"
      url += "?since=#{since_date}" if since_date.present?
      cases = JSON.parse(RestClient.get(url))
      
      # assumes cases are sorted by date
      save_state(cases.last[:since_date]) unless cases.empty?
      
      cases
    end

  end

end

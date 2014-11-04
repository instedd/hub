class RapidProConnector < Connector
  include Entity
  store_accessor :settings, :url, :token

  validates_presence_of :url, :token

  def properties
    {"flows" => Flows.new(self)}
  end

  def request_headers
    {"Authorization" => "Token #{token}"}
  end

  private

  class Flows
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "flows"
    end

    def label
      "Flows"
    end

    def entities
      headers = connector.request_headers
      url = "#{connector.url}/api/v1/flows.json"
      all_flows = []

      while true
        response = JSON.parse RestClient.get url, headers
        flows = response["results"].map { |result| Flow.new(self, result["flow"], result["name"]) }
        all_flows.concat flows
        url = response["next"]
        break unless url
      end

      all_flows.sort_by! { |flow| flow.label.downcase }
      all_flows
    end

    def find_entity(id)
      Flow.new(self, id)
    end
  end

  class Flow
    include Entity

    delegate :connector, to: :@parent

    attr_reader :id

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @name = name
    end

    def label
      @name
    end

    def path
      "#{@parent.path}/#{@id}"
    end

    def events
      {
        "new_run" => NewRunEvent.new(self)
      }
    end
  end

  class NewRunEvent
    include Event

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "New run"
    end

    def path
      "#{@parent.path}/$events/new_run"
    end

    def args
      headers = connector.request_headers
      results = JSON.parse(RestClient.get("#{connector.url}/api/v1/flows.json?flow=#{@parent.id}", headers))
      flow = results["results"].first
      rulesets = flow["rulesets"]
      Hash[rulesets.map do |rule|
        [rule["label"], {type: :string}]
      end
      ]
    end
  end
end

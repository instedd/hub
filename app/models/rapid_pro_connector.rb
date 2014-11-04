class RapidProConnector < Connector
  include Entity
  store_accessor :settings, :url, :token

  validates_presence_of :url, :token

  def properties
    {"flows" => Flows.new(self)}
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
      headers = {"Authorization" => "Token #{connector.token}"}
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
  end
end

class RapidProConnector < Connector
  include Entity
  store_accessor :settings, :url, :token

  validates_presence_of :url, :token

  def properties
    {"flows" => Flows.new(self)}
  end

  def http_get(url)
    RestClient.get url, auth_headers
  end

  def http_post_json(url, data)
    headers = auth_headers
    headers["Content-type"] = "application/json"
    RestClient.post url, data.to_json, headers
  end

  def http_get_json_paginated(url)
    while url
      response = JSON.parse http_get(url)
      yield response
      url = response["next"]
    end
  end

  def auth_headers
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

    def entities(user)
      url = "#{connector.url}/api/v1/flows.json"
      all_flows = []

      connector.http_get_json_paginated(url) do |response|
        flows = response["results"].map { |result| Flow.new(self, result["flow"], result["name"]) }
        all_flows.concat flows
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

    def actions(user)
      {
        "run" => RunAction.new(self)
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

    def args(user)
      headers = connector.auth_headers
      results = JSON.parse(RestClient.get("#{connector.url}/api/v1/flows.json?flow=#{@parent.id}", headers))
      flow = results["results"].first
      rulesets = flow["rulesets"]
      values = Hash[rulesets.map do |rule|
        [rule["label"], {type: :string}]
      end]
      {
        concat: {type: :string},
        phone: {type: :string},
        values: {type: {kind: :struct, members: values}}
      }
    end

    def poll
      max_created_on = load_state

      url = "#{connector.url}/api/v1/runs.json?flow=#{@parent.id}"
      # if max_created_on
      #   url << "&after=#{CGI.escape max_created_on}"
      # end

      all_results = []
      connector.http_get_json_paginated(url) do |results|
        all_results.concat results["results"]
      end
      binding.pry
      if max_created_on
        all_results = all_results.select { |r| r["created_on"] > max_created_on }
      end

      events = all_results.map do |result|
        values =         {
          "contact" => result["contact"],
          "phone" => result["phone"],
          "values" => Hash[result["values"].map do |value|
            [value["label"], value["value"]]
          end],
        }
      end

      if events.empty?
        return []
      end

      max_created_on = all_results.max_by { |result| result["created_on"] }["created_on"]
      save_state(max_created_on)
      events.reverse # return oldest event first
    end
  end

  class RunAction
    delegate :connector, to: :@parent

    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Run"
    end

    def path
      "#{@parent.path}/$actions/run"
    end

    def args(user)
      {
        phone: {type: :string},
        extra: {type: {kind: :struct, members: [], open: true}},
      }
    end

    def invoke(args, user)
      connector.http_post_json "#{connector.url}/api/v1/runs.json", {
        flow: @parent.id.to_i,
        phone: [args["phone"]],
        extra: args["extra"],
      }
    end
  end
end

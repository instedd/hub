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
        "run_update" => RunUpdateEvent.new(self)
      }
    end

    def actions(user)
      {
        "run" => RunAction.new(self)
      }
    end
  end

  # This event runs when a run is started or updated thru a new variable asignment
  class RunUpdateEvent
    include Event

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Run update"
    end

    def path
      "#{@parent.path}/$events/run_update"
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
      url = "#{connector.url}/api/v1/runs.json?flow=#{@parent.id}"

      all_results = []
      connector.http_get_json_paginated(url) do |results|
        all_results.concat results["results"]
      end

      process_runs_response all_results
    end

    def process_runs_response(all_results)
      last_date_per_run = load_state || {}

      all_results = all_results.select do |r|
        last_date = last_date_per_run[r["run"]]
        max_time = r["values"].max_by { |v| v["time"] }["time"] rescue r["created_on"]
        last_date_per_run[r["run"]] = max_time

        last_date.nil? || max_time > last_date
      end

      events = all_results.map do |result|
        {
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

      save_state(last_date_per_run)
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

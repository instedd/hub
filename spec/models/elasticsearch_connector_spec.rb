describe ElasticsearchConnector do
  URL = "http://localhost:9200"
  INDEX_URL = "#{URL}/instedd_hub_test"

  let(:user) { User.make }
  let(:connector) { ElasticsearchConnector.make url: URL }
  let(:url_proc) { ->(path) { "http://server/#{path}" }}

  def refresh_index
    RestClient.post "#{INDEX_URL}/_refresh", ""
  end

  before(:each) do
    RestClient.delete INDEX_URL rescue nil
    RestClient.post INDEX_URL, %(
      {
        "mappings": {
          "type1": {
            "properties": {
                "name": { "type" : "string" },
                "age":  { "type" : "integer" }
            }
          }
        }
      }
    )
  end

  after(:all) do
    RestClient.delete INDEX_URL rescue nil
  end

  describe "reflect" do
    it "connector" do
      result = connector.reflect(url_proc, user)
      expect(result).to eq({
        properties: {
          "indices" => {
            label: "Indices",
            type: :entity_set,
            path: "indices",
            reflect_url: "http://server/indices",
          }
        }
      })
    end

    it "indices" do
      result = connector.lookup_path("indices", user).reflect(url_proc, user)
      entity = result[:entities].select { |entity| entity[:label] == "instedd_hub_test" }
      expect(entity).to_not be_nil
    end

    it "index" do
      result = connector.lookup_path("indices/instedd_hub_test", user).reflect(url_proc, user)
      expect(result).to eq({
        properties: {
          "types" => {
            label: "Types",
            type: :entity_set,
            path: "indices/instedd_hub_test/types",
            reflect_url: "http://server/indices/instedd_hub_test/types"
          }
        }
      })
    end

    it "types" do
      result = connector.lookup_path("indices/instedd_hub_test/types", user).reflect(url_proc, user)
      expect(result).to eq({
        entities: [
          {
            label: "type1",
            path: "indices/instedd_hub_test/types/type1",
            reflect_url: "http://server/indices/instedd_hub_test/types/type1"
          }
        ]
      })
    end

    it "type" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1", user).reflect(url_proc, user)
      expect(result).to eq({
        actions: {
          "insert" => {
            label: "Insert",
            path: "indices/instedd_hub_test/types/type1/$actions/insert",
            reflect_url: "http://server/indices/instedd_hub_test/types/type1/$actions/insert"
          },
          "update" => {
            label: "Update",
            path: "indices/instedd_hub_test/types/type1/$actions/update",
            reflect_url: "http://server/indices/instedd_hub_test/types/type1/$actions/update"
          }
        }
      })
    end

    it "insert action" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user).reflect(url_proc, user)
      expect(result).to eq({
        label: "Insert",
        args: {
          properties: {
            type: {
              kind: :struct,
              members: {
                "age" => {type: "integer"},
                "name" => {type: "string"},
              },
              open: true,
            },
          },
        }
      })
    end

    it "update action" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user).reflect(url_proc, user)
      expect(result).to eq({
        label: "Update",
        args: {
          primary_key_name: "string",
          primary_key_value: "object",
          properties: {
            type: {
              kind: :struct,
              members: {
                "age" => {type: "integer"},
                "name" => {type: "string"},
              },
              open: true,
            },
          },
        }
      })
    end
  end

  it "executes insert action" do
    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user)
    action.invoke({"properties" => {"name" => "john", "age" => 30, "extra" => "hello"}}, user)
    refresh_index

    response = JSON.parse RestClient.get "#{INDEX_URL}/_search"
    hits = response["hits"]["hits"]
    expect(hits.length).to eq(1)

    source = hits[0]["_source"]
    expect(source["name"]).to eq("john")
    expect(source["age"]).to eq(30)
    expect(source["extra"]).to eq("hello")
  end

  it "executes update action" do
    RestClient.post("http://localhost:9200/instedd_hub_test/type1", %({"name": "john", "age": 20}))
    RestClient.post("http://localhost:9200/instedd_hub_test/type1", %({"name": "peter", "age": 40}))
    refresh_index

    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user)
    action.invoke(
      {
        "primary_key_name" => "name",
        "primary_key_value" => "john",
        "properties" => {"name" => "john", "age" => 10, "extra" => "hello"},
      },
      user
    )
    refresh_index

    response = JSON.parse RestClient.get "#{INDEX_URL}/_search"
    hits = response["hits"]["hits"]
    expect(hits.length).to eq(2)

    sources = hits.map { |hit| hit["_source"] }

    john = sources.find { |source| source["name"] == "john" }
    expect(john["age"]).to eq(10)
    expect(john["extra"]).to eq("hello")

    peter = sources.find { |source| source["name"] == "peter" }
    expect(peter["age"]).to eq(40)
    expect(peter["extra"]).to be_nil
  end
end
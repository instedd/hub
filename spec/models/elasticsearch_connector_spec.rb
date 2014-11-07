describe ElasticsearchConnector do
  URL = "http://localhost:9200"
  INDEX_URL = "#{URL}/instedd_hub_test"

  let(:user) { User.make }
  let(:connector) { ElasticsearchConnector.make url: URL }
  let(:url_proc) { ->(path) { "http://server/#{path}" }}

  before(:all) do
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
          }
        }
      })
    end

    it "insert action" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user).reflect(url_proc, user)
      expect(result).to eq({
        label: "Insert",
        args: {
          "age" => {type: "integer"},
          "name" => {type: "string"}
        }
      })
    end
  end

  it "executes insert action" do
    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user)
    action.invoke({"name" => "John", "age" => 30}, user)

    RestClient.post "#{INDEX_URL}/_refresh", ""
    response = JSON.parse RestClient.get "#{INDEX_URL}/_search"
    hits = response["hits"]["hits"]
    expect(hits.length).to eq(1)

    source = hits[0]["_source"]
    expect(source["name"]).to eq("John")
    expect(source["age"]).to eq(30)
  end
end

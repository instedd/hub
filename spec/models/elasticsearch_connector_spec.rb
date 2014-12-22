describe ElasticsearchConnector do
  def url
    "http://localhost:9200"
  end

  def index_url
    "#{url}/instedd_hub_test"
  end

  let(:user) { User.make }
  let(:connector) { ElasticsearchConnector.make url: url }

  def refresh_index
    RestClient.post "#{index_url}/_refresh", ""
  end

  before(:each) do
    RestClient.delete index_url rescue nil
    RestClient.post index_url, %(
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
    RestClient.delete index_url rescue nil
  end

  describe "reflect" do
    it "connector" do
      result = connector.reflect(context)
      expect(result).to eq({
        label: connector.name,
        path: "",
        reflect_url: "http://server/api/reflect/connectors/1",
        type: :entity,
        properties: {
          "indices" => {
            label: "Indices",
            type: :entity_set,
            path: "indices",
            reflect_url: "http://server/api/reflect/connectors/1/indices",
          }
        }
      })
    end

    it "indices" do
      result = connector.lookup_path("indices", user).reflect(context)
      entity = result[:entities].select { |entity| entity[:label] == "instedd_hub_test" }
      expect(entity).to_not be_nil
    end

    it "index" do
      result = connector.lookup_path("indices/instedd_hub_test", user).reflect(context)
      expect(result).to eq({
        label: "instedd_hub_test",
        path: "indices/instedd_hub_test",
        reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test",
        type: :entity,
        properties: {
          "types" => {
            label: "Types",
            type: :entity_set,
            path: "indices/instedd_hub_test/types",
            reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types"
          }
        }
      })
    end

    it "types" do
      result = connector.lookup_path("indices/instedd_hub_test/types", user).reflect(context)
      expect(result).to eq({
        label: "Types",
        path: "indices/instedd_hub_test/types",
        reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types",
        type: :entity_set,
        protocol: [:query],
        entities: [
          {
            label: "type1",
            path: "indices/instedd_hub_test/types/type1",
            type: :entity_set,
            reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types/type1"
          }
        ]
      })
    end

    it "type" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1", user).reflect(context)
      expect(result).to eq({
        label: "type1",
        entity_definition: {
          properties: {
            "age"  => {label: "age", type: "integer"},
            "name" => {label: "name", type: "string"},
          }
        },
        protocol: [:query, :insert, :update],
        path: "indices/instedd_hub_test/types/type1",
        reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types/type1",
        type: :entity_set,
        actions: {
          "insert" => {
            label: "Insert",
            path: "indices/instedd_hub_test/types/type1/$actions/insert",
            reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types/type1/$actions/insert"
          },
          "update" => {
            label: "Update",
            path: "indices/instedd_hub_test/types/type1/$actions/update",
            reflect_url: "http://server/api/reflect/connectors/1/indices/instedd_hub_test/types/type1/$actions/update"
          }
        }
      })
    end

    it "insert action" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user).reflect(context)
      expect(result).to eq({
        label: "Insert",
        args: {
          properties: {
            type: {
              kind: :struct,
              members: {
                "age" => {type: "integer", :label=>"age"},
                "name" => {type: "string", :label=>"name"},
              },
              open: true,
            },
          },
        }
      })
    end

    it "update action" do
      result = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user).reflect(context)
      expect(result).to eq({
        label: "Update",
        args: {
          filters: {
            type: {
              kind: :struct,
              members: {
                "age" => {type: "integer", :label=>"age"},
                "name" => {type: "string", :label=>"name"},
              },
              open: true,
            },
          },
          properties: {
            type: {
              kind: :struct,
              members: {
                "age" => {type: "integer", :label=>"age"},
                "name" => {type: "string", :label=>"name"},
              },
              open: true,
            },
          },
        }
      })
    end
  end

  it "executes query" do
    RestClient.post("#{index_url}/type1", %({"name": "john", "age": 20}))
    RestClient.post("#{index_url}/type1", %({"name": "peter", "age": 40}))
    refresh_index

    entity_set = connector.lookup_path("indices/instedd_hub_test/types/type1", user)
    result = entity_set.query({}, context, {})
    expect(result[:next_page]).to be_nil
    expect(result[:items].count).to eq(2)

    result = entity_set.query({name: 'peter'}, context, {})
    expect(result[:next_page]).to be_nil
    expect(result[:items].count).to eq(1)
  end

  it "executes query paginated" do
    RestClient.post("#{index_url}/type1", %({"name": "john", "age": 20}))
    RestClient.post("#{index_url}/type1", %({"name": "peter", "age": 40}))
    RestClient.post("#{index_url}/type1", %({"name": "martin", "age": 30}))
    refresh_index

    allow(ElasticsearchConnector).to receive(:default_page_size).and_return(2)

    entity_set = connector.lookup_path("indices/instedd_hub_test/types/type1", user)
    result = entity_set.query({}, context, {})
    expect(result[:next_page]).to eq(2)
    expect(result[:items].count).to eq(2)

    result = entity_set.query({}, context, {page: 2})
    expect(result[:next_page]).to be_nil
    expect(result[:items].count).to eq(1)
  end

  it "executes insert action" do
    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/insert", user)
    action.invoke({"properties" => {"name" => "john", "age" => 30, "extra" => "hello"}}, user)
    refresh_index

    response = JSON.parse RestClient.get "#{index_url}/_search"
    hits = response["hits"]["hits"]
    expect(hits.length).to eq(1)

    source = hits[0]["_source"]
    expect(source["name"]).to eq("john")
    expect(source["age"]).to eq(30)
    expect(source["extra"]).to eq("hello")
  end

  it "executes update action" do
    RestClient.post("#{index_url}/type1", %({"name": "john", "age": 20}))
    RestClient.post("#{index_url}/type1", %({"name": "peter", "age": 40}))
    refresh_index

    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user)
    action.invoke(
      {
        "filters" => {
          "name" => "john",
        },
        "properties" => {
          "name" => "john",
          "age" => 10,
          "extra" => "hello"
        },
      },
      user
    )
    refresh_index

    response = JSON.parse RestClient.get "#{index_url}/_search"
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

  it "executes update action with many keys" do
    RestClient.post("#{index_url}/type1", %({"name": "john", "age": 20}))
    RestClient.post("#{index_url}/type1", %({"name": "peter", "age": 40}))
    refresh_index

    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user)
    action.invoke(
      {
        "filters" => {
          "name" => "john",
          "age" => 20,
        },
        "properties" => {
          "name" => "john",
          "age" => 10,
          "extra" => "hello"
        },
      },
      user
    )
    refresh_index

    response = JSON.parse RestClient.get "#{index_url}/_search"
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

  it "executes update over all values" do
    RestClient.post("#{index_url}/type1", %({"name": "john", "age": 20}))
    RestClient.post("#{index_url}/type1", %({"name": "peter", "age": 40}))
    refresh_index

    action = connector.lookup_path("indices/instedd_hub_test/types/type1/$actions/update", user)
    action.invoke(
      {
        "filters" => {
        },
        "properties" => {
          "name" => "john",
          "age" => 10,
          "extra" => "hello"
        },
      },
      user
    )
    refresh_index

    response = JSON.parse RestClient.get "#{index_url}/_search"
    hits = response["hits"]["hits"]
    expect(hits.length).to eq(2)

    sources = hits.map { |hit| hit["_source"] }
    expect(sources).to eq([
      {"name"=>"john", "age"=>10, "extra"=>"hello"},
      {"name"=>"john", "age"=>10, "extra"=>"hello"}
    ])
  end
end

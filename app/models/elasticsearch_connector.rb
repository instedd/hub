class ElasticsearchConnector < Connector
  include Entity
  store_accessor :settings, :url

  validates_presence_of :url

  def properties
    {"indices" => Indices.new(self)}
  end

  private

  class Indices
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "indices"
    end

    def label
      "Indices"
    end

    def entities(user)
      response = JSON.parse RestClient.get("#{connector.url}/_stats/indices")
      response["indices"].map { |name, index| Index.new(self, name) }
    end

    def find_entity(id)
      Index.new(self, id)
    end
  end

  class Index
    include Entity
    attr_reader :name

    def initialize(parent, name = nil)
      @parent = parent
      @name = name
    end

    def label
      @name
    end

    def index_name
      @name
    end

    def sub_path
      @name
    end

    def properties
      {"types" => Types.new(self)}
    end
  end

  class Types
    include EntitySet
    delegate :index_name, to: :parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "#{@parent.path}/types"
    end

    def label
      "Types"
    end

    def entities(user)
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping")
      response[@parent.name]["mappings"].keys.map { |type| Type.new(self, type) }
    end

    def find_entity(id)
      Type.new(self, id)
    end
  end

  class Type
    include Entity
    delegate :index_name, to: :parent

    def initialize(parent, name = nil)
      @parent = parent
      @name = name
    end

    def sub_path
      @name
    end

    def label
      @name
    end

    def type_name
      @name
    end

    def actions(user)
      {
        "insert" => InsertAction.new(self),
        "update" => UpdateAction.new(self),
      }
    end
  end

  class InsertAction
    include Action
    delegate :index_name, :type_name, to: :parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Insert"
    end

    def sub_path
      "insert"
    end

    def args
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping")
      properties = response[index_name]["mappings"][type_name]["properties"]
      {
        properties: {
          type: {
            kind: :struct,
            members: elasticsearch_properties(properties),
            open: true,
          },
        },
      }
    end

    def elasticsearch_properties(hash)
      Hash[hash.map do |key, value|
        if props = value["properties"]
          [key, {type: {kind: :struct, members: elasticsearch_properties(props)}}]
        else
          [key, {type: value["type"]}]
        end
      end]
    end

    def invoke(args, user)
      properties = args["properties"]
      properties.delete "_id"
      RestClient.post("#{connector.url}/#{index_name}/#{type_name}", properties.to_json)
    end
  end

  class UpdateAction
    include Action
    delegate :index_name, :type_name, to: :parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Update"
    end

    def sub_path
      "update"
    end

    def args
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping")
      properties = response[index_name]["mappings"][type_name]["properties"]
      {
        primary_key_name: "string",
        primary_key_value: "object",
        properties: {
          type: {
            kind: :struct,
            members: elasticsearch_properties(properties),
            open: true,
          },
        },
      }
    end

    def elasticsearch_properties(hash)
      Hash[hash.map do |key, value|
        if props = value["properties"]
          [key, {type: {kind: :struct, members: elasticsearch_properties(props)}}]
        else
          [key, {type: value["type"]}]
        end
      end]
    end

    def invoke(args, user)
      primary_key_name = args["primary_key_name"]
      primary_key_value = args["primary_key_value"]
      properties = args["properties"]

      query = {
        query: {
          filtered: {
            filter: {
              term: {
                primary_key_name => primary_key_value
              }
            }
          }
        }
      }

      result = JSON.parse RestClient.post("#{connector.url}/#{index_name}/#{type_name}/_search", query.to_json)
      hits = result["hits"]["hits"]
      hits.each do |hit|
        id = hit["_id"]
        source = hit["_source"]
        source.merge! properties
        source.delete "_id"

        response = RestClient.post "#{connector.url}/#{index_name}/#{type_name}/#{id}", source.to_json
      end
    end
  end
end

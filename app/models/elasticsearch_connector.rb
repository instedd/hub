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

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "indices"
    end

    def label
      "Indices"
    end

    def entities
      response = JSON.parse RestClient.get("#{connector.url}/_stats/indices")
      response["indices"].map { |name, index| Index.new(self, name) }
    end

    def find_entity(id)
      Index.new(self, id)
    end
  end

  class Index
    include Entity

    delegate :connector, to: :@parent

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

    def path
      "#{@parent.path}/#{@name}"
    end

    def properties
      {"types" => Types.new(self)}
    end
  end

  class Types
    include EntitySet

    delegate :connector, :index_name, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "#{@parent.path}/types"
    end

    def label
      "Types"
    end

    def entities
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping")
      response[@parent.name]["mappings"].keys.map { |type| Type.new(self, type) }
    end

    def find_entity(id)
      Type.new(self, id)
    end
  end

  class Type
    include Entity

    delegate :connector, :index_name, to: :@parent

    def initialize(parent, name = nil)
      @parent = parent
      @name = name
    end

    def path
      "#{@parent.path}/#{@name}"
    end

    def label
      @name
    end

    def type_name
      @name
    end

    def actions
      {
        "insert" => InsertAction.new(self)
      }
    end
  end

  class InsertAction
    include Action

    delegate :connector, :index_name, :type_name, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Insert"
    end

    def path
      "#{@parent.path}/$actions/insert"
    end

    def args
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping?pretty")
      properties = response[index_name]["mappings"][type_name]["properties"]
      elasticsearch_properties properties
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
  end
end

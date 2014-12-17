class ElasticsearchConnector < Connector
  include Entity
  store_accessor :settings, :url

  validates_presence_of :url

  def properties(context)
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

    def query(filters, context, options)
      response = JSON.parse RestClient.get("#{connector.url}/_stats/indices")
      response["indices"].map { |name, index| Index.new(self, name) }
    end

    def find_entity(id, context)
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

    def properties(context)
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

    def query(filters, context, options)
      response = JSON.parse RestClient.get("#{connector.url}/#{index_name}/_mapping")
      response[@parent.name]["mappings"].keys.map { |type| Type.new(self, type) }
    end

    def find_entity(id, context)
      Type.new(self, id)
    end
  end

  class Type
    include EntitySet
    protocol :insert, :update
    delegate :index_name, to: :parent

    def initialize(parent, name)
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

    def query(filters, context, options)
      filter = {query:{bool: {must: filters.map { |k, v| {match: {k => v}} } }}}.to_json unless filters.empty?
      response = JSON.parse RestClient.post("#{connector.url}/#{index_name}/_search", filter)
      response['hits']['hits'].map { |r| Record.new(self, r['_source']) }
    end

    def insert(properties, context)
      properties.delete "_id"
      RestClient.post("#{connector.url}/#{index_name}/#{type_name}", properties.to_json)
    end

    def update(filters, properties, context)
      and_filters = filters.map { |k, v| {term: {k => v}} }

      if and_filters.empty?
        query = {
          query: {
            filtered: {
              filter: {
                match_all: {}
              }
            }
          }
        }
      else
        query = {
          query: {
            filtered: {
              filter: {
                and: and_filters
              }
            }
          }
        }
      end

      result = JSON.parse RestClient.post("#{connector.url}/#{index_name}/#{type_name}/_search", query.to_json)
      hits = result["hits"]["hits"]
      hits.each do |hit|
        id = hit["_id"]
        source = hit["_source"]
        source.merge! properties
        source.delete "_id"
        RestClient.post "#{connector.url}/#{index_name}/#{type_name}/#{id}", source.to_json
      end

      hits.count
    end

    def reflect_entities(context)
      # Rows are not displayed during reflection
    end

    def entity_properties(context)
      mapping = JSON.parse RestClient.get("#{connector.url}/#{index_name}/#{type_name}/_mapping")
      properties = mapping[index_name]['mappings'][type_name]['properties']
      elasticsearch_properties(properties)
    rescue RestClient::ResourceNotFound
      Hash.new
    end

    def elasticsearch_properties(hash)
      Hash[hash.map do |key, value|
        if props = value["properties"]
          [key, ComposedProperty.new(elasticsearch_properties(props), open: true)]
        else
          [key, SimpleProperty.new(key, value["type"])]
        end
      end]
    end

    class InsertAction < EntitySet::InsertAction
      def args(context)
        super.tap do |args|
          args[:properties][:type][:open] = true
        end
      end
    end

    class UpdateAction < EntitySet::UpdateAction
      def args(context)
        super.tap do |args|
          args[:properties][:type][:open] = true
          args[:filters][:type][:open] = true
        end
      end
    end
  end

  class Record
    include Entity

    def initialize(parent, row)
      @parent = parent
      @row = row
    end

    def properties(context)
      Hash[parent.entity_properties(context).map { |n,d| [n, SimpleProperty.string(n, @row[n])] }]
    end
  end
end

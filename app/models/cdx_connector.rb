class CDXConnector < Connector
  include Entity
  store_accessor :settings, :url, :username, :password

  validates_presence_of :url

  def human_type
    "CDX"
  end

  def properties(context)
    {"filters" => Filters.new(self)}
  end

  private

  class Filters
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "filters"
    end

    def label
      "Filters"
    end

    def query(filters, context, options)
      filters = GuissoRestClient.new(connector, context.user).get("#{connector.url}/cdx/v1/filters")
      filters = filters.map { |filter| Filter.new(self, filter["id"], filter) }
      {items: filters}
    end

    def find_entity(id, context)
      Filter.new(self, id)
    end
  end

  class Filter
    include Entity
    attr_reader :id

    def initialize(parent, id, filter={})
      @parent = parent
      @id = id
      @filter = filter
    end

    def sub_path
      id
    end

    def label
      @filter['name']
    end

  end

end

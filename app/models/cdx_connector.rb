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

  def get(context, relative_url)
    GuissoRestClient.new(self, context.user).get("#{self.url}/#{relative_url}")
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
      filters = connector.get(context, "filters")
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

    def events
      {
        "new_data" => NewDataEvent.new(self)
      }
    end

    class NewDataEvent
      include Event

      def initialize(parent)
        @parent = parent
      end

      def label
        "New data"
      end

      def sub_path
        "new_data"
      end

      def args(context)
        schema = connector.get(context, "events/schema.json")
        res = {}
        event_schema = {}
        res['event'] = { type: { kind: 'struct', members: event_schema } }

        schema['properties'].each do |key, value|
          event_schema[key] = {type: value['type'], label: value['title']}
        end

        res
      end

      def subscribe(action, binding, user)
        super.tap do |res|
          self.reference_count = self.reference_count + 1
        end
      end

      def unsubscribe
        super.tap do |res|
          self.reference_count = self.reference_count - 1
        end
      end

      def reference_count
        (load_state || {})[:reference_count] || 0
      end

      def reference_count=(value)
        state = load_state || {}
        state[:reference_count] = value
        save_state(state)
      end
    end

  end
end

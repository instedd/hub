class CDXConnector < Connector
  include Entity
  store_accessor :settings, :url, :oauth_token

  validates_presence_of :url, :oauth_token

  def human_type
    "CDX"
  end

  def properties(context)
    {"filters" => Filters.new(self)}
  end

  def get(context, relative_url)
    GuissoRestClient.new(self, context.user).get("#{self.url}/#{relative_url}")
  end

  def post(context, relative_url, body)
    GuissoRestClient.new(self, context.user).post("#{self.url}/#{relative_url}", body.to_query)
  end

  def delete(context, relative_url)
    GuissoRestClient.new(self, context.user).delete("#{self.url}/#{relative_url}")
  end

  def callback(context, path, request)
    event = self.lookup_path(path, context)
    event.validate_and_exec_callback(context, path, request)
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
        "new_event" => NewEvent.new(self)
      }
    end

    class NewEvent
      include Event

      def initialize(parent)
        @parent = parent
      end

      def label
        "New event"
      end

      def sub_path
        "new_event"
      end

      def filter_id
        @parent.id
      end

      def args(context)
        schema = connector.get(context, "events/schema.json")
        {"event" => convert_json_schema(schema)}
      end

      def convert_json_schema(schema)
        case schema['type']
        when "object"
          members = {}
          schema['properties'].each do |key, value|
            members[key] = convert_json_schema(value)
          end
          { type: { kind: 'struct', members: members }}
        when "array"
          # HACK: Arrays are not supported yet. The first element is mapped
          convert_json_schema schema['items']
        else
          { type: schema['type'], label: schema['title'] }
        end

      end

      def subscribe(context)
        super.tap do |res|
          current_count = self.reference_count
          self.reference_count = current_count + 1

          if current_count == 0
            # first time the subscription will be need
            token = self.make_callback_secret!

            subscriber = JSON.parse(connector.post(context, "filters/#{self.filter_id}/subscribers.json", {
              subscriber: {
                name: "InSTEDD Hub (#{Settings.host})",
                url: "http://#{Settings.host}/api/callback/connectors/#{connector.guid}/#{self.path}?token=#{token}",
                verb: 'POST'
              }
            }))

            self.subscriber_id = subscriber['id']
          end
        end
      end

      def unsubscribe(context)
        super.tap do |res|
          current_count = self.reference_count
          self.reference_count = current_count - 1

          if current_count == 1
            # last time the subscription is needed
            begin
              connector.delete(context, "filters/#{self.filter_id}/subscribers/#{self.subscriber_id}")
            rescue Exception => ex
              Rails.logger.warn "Error when trying to delete subscriber: #{ex.message}"
            end
          end
        end
      end

      def hash_state
        state = JSON.parse(load_state) rescue nil
        state = {} unless state.is_a? Hash
        state
      end

      def reference_count
        hash_state['reference_count'] || 0
      end

      def reference_count=(value)
        state = hash_state
        state['reference_count'] = value
        save_state(state.to_json)
      end

      def subscriber_id
        hash_state['subscriber_id']
      end

      def subscriber_id=(value)
        state = hash_state
        state['subscriber_id'] = value
        save_state(state.to_json)
      end

      def callback_secret
        hash_state['callback_secret']
      end

      def make_callback_secret!
        token = Guid.new.to_s

        state = hash_state
        state['callback_secret'] = BCrypt::Password.create(token)
        save_state(state.to_json)

        token
      end

      def validate_and_exec_callback(context, path, request)
        raise "invalid token" unless authenticate_with_token(request.params[:token])

        event_data = JSON.parse(request.body.read)
        convert_test_assays_array_into_plain_object(event_data)
        event = {event: event_data}

        Resque.enqueue_to(:hub, Connector::NotifyJob, self.connector.id, path, event.to_json)
      end

      def authenticate_with_token(token)
        BCrypt::Password.new(self.callback_secret) == token
      end

      def convert_test_assays_array_into_plain_object(event_data)
        if event_data.is_a?(Hash)
          test_data = event_data["test"]
          if test_data.is_a?(Hash)
            assays_data = test_data["assays"]
            if assays_data.is_a?(Array)
              test_data["assays"] = assays_data.first
            end
          end
        end
      end
    end
  end
end

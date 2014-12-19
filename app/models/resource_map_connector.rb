class ResourceMapConnector < Connector
  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties(context)
    {"collections" => Collections.new(self)}
  end

  private

  def initialize_defaults
    self.url = "https://resourcemap.instedd.org" unless self.url
  end

  class Collections
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "collections"
    end

    def label
      "Collections"
    end

    def query(filters, context, options)
      collections(context.user).map { |collection| entity(collection) }
    end

    def find_entity(id, context)
      Collection.new(self, id, nil, context.user)
    end

    def collections(user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/collections.json")
    end

    def collection(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/collections/#{id}.json")
    end

    def entity(collection)
      Collection.new(self, collection["id"], collection["name"])
    end
  end

  class Collection
    include Entity
    attr_reader :id

    def initialize(parent, id, name = nil, user = nil)
      @parent = parent
      @id = id
      @label = name
      @user = user
    end

    def sub_path
      id
    end

    def label(user = nil)
      @label ||= collection(user || @user)["name"]
    end

    def properties(context)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name(label(context.user)),
        "sites" => Sites.new(self),
      }
    end

    def collection_id
      @id
    end

    def collection(user)
      @collection ||= parent.collections(user).find { |col| col["id"].to_s == id.to_s }
    end
  end

  class Sites
    include EntitySet
    delegate :collection_id, to: :@parent

    protocol :insert, :update, :delete

    def initialize(parent)
      @parent = parent
    end

    def label
      "Sites"
    end

    def path
      "#{@parent.path}/sites"
    end

    def reflect_entities(context)
    end

    def entity_properties(context)
      layers = GuissoRestClient.new(connector, context.user).get("#{connector.url}/api/collections/#{@parent.id}/layers.json")
      {
        id: SimpleProperty.integer("ID"),
        name: SimpleProperty.string("Name"),
        lat: SimpleProperty.float("Latitude"),
        lng: SimpleProperty.float("Longitude"),
        layers: {
          label: "Layers",
          type: {
            kind: :struct,
            members: Hash[layers.map do |layer|
              [layer["id"].to_s, {
                label: layer["name"],
                type: {
                  kind: :struct,
                  members: Hash[
                    (layer["fields"] || []).map do |field|
                      [field["code"].to_s, field_properties(field)]
                    end
                  ]
                }
              }]
            end]
          }
        }
      }
    end

    def query(filters, context, options)
      url_query = filters_as_query(filters)
      if url_query.empty?
        url_query = ""
      else
        url_query = "?#{url_query.to_query}"
      end

      sites = GuissoRestClient.new(connector, context.user).
                get("#{connector.url}/api/collections/#{@parent.id}.json#{url_query}")

      layers = GuissoRestClient.new(connector, context.user).get("#{connector.url}/api/collections/#{@parent.id}/layers.json")
      layers_by_field_code = index_layers_by_field_code(layers)

      sites_to_ui(sites["sites"], layers_by_field_code)
    end

    def insert(properties, context)
      GuissoRestClient.new(connector, context.user).
        post("#{connector.url}/api/collections/#{@parent.id}/sites.json",
          site: site_as_json(properties).to_json)
    end

    def update(filters, properties, context)
      #
    end

    def site_as_json(properties)
      site = {}

      site["name"] = properties["name"] if properties["name"].present?
      site["lat"] = properties["lat"].to_f if properties["lat"].present?
      site["lng"] = properties["lng"].to_f if properties["lng"].present?

      site_properties = site["properties"] = {}

      layers = properties["layers"]
      if layers
        layers.each do |layer_id, fields|
          if fields
            fields.each do |field_code, value|
              site_properties[field_code] = value
            end
          end
        end
      end

      if site_properties.empty?
        site.delete "properties"
      end

      site
    end

    def field_properties(field)
      h = {}
      h[:label] = field["name"]
      case field["kind"]
      when "numeric"
        if field["config"] && field["config"]["allows_decimals"]
          h[:kind] = :float
        else
          h[:kind] = :integer
        end
      # TODO: missing select one, select many and hierarchy fields
      else
        h[:kind]= :string
      end
      h
    end

    def filters_as_query(filters)
      query = {}

      query["name"] = filters["name"] if filters["name"].present?
      query["lat"] = filters["lat"] if filters["lat"].present?
      query["lng"] = filters["lng"] if filters["lng"].present?

      layers = filters["layers"]
      if layers
        layers.each do |layer_id, fields|
          if fields
            fields.each do |field_code, value|
              query[field_code] = value
            end
          end
        end
      end

      query
    end

    def sites_to_ui(sites, layers_by_field_code)
      sites.map { |site| site_to_ui(site, layers_by_field_code) }
    end

    def site_to_ui(site, layers_by_field_code)
      ui = {}

      ui["id"] = site["id"]
      ui["name"] = site["name"]
      ui["lat"] = site["lat"] if site["lat"].present?
      ui["lng"] = site["long"] if site["long"].present?
      ui_layers = ui["layers"] = {}

      properties = site["properties"]
      if properties
        properties.each do |field_code, value|
          layer_id = layers_by_field_code[field_code]
          if layer_id
            layer_properties = ui_layers[layer_id.to_s] ||= {}
            layer_properties[field_code] = value
          end
        end
      end

      ui
    end

    def index_layers_by_field_code(layers)
      index = {}
      layers.each do |layer|
        fields = layer["fields"]
        if fields
          fields.each do |field|
            index[field["code"]] = layer["id"]
          end
        end
      end
      index
    end
  end
end
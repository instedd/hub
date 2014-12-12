class GoogleFusionTablesConnector < Connector
  include Entity

  store_accessor :settings, :access_token, :refresh_token, :expires_at

  validates_presence_of :access_token
  validates_presence_of :refresh_token
  validates_presence_of :expires_at

  def properties(context)
    {"tables" => Tables.new(self)}
  end

  def needs_authorization?
    true
  end

  def authorization_text
    "Save and authenticate with Google"
  end

  def authorization_uri(redirect_uri, state)
    client = api_client
    auth = client.authorization
    auth.redirect_uri = redirect_uri
    auth.state = state
    auth.authorization_uri(access_type: :offline, approval_prompt: :force).to_s
  end

  def callback_action
    :google_fusiontables_callback
  end

  def api_client
    self.class.api_client
  end

  def self.api_client
    client = Google::APIClient.new application_name: "InSTEDD Hub", application_version: "1.0"
    auth = client.authorization
    auth.client_id = Settings.google.client_id
    auth.client_secret = Settings.google.client_secret
    auth.scope = [
      "https://www.googleapis.com/auth/fusiontables",
    ]
    client
  end

  def access_token
    if access_token_expired?
      token = OAuth2::AccessToken.from_hash(oauth_client, refresh_token: refresh_token)
      auth_token = token.refresh!
      self.access_token = auth_token.token
      self.expires_at = auth_token.expires_in.seconds.from_now
      self.refresh_token = auth_token.refresh_token if auth_token.refresh_token
      save!
    end
    settings[:access_token]
  end

  def access_token_expired?
    if expires_at
      Time.now > expires_at - 5.minutes
    else
      false
    end
  end

  def oauth_client
    self.class.oauth_client
  end

  def self.oauth_client
    OAuth2::Client.new(
        Settings.google.client_id,
        Settings.google.client_secret,
        site: "https://accounts.google.com",
        token_url: "/o/oauth2/token",
        authorize_url: "/o/oauth2/auth")
  end

  def get url
    token = Rack::OAuth2::AccessToken::Bearer.new(
      :access_token => access_token
    )
    response = token.get url
    JSON.parse(response.body)
  end

  class Tables
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def label
      "Tables"
    end

    def path
      'tables'
    end

    def tables
      data = connector.get "https://www.googleapis.com/fusiontables/v2/tables?fields=items(name%2CtableId)"
      tables = (data["items"] || [])
    end

    def query(filter, context, options)
      tables.map do |table|
        Table.new(self, table["tableId"], table["name"])
      end
    end

    def find_entity(table_id, context)
      table_data = connector.get "https://www.googleapis.com/fusiontables/v2/tables/#{table_id}"
      Table.new self, table_id, table_data["name"], table_data["columns"]
    end

  end

  class Table
    include EntitySet
    protocol :update, :insert, :delete

    def initialize(parent, id, name, columns=nil)
      @parent = parent
      @id = id
      @name = name
      @columns = columns
    end

    def path
      "tables/#{@id}"
    end

    def label
      @name
    end

     def properties(context)
      {
        "id" => SimpleProperty.string("id", @id),
        "name" => SimpleProperty.name(@name),
      }
    end

    def entity_properties(context)
      Hash[@columns.map do |c|
        label = c["name"]

        property_type = case c["type"]
          when "DATETIME"
            SimpleProperty.datetime(label)
          when "LOCATION"
            SimpleProperty.location(label)
          when "NUMBER"
            SimpleProperty.numeric(label)
          when "STRING"
            SimpleProperty.string(label)
        end

        [label, property_type]
      end]
    end

    def column_names
      @columns.map {|c| c["name"]}
    end

    def reflect_entities(context)
      # Rows are not displayed during reflection
    end

    def generate_query_url(filters)
      conditions = []
      filters.keys.each do |key|
        conditions << "#{key}='#{URI.escape(filters[key].to_s)}'"
      end
      sql = "SELECT * FROM #{@id}"
      if conditions.count > 0
        sql << " WHERE #{conditions.join(" AND ")}"
      end
      "https://www.googleapis.com/fusiontables/v2/query?#{{sql: sql}.to_query}"
    end

    def query(filters, context, options)
      results = connector.get generate_query_url(filters)
      results["rows"].map{|data| Row.new(self, data)}
    end
  end

   class Row
    include Entity

    def initialize(parent, row)
      @parent = parent
      @row = {}
      parent.column_names.each_with_index do |header, index|
        @row[header] = row[index]
      end
    end

    def properties(context)
      Hash[parent.columns.map { |c| [c, SimpleProperty.string(h, @row[c])] }]
    end
  end

end

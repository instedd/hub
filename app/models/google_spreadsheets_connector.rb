class GoogleSpreadsheetsConnector < Connector
  include EntitySet

  store_accessor :settings, :access_token, :refresh_token, :expires_at, :spreadsheet_key, :spreadsheet_name

  validates_presence_of :access_token
  validates_presence_of :refresh_token
  validates_presence_of :expires_at

  def has_events?
    false
  end

  def label
    "Spreadsheets"
  end

  def path
    ""
  end

  def query(filters, context, options)
    {items: [Spreadsheet.new(self, spreadsheet_key)]}
  end

  def find_entity(key, context)
    Spreadsheet.new(self, key)
  end

  def needs_authorization?
    true
  end

  def authorization_text
    "Save and authenticate with Google"
  end

  def callback_action
    :google_spreadsheets_callback
  end

  def authorization_uri(redirect_uri, state)
    client = api_client
    auth = client.authorization
    auth.redirect_uri = redirect_uri
    auth.state = state
    auth.authorization_uri(access_type: :offline, approval_prompt: :force).to_s
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

  def api_client
    self.class.api_client
  end

  def self.api_client
    client = Google::APIClient.new application_name: "InSTEDD Hub", application_version: "1.0"
    auth = client.authorization
    auth.client_id = Settings.google.client_id
    auth.client_secret = Settings.google.client_secret
    auth.scope = [
      "https://www.googleapis.com/auth/drive.file",
      "https://www.googleapis.com/auth/drive.install",
      "https://www.googleapis.com/auth/userinfo.profile",
    ]
    client
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

  class Spreadsheet
    include EntitySet

    attr_reader :key

    def initialize(parent, key)
      @parent = parent
      @key = key
    end

    def label
      connector.spreadsheet_name
    end

    def path
      @key
    end

    def spreadsheet
      session = GoogleDrive.login_with_oauth(connector.access_token)
      session.spreadsheet_by_key(@key)
    end

    def query(filter, context, options)
      ws = spreadsheet.worksheets
      ws = ws.map { |w| Worksheet.new(self, w.gid, w.title, w) }
      {items: ws}
    end

    def find_entity(gid, context)
      Worksheet.new(self, gid)
    end
  end

  class Worksheet
    include EntitySet
    protocol :update, :insert

    class InsertAction < EntitySet::InsertAction
      def args(context)
        super.tap do |args|
          args[:properties][:type][:open] = true
        end
      end

      def after_create(binding)
        define_columns_for binding
      end

      def after_update(binding)
        define_columns_for binding
      end

      def define_columns_for(binding)
        new_columns = (binding["members"]["properties"]["open"] || {}).keys
        return if new_columns.empty?

        worksheet = parent.worksheet
        list = worksheet.list
        headers = list.keys
        new_headers = (headers + new_columns).uniq
        list.keys = new_headers
        worksheet.save
      end
    end

    def initialize(parent, gid, label = nil, worksheet = nil)
      @parent = parent
      @gid = gid
      @label = label
      @worksheet = worksheet
    end

    def label
      @label ||= worksheet.title
    end

    def path
      "#{@parent.path}/#{@gid}"
    end

    def reflect_entities(context)
      # Rows are not displayed during reflection
    end

    def entity_properties(context)
      Hash[headers.map { |h| [h, SimpleProperty.string(h)] }]
    end

    def query(filters, context, options)
      rows = worksheet.list.select { |row| row_matches_filters?(row, filters) }
      rows = rows.map { |row| Row.new(self, row) }
      {items: rows}
    end

    def insert(properties, context)
      list = worksheet.list
      list.push properties
      worksheet.save
    end

    def update(filters, properties, context)
      updated_rows = 0
      list = worksheet.list
      list.each do |row|
        if row_matches_filters?(row, filters)
          row.merge!(properties)
          updated_rows += 1
        end
      end
      worksheet.save

      updated_rows
    end

    def row_matches_filters?(row, filters)
      filters.all? { |key, value| row[key] == value }
    end

    def find_entity(id, context)
      Row.new(self, worksheet.list[id.to_i - 1])
    end

    def worksheet
      @worksheet ||= parent.spreadsheet.worksheet_by_gid(@gid)
    end

    def headers
      worksheet.list.keys
    end
  end

  class Row
    include Entity

    def initialize(parent, row)
      @parent = parent
      @row = row
    end

    def properties(context)
      Hash[parent.headers.map { |h| [h, SimpleProperty.string(h, @row[h])] }]
    end
  end
end

class GoogleSpreadsheetsConnector < Connector
  include EntitySet

  store_accessor :settings, :access_token, :refresh_token, :expires_at, :spreadsheet_key, :spreadsheet_name

  validates_presence_of :access_token
  validates_presence_of :refresh_token
  validates_presence_of :expires_at

  def label
    "Spreadsheets"
  end

  def path
    ""
  end

  def query(filters, user, options)
    [Spreadsheet.new(self, spreadsheet_key)]
  end

  def find_entity(key, user)
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

    def query(filter, user, options)
      spreadsheet.worksheets.map do |ws|
        Worksheet.new(self, ws.title, ws)
      end
    end

    def find_entity(title, user)
      Worksheet.new(self, title)
    end
  end

  class Worksheet
    include EntitySet
    protocol :update, :insert

    class InsertAction < EntitySet::InsertAction
      def args(user)
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
        new_columns = binding["members"]["properties"]["open"].keys
        worksheet = parent.worksheet
        list = worksheet.list
        headers = list.keys
        new_headers = (headers + new_columns).uniq
        list.keys = new_headers
        worksheet.save
      end
    end

    def initialize(parent, label, worksheet = nil)
      @parent = parent
      @label = label
      @worksheet = worksheet
    end

    def label
      @label
    end

    def path
      "#{@parent.path}/#{@label}"
    end

    def reflect_entities(user)
      # Rows are not displayed during reflection
    end

    def filters
      headers
    end

    def entity_properties
      Hash[headers.map { |h| [h, SimpleProperty.string(h, nil)] }]
    end

    def query(filters, current_user, options)
      worksheet.list.select do |row|
        row_matches_filters?(row, filters)
      end.map { |row| Row.new(self, row) }
    end

    def insert(properties, user)
      list = worksheet.list
      list.push properties
      worksheet.save
    end

    def update(filters, properties, user)
      list = worksheet.list
      list.each do |row|
        if row_matches_filters?(row, filters)
          row.merge!(properties)
        end
      end
      worksheet.save
    end

    def row_matches_filters?(row, filters)
      filters.all? { |key, value| row[key] == value }
    end

    def find_entity(id, user)
      Row.new(self, worksheet.list[id.to_i - 1])
    end

    def worksheet
      @worksheet ||= parent.spreadsheet.worksheet_by_title(@label)
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

    def properties
      Hash[parent.headers.map { |h| [h, SimpleProperty.string(h, @row[h])] }]
    end
  end
end

class ResourceMapConnector < Connector
  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  private

  def initialize_defaults
    self.url = "https://resourcemap.instedd.org" unless self.url
  end
end

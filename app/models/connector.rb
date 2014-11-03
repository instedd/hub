class Connector < ActiveRecord::Base
  belongs_to :user

  validates_presence_of :name

  def connector
    self
  end

  def lookup_path(path)
    lookup path.to_s.split('/')
  end
end

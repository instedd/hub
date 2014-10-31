class Connector < ActiveRecord::Base
  def connector
    self
  end

  def lookup_path(path)
    lookup path.to_s.split('/')
  end
end

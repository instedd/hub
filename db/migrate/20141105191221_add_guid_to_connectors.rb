class AddGuidToConnectors < ActiveRecord::Migration
  class MyConnector < ActiveRecord::Base
    self.table_name = "connectors"
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :connectors, :guid, :string

    MyConnector.all.each do |connector|
      connector.name ||= "Some connector"
      connector.guid = Guid.new.to_s
      connector.save!
    end
  end

  def down
    remove_column :connectors, :guid, :string
  end
end

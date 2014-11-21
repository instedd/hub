class ChangeConnectorsSettingsToText < ActiveRecord::Migration
  def up
    change_column :connectors, :settings, :text
  end

  def down
    change_column :connectors, :settings, :hstore
  end
end

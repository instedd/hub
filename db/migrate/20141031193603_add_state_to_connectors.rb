class AddStateToConnectors < ActiveRecord::Migration
  def change
    add_column :connectors, :state, :hstore
  end
end

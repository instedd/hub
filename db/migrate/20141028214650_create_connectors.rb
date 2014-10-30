class CreateConnectors < ActiveRecord::Migration
  def change
    create_table :connectors do |t|
      t.string :name
      t.string :type
      t.hstore :settings

      t.timestamps
    end
  end
end

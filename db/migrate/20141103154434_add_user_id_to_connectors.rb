class AddUserIdToConnectors < ActiveRecord::Migration
  def change
    add_column :connectors, :user_id, :integer
  end
end

class AddSecretTokenToConnectors < ActiveRecord::Migration
  def change
    add_column :connectors, :secret_token, :string
  end
end

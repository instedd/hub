class ConvertOldSettingsFormatToYaml < ActiveRecord::Migration
  def up
    connection.execute("SELECT id, settings FROM connectors").each do |connector|
      next if connector["settings"].starts_with?("---")
      hash = HashWithIndifferentAccess.new
      connector["settings"].scan(/(\"(?<name>[^\"]*)\"\s*=>\s*\"(?<value>[^\"]*)\"(\,\s)?)/) do |name, value|
        hash[name] = value
      end
      puts "Converting settings of connector #{connector["id"]}"
      connection.execute("UPDATE connectors SET settings = #{connection.quote(YAML.dump(hash))} WHERE id = #{connector["id"]}")
    end
  end
end

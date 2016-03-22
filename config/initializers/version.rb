RevisionFilePath = "#{::Rails.root.to_s}/REVISION"
VersionFilePath = "#{::Rails.root.to_s}/VERSION"

if FileTest.exists?(VersionFilePath)
  version = IO.read(VersionFilePath)
elsif FileTest.exists?(RevisionFilePath)
  version = IO.read(RevisionFilePath)
else
  version = ENV["HUB_VERSION"] || "development"
end

Hub::Application.config.version_name = version

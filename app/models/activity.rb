class Activity

  def self.for(user)
    new user
  end

  def initialize(user)
    @user = user
  end

  def all
    Hercule::Activity.query("controller:ConnectorsController action:invoke", size: 1000000).items + Hercule::Activity.query("@description:polling_event", size: 1000000).items
  end
end
